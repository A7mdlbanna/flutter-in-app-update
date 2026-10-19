import 'package:flutter/foundation.dart';

import 'in_app_update_platform_interface.dart';
import 'types.dart';

/// Google Play in-app updates on Android, App Store version check on iOS.
///
/// Most apps only need [InAppUpdateScope]; these are the building blocks it
/// uses.
abstract final class InAppUpdate {
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Asks Google Play (Android) or the App Store (iOS) whether a newer version
  /// of this app is available. Returns [UpdateInfo.unsupported] elsewhere.
  static Future<UpdateInfo> checkForUpdate() async {
    if (!_isSupported) return UpdateInfo.unsupported;
    return InAppUpdatePlatform.instance.checkForUpdate();
  }

  /// Shows the update UI. On Android, [UpdateType.immediate] is Play's
  /// full-screen blocking flow and [UpdateType.flexible] downloads in the
  /// background (call [completeUpdate] once the install status is
  /// [InstallStatus.downloaded]). On iOS both show the app's App Store page
  /// in-app and complete with [UpdateFlowResult.canceled] when it closes.
  ///
  /// Throws [InAppUpdateException] if no update can be started.
  static Future<UpdateFlowResult> startUpdate([
    UpdateType type = UpdateType.immediate,
  ]) async {
    if (!_isSupported) {
      throw const InAppUpdateException(
        InAppUpdateException.unsupported,
        'In-app updates are only available on Android and iOS',
      );
    }
    return InAppUpdatePlatform.instance.startUpdate(type);
  }

  /// Installs a downloaded flexible update. The app restarts. No-op on iOS.
  static Future<void> completeUpdate() async {
    if (!_isAndroid) return;
    return InAppUpdatePlatform.instance.completeUpdate();
  }

  /// Download/install progress of flexible updates. Never emits on iOS.
  static Stream<InstallState> get installStateChanges {
    if (!_isAndroid) return const Stream.empty();
    return InAppUpdatePlatform.instance.installStateChanges;
  }
}
