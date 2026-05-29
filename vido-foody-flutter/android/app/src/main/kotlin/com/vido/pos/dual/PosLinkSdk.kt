package com.vido.pos.dual

import android.util.Log

/**
 * Thin reflection wrapper over the PAX POSLink Android SDK
 * (com.pax.poslink.PosLink and its peers).
 *
 * The Vido POS Flutter project compiles cleanly without the SDK JAR in
 * `android/app/libs/`. When the JAR is dropped in, this loader will detect
 * the classes at runtime and route real calls to POSLink. When absent,
 * `isPresent` is false and `PaxPaymentPlugin` falls back to mock responses.
 *
 * Tested against POSLink Java/Android V1.14 and V1.15.
 * Reference: "POSLink Integration Setup Guide V1.04" §3.2 & §4.
 */
class PosLinkSdk private constructor(
    val isPresent: Boolean,
    private val posLinkClass: Class<*>? = null,
    private val commSettingClass: Class<*>? = null,
    private val manageRequestClass: Class<*>? = null,
    private val paymentRequestClass: Class<*>? = null,
) {
    companion object {
        private const val TAG = "PosLinkSdk"

        fun tryLoad(): PosLinkSdk = try {
            val pl = Class.forName("com.pax.poslink.PosLink")
            val cs = Class.forName("com.pax.poslink.CommSetting")
            val mr = Class.forName("com.pax.poslink.ManageRequest")
            val pr = Class.forName("com.pax.poslink.PaymentRequest")
            Log.i(TAG, "POSLink SDK detected — real payments enabled")
            PosLinkSdk(true, pl, cs, mr, pr)
        } catch (e: ClassNotFoundException) {
            Log.w(TAG, "POSLink SDK not bundled — running in MOCK mode. " +
                "Drop POSLink_VX.XX.jar into android/app/libs/ to enable real payments.")
            PosLinkSdk(false)
        }
    }

    // ===================================================================
    // Data classes
    // ===================================================================
    data class CommSetting(
        val commType: String,    // TCP | USB | BT | AIDL | UART | HTTP | HTTPS | SSL
        val destIp: String,
        val destPort: String,
        val serialPort: String,
        val baudRate: String,
        val timeoutMs: String,
        val enableProxy: Boolean,
    )

    data class InitResult(
        val resultCode: String,
        val resultText: String,
        val sn: String,
        val modelName: String,
        val osVersion: String,
        val macAddress: String,
    )

    data class SaleResult(
        val resultCode: String,
        val resultText: String,
        val hostCode: String,
        val hostText: String,
        val authCode: String,
        val approvedAmountCents: Int,
        val refNum: String,
        val transNum: String,
        val cardType: String,
        val last4: String,
        val entryMode: String,
        val signatureRequired: Boolean,
    )

    data class VoidResult(
        val resultCode: String,
        val resultText: String,
        val hostCode: String,
        val hostText: String,
    )

    // ===================================================================
    // POSLink operations (all blocking — call from worker thread)
    // ===================================================================
    fun runInit(comm: CommSetting): InitResult {
        require(isPresent) { "POSLink SDK not loaded" }
        val posLink = newPosLinkWithComm(comm)

        // ManageRequest manageReq = new ManageRequest();
        val manageReq = manageRequestClass!!.getConstructor().newInstance()
        val parsed = manageReq.javaClass.getMethod("ParseTransType", String::class.java)
            .invoke(manageReq, "INIT")
        manageReq.javaClass.getField("TransType").set(manageReq, parsed)

        // poslink.ManageRequest = manageReq;
        posLink.javaClass.getField("ManageRequest").set(posLink, manageReq)

        // ProcessTransResult result = poslink.ProcessTrans();
        val transResult = posLink.javaClass.getMethod("ProcessTrans").invoke(posLink)
        val code = transResult.javaClass.getField("Code").get(transResult)?.toString() ?: ""
        val msg = transResult.javaClass.getField("Msg").get(transResult)?.toString() ?: ""

        if (code != "OK" && code != "0") {
            return InitResult("999999", "Process failed: $code $msg", "", "", "", "")
        }

        // ManageResponse manageRes = poslink.ManageResponse;
        val mr = posLink.javaClass.getField("ManageResponse").get(posLink)!!
        return InitResult(
            resultCode = strField(mr, "ResultCode"),
            resultText = strField(mr, "ResultTxt"),
            sn = strField(mr, "SN"),
            modelName = strField(mr, "ModelName"),
            osVersion = strField(mr, "OSVersion"),
            macAddress = strField(mr, "MacAddress"),
        )
    }

    fun runSale(
        comm: CommSetting,
        amountCents: Long,
        tipCents: Long,
        taxCents: Long,
        ecrRefNum: String,
        invoiceNum: String,
        clerkId: String,
    ): SaleResult {
        require(isPresent) { "POSLink SDK not loaded" }
        val posLink = newPosLinkWithComm(comm)

        // PaymentRequest req = new PaymentRequest();
        val req = paymentRequestClass!!.getConstructor().newInstance()
        req.javaClass.getField("TenderType").set(req,
            parseEnum(req, "ParseTenderType", "CREDIT"))
        req.javaClass.getField("TransType").set(req,
            parseEnum(req, "ParseTransType", "SALE"))
        req.javaClass.getField("Amount").set(req, amountCents.toString())
        if (tipCents > 0) req.javaClass.getField("TipAmt").set(req, tipCents.toString())
        if (taxCents > 0) req.javaClass.getField("TaxAmt").set(req, taxCents.toString())
        req.javaClass.getField("ECRRefNum").set(req, ecrRefNum)
        if (invoiceNum.isNotEmpty()) req.javaClass.getField("InvNum").set(req, invoiceNum)
        if (clerkId.isNotEmpty())    req.javaClass.getField("ClerkID").set(req, clerkId)

        posLink.javaClass.getField("PaymentRequest").set(posLink, req)
        val transResult = posLink.javaClass.getMethod("ProcessTrans").invoke(posLink)
        val code = strField(transResult, "Code")
        val msg = strField(transResult, "Msg")
        if (code != "OK" && code != "0") {
            return SaleResult("999999", "Process failed: $code $msg",
                "", "", "", 0, ecrRefNum, "", "", "", "", false)
        }

        val rsp = posLink.javaClass.getField("PaymentResponse").get(posLink)!!
        val approved = strField(rsp, "ApprovedAmount").toLongOrNull()
            ?: strField(rsp, "Amount").toLongOrNull()
            ?: amountCents
        return SaleResult(
            resultCode = strField(rsp, "ResultCode"),
            resultText = strField(rsp, "ResultTxt"),
            hostCode = strField(rsp, "HostCode"),
            hostText = strField(rsp, "HostResponse"),
            authCode = strField(rsp, "AuthCode"),
            approvedAmountCents = approved.toInt(),
            refNum = strField(rsp, "RefNum"),
            transNum = strField(rsp, "ECRRefNum").ifEmpty { ecrRefNum },
            cardType = strField(rsp, "CardType"),
            last4 = strField(rsp, "BogusAccountNum").takeLast(4),
            entryMode = strField(rsp, "EntryMode"),
            signatureRequired = strField(rsp, "SigRequired") == "1",
        )
    }

    fun runVoidSale(
        comm: CommSetting,
        ecrRefNum: String,
        transNum: String,
    ): VoidResult {
        require(isPresent) { "POSLink SDK not loaded" }
        val posLink = newPosLinkWithComm(comm)
        val req = paymentRequestClass!!.getConstructor().newInstance()
        req.javaClass.getField("TenderType").set(req,
            parseEnum(req, "ParseTenderType", "CREDIT"))
        req.javaClass.getField("TransType").set(req,
            parseEnum(req, "ParseTransType", "V/SALE"))
        req.javaClass.getField("ECRRefNum").set(req, ecrRefNum)
        if (transNum.isNotEmpty()) req.javaClass.getField("OrigRefNum").set(req, transNum)

        posLink.javaClass.getField("PaymentRequest").set(posLink, req)
        posLink.javaClass.getMethod("ProcessTrans").invoke(posLink)
        val rsp = posLink.javaClass.getField("PaymentResponse").get(posLink)!!
        return VoidResult(
            resultCode = strField(rsp, "ResultCode"),
            resultText = strField(rsp, "ResultTxt"),
            hostCode = strField(rsp, "HostCode"),
            hostText = strField(rsp, "HostResponse"),
        )
    }

    // ===================================================================
    // Internal — reflection helpers
    // ===================================================================
    private fun newPosLinkWithComm(c: CommSetting): Any {
        val commCls = requireNotNull(commSettingClass) { "CommSetting class is not loaded" }
        val posLinkCls = requireNotNull(posLinkClass) { "POSLink class is not loaded" }
        val comm = commCls.getConstructor().newInstance()

        // commSetting.setType(CommSetting.TCP)  via reflected static field
        val typeConst = commCls.getField(c.commType).get(null) as String
        commCls.getMethod("setType", String::class.java).invoke(comm, typeConst)
        commCls.getMethod("setTimeOut", String::class.java).invoke(comm, c.timeoutMs)

        when (c.commType) {
            "TCP", "HTTP", "HTTPS", "SSL" -> {
                commCls.getMethod("setDestIP", String::class.java).invoke(comm, c.destIp)
                commCls.getMethod("setDestPort", String::class.java).invoke(comm, c.destPort)
            }
            "UART" -> {
                commCls.getMethod("setSerialPort", String::class.java).invoke(comm, c.serialPort)
                commCls.getMethod("setBaudRate", String::class.java).invoke(comm, c.baudRate)
            }
            "USB" -> {
                runCatching {
                    commCls.getMethod("setEnableProxy", java.lang.Boolean.TYPE)
                        .invoke(comm, c.enableProxy)
                }
            }
            "BT" -> {
                runCatching {
                    commCls.getMethod("setMacAddr", String::class.java)
                        .invoke(comm, c.destIp)   // re-use destIp field as the MAC
                }
            }
            "AIDL" -> { /* no extra parameters needed */ }
        }

        val posLink = posLinkCls.getConstructor().newInstance()
        // Either field-style ("CommSetting = comm") or setter ("SetCommSetting(comm)")
        // depending on SDK version. Try both.
        runCatching {
            posLinkCls.getMethod("SetCommSetting", commCls).invoke(posLink, comm)
        }.onFailure {
            posLinkCls.getField("CommSetting").set(posLink, comm)
        }
        return posLink
    }

    private fun parseEnum(req: Any, methodName: String, value: String): Any =
        req.javaClass.getMethod(methodName, String::class.java).invoke(req, value)!!

    private fun strField(obj: Any, name: String): String = runCatching {
        obj.javaClass.getField(name).get(obj)?.toString() ?: ""
    }.getOrElse { "" }
}
