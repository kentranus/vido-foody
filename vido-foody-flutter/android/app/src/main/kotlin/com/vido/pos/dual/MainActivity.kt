package com.vido.pos.dual

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CustomerDisplayPlugin.register(flutterEngine, this)
        PaxPaymentPlugin.register(flutterEngine, this)
    }
}
