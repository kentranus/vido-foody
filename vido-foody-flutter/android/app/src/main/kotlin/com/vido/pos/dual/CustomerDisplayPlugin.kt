package com.vido.pos.dual

import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.graphics.Point
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Customer-Facing Display (CFD) — secondary screen for POS.
 *
 * Channel: com.vido.foody/customer_display
 *   listDisplays()            → Map { displays: [...] }
 *   show(displayId?)          → Map { ok, displayId }
 *   hide()                    → Map { ok }
 *   update(json)              → Map { ok }
 *   isShowing()               → Map { showing }
 *
 * Native→Flutter events (invokeMethod on channel):
 *   onDisplaysChanged         → { displays: [...] }   when external display attaches/detaches
 *   onDismissed               → {}                    when presentation is dismissed externally
 *
 * Renders an HTML/CSS receipt inside an Android Presentation + WebView so it
 * works on any Android device with a secondary display (HDMI / USB-C alt-mode /
 * built-in dual-screen POS hardware).
 */
object CustomerDisplayPlugin : MethodChannel.MethodCallHandler {

    private const val CHANNEL = "com.vido.pos.dual/customer_display"
    private lateinit var ctx: Context
    private lateinit var channel: MethodChannel
    private val main = Handler(Looper.getMainLooper())

    private var presentation: ReceiptPresentation? = null
    /** Cached state so a newly-shown presentation can restore the last view immediately. */
    private var lastStateJson: String? = null

    fun register(engine: FlutterEngine, context: Context) {
        ctx = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        registerDisplayListener()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listDisplays" -> listDisplays(result)
            "show"         -> show(call, result)
            "hide"         -> hide(result)
            "update"       -> update(call, result)
            "isShowing"    -> result.success(mapOf("showing" to (presentation?.isShowing == true)))
            else           -> result.notImplemented()
        }
    }

    // ===================================================================
    // Display enumeration
    // ===================================================================
    private fun listDisplays(result: MethodChannel.Result) {
        try {
            val dm = ctx.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val presentationIds = dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                .map { it.displayId }.toSet()
            val list = dm.displays.map { d ->
                val p = Point().also { runCatching { d.getRealSize(it) } }
                mapOf(
                    "id" to d.displayId,
                    "name" to (d.name ?: "Display ${d.displayId}"),
                    "isPrimary" to (d.displayId == Display.DEFAULT_DISPLAY),
                    "isPresentation" to presentationIds.contains(d.displayId),
                    "width" to p.x,
                    "height" to p.y,
                )
            }
            result.success(mapOf("displays" to list))
        } catch (e: Exception) {
            result.error("DISPLAY", e.message ?: "error", null)
        }
    }

    // ===================================================================
    // Show / hide
    // ===================================================================
    private fun show(call: MethodCall, result: MethodChannel.Result) {
        val displayId = call.argument<Int>("displayId")
        main.post {
            try {
                val dm = ctx.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                val target: Display? = when {
                    displayId != null -> dm.displays.firstOrNull { it.displayId == displayId }
                    else -> dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull()
                        ?: dm.displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
                }
                if (target == null) {
                    result.error("NO_DISPLAY", "No secondary display available", null)
                    return@post
                }
                presentation?.dismiss()
                val p = ReceiptPresentation(ctx, target) {
                    // onDismiss callback
                    if (presentation === it) presentation = null
                    channel.invokeMethod("onDismissed", null)
                }
                p.show()
                presentation = p
                lastStateJson?.let { p.pushState(it) }
                result.success(mapOf("ok" to true, "displayId" to target.displayId))
            } catch (e: Exception) {
                result.error("SHOW", e.message ?: "error", null)
            }
        }
    }

    private fun hide(result: MethodChannel.Result) {
        main.post {
            try {
                presentation?.dismiss()
                presentation = null
                result.success(mapOf("ok" to true))
            } catch (e: Exception) {
                result.error("HIDE", e.message ?: "error", null)
            }
        }
    }

    private fun update(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("json") ?: "{}"
        lastStateJson = json
        main.post {
            try {
                presentation?.pushState(json)
                result.success(mapOf("ok" to true, "delivered" to (presentation != null)))
            } catch (e: Exception) {
                result.error("UPDATE", e.message ?: "error", null)
            }
        }
    }

    // ===================================================================
    // Display add/remove listener
    // ===================================================================
    private fun registerDisplayListener() {
        val dm = ctx.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val listener = object : DisplayManager.DisplayListener {
            override fun onDisplayAdded(displayId: Int)   = notifyDisplays()
            override fun onDisplayRemoved(displayId: Int) = notifyDisplays()
            override fun onDisplayChanged(displayId: Int) = notifyDisplays()
            private fun notifyDisplays() {
                main.post {
                    val all = dm.displays.map { d ->
                        mapOf(
                            "id" to d.displayId,
                            "name" to (d.name ?: "Display ${d.displayId}"),
                            "isPrimary" to (d.displayId == Display.DEFAULT_DISPLAY),
                        )
                    }
                    channel.invokeMethod("onDisplaysChanged", mapOf("displays" to all))
                }
            }
        }
        dm.registerDisplayListener(listener, main)
    }
}

// ===================================================================
// Presentation: actual second-screen window
// ===================================================================
class ReceiptPresentation(
    outerContext: Context,
    display: Display,
    private val onDismissed: ((ReceiptPresentation) -> Unit)? = null,
) : Presentation(outerContext.applicationContext, display) {

    private lateinit var webView: WebView
    private var ready = false
    private var queued: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.apply {
            setBackgroundDrawable(android.graphics.drawable.ColorDrawable(Color.parseColor("#0F1419")))
            addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            // Cover any system bars on the secondary display
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                setDecorFitsSystemWindows(false)
            } else {
                @Suppress("DEPRECATION")
                decorView.systemUiVisibility =
                    android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                    android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            }
        }
        webView = WebView(context).apply {
            setBackgroundColor(Color.parseColor("#0F1419"))
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    ready = true
                    queued?.let { js -> view?.evaluateJavascript(js, null) }
                    queued = null
                }
            }
            loadDataWithBaseURL(null, CustomerDisplayHtml.TEMPLATE, "text/html", "utf-8", null)
        }
        setContentView(webView)
    }

    fun pushState(json: String) {
        // JSON.parse on the JS side handles escaping; we only need to embed the JSON
        // as a JS string literal safely. Backslash and apostrophe are the only chars
        // that can break a single-quoted JS literal once the source is already JSON.
        val literal = "'" + json
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "") + "'"
        val js = "window.__updateState && window.__updateState($literal);"
        if (!ready) { queued = js; return }
        webView.post { webView.evaluateJavascript(js, null) }
    }

    override fun onStop() {
        super.onStop()
        try { webView.destroy() } catch (_: Throwable) {}
        onDismissed?.invoke(this)
    }
}
