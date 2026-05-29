package com.vido.pos.dual

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * PAX Terminal payment plugin (POSLink Semi-Integration).
 *
 * Channel: com.vido.pos.dual/pax_payment
 *
 * Methods:
 *   configure({ commType, destIp, destPort, serialPort, baudRate, timeoutMs, enableProxy })
 *       Save connection settings. No network call.
 *
 *   initialize() -> { ok, sn, model, osVersion, macAddress }
 *       Verify connection (POSLink INIT command). Should be called once on app start
 *       or when settings change.
 *
 *   sale({ amountCents, tipCents, taxCents, ecrRefNum, invoiceNum, clerkId })
 *       -> { ok, resultCode, resultText, hostCode, hostText, authCode,
 *            approvedAmountCents, refNum, transNum, cardType, last4,
 *            entryMode, signatureRequired }
 *       Run a CREDIT SALE transaction. The PAX terminal handles its own UI
 *       (insert/tap/swipe, signature). This call blocks until the transaction
 *       completes or times out.
 *
 *   voidSale({ ecrRefNum, transNum }) -> { ok, resultCode, resultText }
 *
 *   isMockMode() -> { mock: true|false }
 *       Returns true if the POSLink SDK JAR is not bundled — useful so the UI
 *       can warn the user that real payments are not yet available.
 *
 * IMPORTANT: This plugin uses runtime reflection to call into POSLink.jar so
 * the Flutter project compiles cleanly whether or not the SDK has been
 * dropped into `android/app/libs/`. When the JAR is missing, all methods
 * return a mock-success response with a clear flag so the cashier UI can
 * be developed without the terminal present.
 *
 * Drop `POSLink_VX.XX.XX.jar` (from PAX Technology) into
 *     android/app/libs/
 * and the plugin will automatically switch to real-payment mode.
 */
object PaxPaymentPlugin : MethodChannel.MethodCallHandler {

    private const val TAG = "PaxPaymentPlugin"
    private const val CHANNEL = "com.vido.pos.dual/pax_payment"

    // Connection settings (set via configure)
    @Volatile private var commType: String = "TCP"        // TCP | USB | BT | AIDL | UART
    @Volatile private var destIp: String = "192.168.1.100"
    @Volatile private var destPort: String = "10009"
    @Volatile private var serialPort: String = "COM1"
    @Volatile private var baudRate: String = "115200"
    @Volatile private var timeoutMs: String = "60000"
    @Volatile private var enableProxy: Boolean = true     // for E-Series USB → Q20

    private lateinit var ctx: Context
    private lateinit var channel: MethodChannel

    // POSLink calls are blocking & can take 30-60s → off the main thread.
    private val workerThread = HandlerThread("pax-worker").apply { start() }
    private val worker = Handler(workerThread.looper)
    private val mainHandler = Handler(android.os.Looper.getMainLooper())

    private val sdk: PosLinkSdk by lazy { PosLinkSdk.tryLoad() }

    fun register(engine: FlutterEngine, context: Context) {
        ctx = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        Log.i(TAG, "registered — SDK present: ${sdk.isPresent}")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure"   -> configure(call, result)
            "initialize"  -> runOnWorker { initialize(result) }
            "sale"        -> runOnWorker { sale(call, result) }
            "voidSale"    -> runOnWorker { voidSale(call, result) }
            "isMockMode"  -> result.success(mapOf("mock" to !sdk.isPresent))
            else          -> result.notImplemented()
        }
    }

    // ===================================================================
    // Settings
    // ===================================================================
    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        commType    = call.argument<String>("commType")    ?: commType
        destIp      = call.argument<String>("destIp")      ?: destIp
        destPort    = call.argument<String>("destPort")    ?: destPort
        serialPort  = call.argument<String>("serialPort")  ?: serialPort
        baudRate    = call.argument<String>("baudRate")    ?: baudRate
        timeoutMs   = call.argument<String>("timeoutMs")   ?: timeoutMs
        enableProxy = call.argument<Boolean>("enableProxy") ?: enableProxy
        Log.i(TAG, "configure: $commType $destIp:$destPort (proxy=$enableProxy)")
        result.success(mapOf("ok" to true))
    }

    // ===================================================================
    // INIT — connection test
    // ===================================================================
    private fun initialize(result: MethodChannel.Result) {
        if (!sdk.isPresent) {
            // Mock response for UI development without SDK/terminal
            replyMain(result, mapOf(
                "ok" to true, "mock" to true,
                "sn" to "MOCK-SN-00000001",
                "model" to "MOCK Terminal",
                "osVersion" to "1.0.0",
                "macAddress" to "00:00:00:00:00:00",
            ))
            return
        }
        try {
            val res = sdk.runInit(buildCommSetting())
            replyMain(result, mapOf(
                "ok" to (res.resultCode == "000000"),
                "resultCode" to res.resultCode,
                "resultText" to res.resultText,
                "sn" to res.sn,
                "model" to res.modelName,
                "osVersion" to res.osVersion,
                "macAddress" to res.macAddress,
            ))
        } catch (e: Throwable) {
            Log.e(TAG, "initialize failed", e)
            replyError(result, "INIT_FAILED", e.message ?: "error")
        }
    }

    // ===================================================================
    // SALE — main payment flow
    // ===================================================================
    private fun sale(call: MethodCall, result: MethodChannel.Result) {
        val amountCents  = (call.argument<Int>("amountCents")  ?: 0).toLong()
        val tipCents     = (call.argument<Int>("tipCents")     ?: 0).toLong()
        val taxCents     = (call.argument<Int>("taxCents")     ?: 0).toLong()
        val ecrRefNum    = call.argument<String>("ecrRefNum") ?: System.currentTimeMillis().toString()
        val invoiceNum   = call.argument<String>("invoiceNum") ?: ""
        val clerkId      = call.argument<String>("clerkId")    ?: ""

        if (amountCents <= 0) {
            replyError(result, "INVALID_AMOUNT", "Amount must be > 0")
            return
        }

        if (!sdk.isPresent) {
            // Simulate processing delay + return mock approval
            Thread.sleep(1500)
            replyMain(result, mapOf(
                "ok" to true, "mock" to true,
                "resultCode" to "000000",
                "resultText" to "OK",
                "hostCode" to "000",
                "hostText" to "APPROVAL",
                "authCode" to "MOCK01",
                "approvedAmountCents" to amountCents.toInt(),
                "refNum" to ecrRefNum,
                "transNum" to "1",
                "cardType" to "VISA",
                "last4" to "4242",
                "entryMode" to "Chip",
                "signatureRequired" to false,
            ))
            return
        }

        try {
            val res = sdk.runSale(
                comm = buildCommSetting(),
                amountCents = amountCents,
                tipCents = tipCents,
                taxCents = taxCents,
                ecrRefNum = ecrRefNum,
                invoiceNum = invoiceNum,
                clerkId = clerkId,
            )
            // resultCode == "000000" = transaction completed (could still be DECLINED)
            // hostCode  == "000"     = host approval
            replyMain(result, mapOf(
                "ok" to (res.resultCode == "000000" && res.hostCode == "000"),
                "resultCode" to res.resultCode,
                "resultText" to res.resultText,
                "hostCode" to res.hostCode,
                "hostText" to res.hostText,
                "authCode" to res.authCode,
                "approvedAmountCents" to res.approvedAmountCents,
                "refNum" to res.refNum,
                "transNum" to res.transNum,
                "cardType" to res.cardType,
                "last4" to res.last4,
                "entryMode" to res.entryMode,
                "signatureRequired" to res.signatureRequired,
            ))
        } catch (e: Throwable) {
            Log.e(TAG, "sale failed", e)
            replyError(result, "SALE_FAILED", e.message ?: "error")
        }
    }

    // ===================================================================
    // VOID SALE — cancel a transaction by reference
    // ===================================================================
    private fun voidSale(call: MethodCall, result: MethodChannel.Result) {
        val ecrRefNum = call.argument<String>("ecrRefNum") ?: ""
        val transNum  = call.argument<String>("transNum")  ?: ""

        if (!sdk.isPresent) {
            Thread.sleep(800)
            replyMain(result, mapOf(
                "ok" to true, "mock" to true,
                "resultCode" to "000000", "resultText" to "OK",
            ))
            return
        }
        try {
            val res = sdk.runVoidSale(buildCommSetting(), ecrRefNum, transNum)
            replyMain(result, mapOf(
                "ok" to (res.resultCode == "000000" && res.hostCode == "000"),
                "resultCode" to res.resultCode,
                "resultText" to res.resultText,
                "hostCode" to res.hostCode,
                "hostText" to res.hostText,
            ))
        } catch (e: Throwable) {
            Log.e(TAG, "voidSale failed", e)
            replyError(result, "VOID_FAILED", e.message ?: "error")
        }
    }

    // ===================================================================
    // Helpers
    // ===================================================================
    private fun buildCommSetting(): PosLinkSdk.CommSetting = PosLinkSdk.CommSetting(
        commType = commType,
        destIp = destIp, destPort = destPort,
        serialPort = serialPort, baudRate = baudRate,
        timeoutMs = timeoutMs, enableProxy = enableProxy,
    )

    private fun runOnWorker(block: () -> Unit) = worker.post(block)

    private fun replyMain(r: MethodChannel.Result, m: Map<String, Any?>) =
        mainHandler.post { r.success(m) }

    private fun replyError(r: MethodChannel.Result, code: String, msg: String) =
        mainHandler.post { r.error(code, msg, null) }
}
