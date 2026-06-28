package com.altf4.personaltrainer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "traininghub.dev/hr_stream"
    private val GB_ACTION = "nodomain.freeyourgadget.gadgetbridge.device.action.HEART_RATE_UPDATED"
    private val GB_EXTRA = "HEART_RATE"

    private var eventSink: EventChannel.EventSink? = null
    private var hrReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    registerHrReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterHrReceiver()
                }
            }
        )
    }

    private fun registerHrReceiver() {
        if (hrReceiver != null) return
        hrReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null || intent.action != GB_ACTION) return
                val bpm = intent.getIntExtra(GB_EXTRA, -1)
                if (bpm > 0) {
                    eventSink?.success(bpm)
                }
            }
        }
        val filter = IntentFilter(GB_ACTION)
        registerReceiver(hrReceiver, filter)
    }

    private fun unregisterHrReceiver() {
        hrReceiver?.let { unregisterReceiver(it) }
        hrReceiver = null
    }

    override fun onDestroy() {
        unregisterHrReceiver()
        eventSink = null
        super.onDestroy()
    }
}