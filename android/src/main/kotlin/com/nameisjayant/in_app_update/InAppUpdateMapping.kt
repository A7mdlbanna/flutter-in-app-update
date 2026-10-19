package com.nameisjayant.in_app_update

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability

// Play Core → Dart translation, kept free of Flutter so it can be unit tested.
internal object InAppUpdateMapping {

    fun updateType(type: String?): Int =
        if (type == "flexible") AppUpdateType.FLEXIBLE else AppUpdateType.IMMEDIATE

    /** Whether `updateType` can be started from this AppUpdateInfo. */
    fun canStart(info: AppUpdateInfo, updateType: Int): Boolean =
        when (info.updateAvailability()) {
            UpdateAvailability.UPDATE_AVAILABLE -> info.isUpdateTypeAllowed(updateType)
            // A started immediate update can only be resumed as immediate.
            UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS ->
                updateType == AppUpdateType.IMMEDIATE
            else -> false
        }

    fun flowResult(resultCode: Int): String = when (resultCode) {
        Activity.RESULT_OK -> "accepted"
        Activity.RESULT_CANCELED -> "canceled"
        else -> "failed"
    }

    fun updateInfo(info: AppUpdateInfo): Map<String, Any?> = mapOf(
        "updateAvailability" to availabilityName(info.updateAvailability()),
        "installStatus" to installStatusName(info.installStatus()),
        "availableVersionCode" to info.availableVersionCode(),
        "isImmediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
        "isFlexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
        "clientVersionStalenessDays" to info.clientVersionStalenessDays(),
        "updatePriority" to info.updatePriority(),
        "bytesDownloaded" to info.bytesDownloaded(),
        "totalBytesToDownload" to info.totalBytesToDownload(),
    )

    fun installState(state: InstallState): Map<String, Any> = mapOf(
        "installStatus" to installStatusName(state.installStatus()),
        "installErrorCode" to state.installErrorCode(),
        "bytesDownloaded" to state.bytesDownloaded(),
        "totalBytesToDownload" to state.totalBytesToDownload(),
    )

    fun availabilityName(value: Int): String = when (value) {
        UpdateAvailability.UPDATE_NOT_AVAILABLE -> "not_available"
        UpdateAvailability.UPDATE_AVAILABLE -> "available"
        UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> "in_progress"
        else -> "unknown"
    }

    @Suppress("DEPRECATION") // REQUIRES_UI_INTENT
    fun installStatusName(value: Int): String = when (value) {
        InstallStatus.PENDING -> "pending"
        InstallStatus.DOWNLOADING -> "downloading"
        InstallStatus.DOWNLOADED -> "downloaded"
        InstallStatus.INSTALLING -> "installing"
        InstallStatus.INSTALLED -> "installed"
        InstallStatus.FAILED -> "failed"
        InstallStatus.CANCELED -> "canceled"
        InstallStatus.REQUIRES_UI_INTENT -> "requires_ui_intent"
        else -> "unknown"
    }
}
