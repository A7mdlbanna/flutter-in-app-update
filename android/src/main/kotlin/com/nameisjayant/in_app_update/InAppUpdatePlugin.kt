package com.nameisjayant.in_app_update

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Google Play in-app updates. */
class InAppUpdatePlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var installStateChannel: EventChannel
    private lateinit var appUpdateManager: AppUpdateManager
    private var activity: Activity? = null
    private var installStateSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val installStateListener = InstallStateUpdatedListener { state ->
        val event = InAppUpdateMapping.installState(state)
        mainHandler.post { installStateSink?.success(event) }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appUpdateManager = AppUpdateManagerFactory.create(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "in_app_update")
        channel.setMethodCallHandler(this)
        installStateChannel = EventChannel(binding.binaryMessenger, "in_app_update/install_state")
        installStateChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        installStateChannel.setStreamHandler(null)
        onCancel(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkForUpdate" -> checkForUpdate(result)
            "startUpdate" -> startUpdate(call.argument<String>("type"), result)
            "completeUpdate" -> completeUpdate(result)
            else -> result.notImplemented()
        }
    }

    private fun checkForUpdate(result: Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { result.success(InAppUpdateMapping.updateInfo(it)) }
            .addOnFailureListener { result.error(E_CHECK_FAILED, it.message, null) }
    }

    private fun startUpdate(type: String?, result: Result) {
        val updateType = InAppUpdateMapping.updateType(type)
        // AppUpdateInfo can only start one flow, so always fetch a fresh one.
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val activity = activity
                if (activity == null) {
                    result.error(E_NO_ACTIVITY, "No foreground activity to show the update UI", null)
                    return@addOnSuccessListener
                }
                if (!InAppUpdateMapping.canStart(info, updateType)) {
                    result.error(E_NOT_AVAILABLE, "No ${type ?: "immediate"} update is available", null)
                    return@addOnSuccessListener
                }
                appUpdateManager
                    .startUpdateFlow(info, activity, AppUpdateOptions.defaultOptions(updateType))
                    .addOnSuccessListener { resultCode ->
                        result.success(InAppUpdateMapping.flowResult(resultCode))
                    }
                    .addOnFailureListener { result.error(E_START_FAILED, it.message, null) }
            }
            .addOnFailureListener { result.error(E_CHECK_FAILED, it.message, null) }
    }

    private fun completeUpdate(result: Result) {
        appUpdateManager.completeUpdate()
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { result.error(E_COMPLETE_FAILED, it.message, null) }
    }

    // EventChannel.StreamHandler: flexible download progress.

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        installStateSink = events
        appUpdateManager.registerListener(installStateListener)
    }

    override fun onCancel(arguments: Any?) {
        if (installStateSink == null) return
        appUpdateManager.unregisterListener(installStateListener)
        installStateSink = null
    }

    // ActivityAware: the update UI needs the foreground activity.

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private companion object {
        const val E_CHECK_FAILED = "E_CHECK_FAILED"
        const val E_NO_ACTIVITY = "E_NO_ACTIVITY"
        const val E_NOT_AVAILABLE = "E_NOT_AVAILABLE"
        const val E_START_FAILED = "E_START_FAILED"
        const val E_COMPLETE_FAILED = "E_COMPLETE_FAILED"
    }
}
