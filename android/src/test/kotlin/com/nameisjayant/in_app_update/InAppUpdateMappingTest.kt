package com.nameisjayant.in_app_update

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallErrorCode
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.mockk.every
import io.mockk.mockk
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class InAppUpdateMappingTest {

    private fun appUpdateInfo(
        availability: Int = UpdateAvailability.UPDATE_AVAILABLE,
        installStatus: Int = InstallStatus.UNKNOWN,
        versionCode: Int = 42,
        immediateAllowed: Boolean = true,
        flexibleAllowed: Boolean = true,
        stalenessDays: Int? = null,
        priority: Int = 0,
        bytesDownloaded: Long = 0,
        totalBytes: Long = 0,
    ): AppUpdateInfo = mockk {
        every { updateAvailability() } returns availability
        every { installStatus() } returns installStatus
        every { availableVersionCode() } returns versionCode
        every { isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) } returns immediateAllowed
        every { isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) } returns flexibleAllowed
        every { clientVersionStalenessDays() } returns stalenessDays
        every { updatePriority() } returns priority
        every { bytesDownloaded() } returns bytesDownloaded
        every { totalBytesToDownload() } returns totalBytes
    }

    // updateType

    @Test
    fun `flexible maps to the flexible flow`() {
        assertEquals(AppUpdateType.FLEXIBLE, InAppUpdateMapping.updateType("flexible"))
    }

    @Test
    fun `immediate maps to the immediate flow`() {
        assertEquals(AppUpdateType.IMMEDIATE, InAppUpdateMapping.updateType("immediate"))
    }

    @Test
    fun `unknown or missing types fall back to the immediate flow`() {
        assertEquals(AppUpdateType.IMMEDIATE, InAppUpdateMapping.updateType(""))
        assertEquals(AppUpdateType.IMMEDIATE, InAppUpdateMapping.updateType("FLEXIBLE"))
        assertEquals(AppUpdateType.IMMEDIATE, InAppUpdateMapping.updateType(null))
    }

    // canStart

    @Test
    fun `available update starts when the flow is allowed`() {
        val info = appUpdateInfo(immediateAllowed = true, flexibleAllowed = true)
        assertTrue(InAppUpdateMapping.canStart(info, AppUpdateType.IMMEDIATE))
        assertTrue(InAppUpdateMapping.canStart(info, AppUpdateType.FLEXIBLE))
    }

    @Test
    fun `available update does not start a flow Play disallows`() {
        val info = appUpdateInfo(immediateAllowed = false, flexibleAllowed = true)
        assertFalse(InAppUpdateMapping.canStart(info, AppUpdateType.IMMEDIATE))
        assertTrue(InAppUpdateMapping.canStart(info, AppUpdateType.FLEXIBLE))
    }

    @Test
    fun `in-progress immediate update resumes only as immediate`() {
        val info = appUpdateInfo(
            availability = UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS,
            immediateAllowed = false,
            flexibleAllowed = false,
        )
        assertTrue(InAppUpdateMapping.canStart(info, AppUpdateType.IMMEDIATE))
        assertFalse(InAppUpdateMapping.canStart(info, AppUpdateType.FLEXIBLE))
    }

    @Test
    fun `nothing starts when no update is available`() {
        listOf(UpdateAvailability.UPDATE_NOT_AVAILABLE, UpdateAvailability.UNKNOWN).forEach {
            val info = appUpdateInfo(availability = it)
            assertFalse(InAppUpdateMapping.canStart(info, AppUpdateType.IMMEDIATE))
            assertFalse(InAppUpdateMapping.canStart(info, AppUpdateType.FLEXIBLE))
        }
    }

    // flowResult

    @Test
    fun `RESULT_OK means the user accepted`() {
        assertEquals("accepted", InAppUpdateMapping.flowResult(Activity.RESULT_OK))
    }

    @Test
    fun `RESULT_CANCELED means the user canceled`() {
        assertEquals("canceled", InAppUpdateMapping.flowResult(Activity.RESULT_CANCELED))
    }

    @Test
    fun `any other result code is a failure`() {
        // ActivityResult.RESULT_IN_APP_UPDATE_FAILED
        assertEquals("failed", InAppUpdateMapping.flowResult(1))
        assertEquals("failed", InAppUpdateMapping.flowResult(Activity.RESULT_FIRST_USER))
    }

    // availabilityName

    @Test
    fun `maps every update availability`() {
        assertEquals("unknown", InAppUpdateMapping.availabilityName(UpdateAvailability.UNKNOWN))
        assertEquals(
            "not_available",
            InAppUpdateMapping.availabilityName(UpdateAvailability.UPDATE_NOT_AVAILABLE)
        )
        assertEquals(
            "available",
            InAppUpdateMapping.availabilityName(UpdateAvailability.UPDATE_AVAILABLE)
        )
        assertEquals(
            "in_progress",
            InAppUpdateMapping.availabilityName(UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS)
        )
        assertEquals("unknown", InAppUpdateMapping.availabilityName(99))
    }

    // installStatusName

    @Test
    @Suppress("DEPRECATION")
    fun `maps every install status`() {
        val expected = mapOf(
            InstallStatus.UNKNOWN to "unknown",
            InstallStatus.PENDING to "pending",
            InstallStatus.DOWNLOADING to "downloading",
            InstallStatus.DOWNLOADED to "downloaded",
            InstallStatus.INSTALLING to "installing",
            InstallStatus.INSTALLED to "installed",
            InstallStatus.FAILED to "failed",
            InstallStatus.CANCELED to "canceled",
            InstallStatus.REQUIRES_UI_INTENT to "requires_ui_intent",
            99 to "unknown",
        )
        expected.forEach { (status, name) ->
            assertEquals(name, InAppUpdateMapping.installStatusName(status))
        }
    }

    // updateInfo

    @Test
    fun `updateInfo exposes every field Dart expects`() {
        val map = InAppUpdateMapping.updateInfo(appUpdateInfo())
        assertEquals(
            setOf(
                "updateAvailability", "installStatus", "availableVersionCode", "isImmediateAllowed",
                "isFlexibleAllowed", "clientVersionStalenessDays", "updatePriority",
                "bytesDownloaded", "totalBytesToDownload",
            ),
            map.keys
        )
    }

    @Test
    fun `updateInfo maps an available update`() {
        val map = InAppUpdateMapping.updateInfo(
            appUpdateInfo(
                versionCode = 7,
                immediateAllowed = true,
                flexibleAllowed = false,
                stalenessDays = 4,
                priority = 5,
            )
        )
        assertEquals("available", map["updateAvailability"])
        assertEquals("unknown", map["installStatus"])
        assertEquals(7, map["availableVersionCode"])
        assertEquals(true, map["isImmediateAllowed"])
        assertEquals(false, map["isFlexibleAllowed"])
        assertEquals(4, map["clientVersionStalenessDays"])
        assertEquals(5, map["updatePriority"])
    }

    @Test
    fun `updateInfo reports unknown staleness as null`() {
        val map = InAppUpdateMapping.updateInfo(appUpdateInfo(stalenessDays = null))
        assertTrue(map.containsKey("clientVersionStalenessDays"))
        assertNull(map["clientVersionStalenessDays"])
    }

    @Test
    fun `updateInfo keeps download progress as longs`() {
        val map = InAppUpdateMapping.updateInfo(
            appUpdateInfo(
                installStatus = InstallStatus.DOWNLOADING,
                bytesDownloaded = 3_000_000_000,
                totalBytes = 4_000_000_000,
            )
        )
        assertEquals("downloading", map["installStatus"])
        // Larger than Int.MAX_VALUE: must not overflow on the way to Dart.
        assertEquals(3_000_000_000L, map["bytesDownloaded"])
        assertEquals(4_000_000_000L, map["totalBytesToDownload"])
    }

    @Test
    fun `updateInfo maps an up-to-date app`() {
        val map = InAppUpdateMapping.updateInfo(
            appUpdateInfo(
                availability = UpdateAvailability.UPDATE_NOT_AVAILABLE,
                versionCode = 0,
                immediateAllowed = false,
                flexibleAllowed = false,
            )
        )
        assertEquals("not_available", map["updateAvailability"])
        assertEquals(false, map["isImmediateAllowed"])
        assertEquals(false, map["isFlexibleAllowed"])
    }

    // installState

    @Test
    fun `installState maps a download in progress`() {
        val state = mockk<InstallState> {
            every { installStatus() } returns InstallStatus.DOWNLOADING
            every { installErrorCode() } returns InstallErrorCode.NO_ERROR
            every { bytesDownloaded() } returns 25
            every { totalBytesToDownload() } returns 100
        }
        assertEquals(
            mapOf(
                "installStatus" to "downloading",
                "installErrorCode" to 0,
                "bytesDownloaded" to 25L,
                "totalBytesToDownload" to 100L,
            ),
            InAppUpdateMapping.installState(state)
        )
    }

    @Test
    fun `installState passes the Play error code through`() {
        val state = mockk<InstallState> {
            every { installStatus() } returns InstallStatus.FAILED
            every { installErrorCode() } returns InstallErrorCode.ERROR_INSTALL_NOT_ALLOWED
            every { bytesDownloaded() } returns 0
            every { totalBytesToDownload() } returns 0
        }
        val map = InAppUpdateMapping.installState(state)
        assertEquals("failed", map["installStatus"])
        assertEquals(InstallErrorCode.ERROR_INSTALL_NOT_ALLOWED, map["installErrorCode"])
    }
}
