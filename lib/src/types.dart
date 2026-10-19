import 'package:flutter/foundation.dart';

/// Android update flow. On iOS both show the App Store page.
enum UpdateType {
  /// Play's full-screen, blocking update.
  immediate,

  /// Downloads in the background; call [InAppUpdate.completeUpdate] once the
  /// install status is [InstallStatus.downloaded].
  flexible,
}

enum UpdateAvailability {
  unknown('unknown'),
  notAvailable('not_available'),
  available('available'),

  /// An immediate update was started and not finished — resume it.
  inProgress('in_progress'),

  /// Platform without in-app updates (web, desktop).
  unsupported('unsupported');

  const UpdateAvailability(this.wireName);

  /// Name used on the platform channel.
  final String wireName;

  static UpdateAvailability fromWire(Object? value) => values.firstWhere(
        (e) => e.wireName == value,
        orElse: () => UpdateAvailability.unknown,
      );
}

enum InstallStatus {
  unknown('unknown'),
  pending('pending'),
  downloading('downloading'),
  downloaded('downloaded'),
  installing('installing'),
  installed('installed'),
  failed('failed'),
  canceled('canceled'),
  requiresUiIntent('requires_ui_intent');

  const InstallStatus(this.wireName);

  /// Name used on the platform channel.
  final String wireName;

  static InstallStatus fromWire(Object? value) => values.firstWhere(
        (e) => e.wireName == value,
        orElse: () => InstallStatus.unknown,
      );
}

/// Outcome of the update UI. On iOS it is always [canceled] once the App Store
/// page closes: Apple doesn't say whether the user updated, and if they did
/// iOS relaunches the app on the new version.
enum UpdateFlowResult {
  accepted,
  canceled,
  failed;

  static UpdateFlowResult fromWire(Object? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => UpdateFlowResult.failed,
      );
}

@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.updateAvailability,
    this.installStatus = InstallStatus.unknown,
    this.availableVersionCode = 0,
    this.availableVersion,
    this.releaseNotes,
    this.isImmediateAllowed = false,
    this.isFlexibleAllowed = false,
    this.clientVersionStalenessDays,
    this.updatePriority = 0,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
  });

  factory UpdateInfo.fromMap(Map<Object?, Object?> map) => UpdateInfo(
        updateAvailability:
            UpdateAvailability.fromWire(map['updateAvailability']),
        installStatus: InstallStatus.fromWire(map['installStatus']),
        availableVersionCode: _int(map['availableVersionCode']),
        availableVersion: _nonEmpty(map['availableVersion']),
        releaseNotes: _nonEmpty(map['releaseNotes']),
        isImmediateAllowed: map['isImmediateAllowed'] == true,
        isFlexibleAllowed: map['isFlexibleAllowed'] == true,
        clientVersionStalenessDays: map['clientVersionStalenessDays'] as int?,
        updatePriority: _int(map['updatePriority']),
        bytesDownloaded: _int(map['bytesDownloaded']),
        totalBytesToDownload: _int(map['totalBytesToDownload']),
      );

  /// Returned on platforms without in-app updates.
  static const unsupported = UpdateInfo(
    updateAvailability: UpdateAvailability.unsupported,
  );

  final UpdateAvailability updateAvailability;
  final InstallStatus installStatus;

  /// Play `versionCode` of the update. Always 0 on iOS.
  final int availableVersionCode;

  /// App Store version string (e.g. "2.1.0"). Null on Android: Play only
  /// gives [availableVersionCode].
  final String? availableVersion;

  /// App Store "What's New" text. Null on Android.
  final String? releaseNotes;

  /// On iOS both flows show the App Store page, so these match.
  final bool isImmediateAllowed;
  final bool isFlexibleAllowed;

  /// Days since Play learned about the update (Android) or since the App Store
  /// version was released (iOS), or null if unknown.
  final int? clientVersionStalenessDays;

  /// 0–5, set via the Play Developer API. Always 0 on iOS.
  final int updatePriority;
  final int bytesDownloaded;
  final int totalBytesToDownload;

  bool isAllowed(UpdateType type) =>
      type == UpdateType.immediate ? isImmediateAllowed : isFlexibleAllowed;

  @override
  bool operator ==(Object other) =>
      other is UpdateInfo &&
      other.updateAvailability == updateAvailability &&
      other.installStatus == installStatus &&
      other.availableVersionCode == availableVersionCode &&
      other.availableVersion == availableVersion &&
      other.releaseNotes == releaseNotes &&
      other.isImmediateAllowed == isImmediateAllowed &&
      other.isFlexibleAllowed == isFlexibleAllowed &&
      other.clientVersionStalenessDays == clientVersionStalenessDays &&
      other.updatePriority == updatePriority &&
      other.bytesDownloaded == bytesDownloaded &&
      other.totalBytesToDownload == totalBytesToDownload;

  @override
  int get hashCode => Object.hash(
        updateAvailability,
        installStatus,
        availableVersionCode,
        availableVersion,
        releaseNotes,
        isImmediateAllowed,
        isFlexibleAllowed,
        clientVersionStalenessDays,
        updatePriority,
        bytesDownloaded,
        totalBytesToDownload,
      );

  @override
  String toString() => 'UpdateInfo(${updateAvailability.wireName}, '
      'installStatus: ${installStatus.wireName}, '
      'versionCode: $availableVersionCode, version: $availableVersion, '
      'immediate: $isImmediateAllowed, flexible: $isFlexibleAllowed, '
      'staleness: $clientVersionStalenessDays, priority: $updatePriority)';
}

/// Download/install progress of a flexible update (Android only).
@immutable
class InstallState {
  const InstallState({
    required this.installStatus,
    this.installErrorCode = 0,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
  });

  factory InstallState.fromMap(Map<Object?, Object?> map) => InstallState(
        installStatus: InstallStatus.fromWire(map['installStatus']),
        installErrorCode: _int(map['installErrorCode']),
        bytesDownloaded: _int(map['bytesDownloaded']),
        totalBytesToDownload: _int(map['totalBytesToDownload']),
      );

  final InstallStatus installStatus;

  /// Play `InstallErrorCode`, 0 when there is no error.
  final int installErrorCode;
  final int bytesDownloaded;
  final int totalBytesToDownload;

  @override
  bool operator ==(Object other) =>
      other is InstallState &&
      other.installStatus == installStatus &&
      other.installErrorCode == installErrorCode &&
      other.bytesDownloaded == bytesDownloaded &&
      other.totalBytesToDownload == totalBytesToDownload;

  @override
  int get hashCode => Object.hash(
        installStatus,
        installErrorCode,
        bytesDownloaded,
        totalBytesToDownload,
      );

  @override
  String toString() =>
      'InstallState(${installStatus.wireName}, error: $installErrorCode, '
      '$bytesDownloaded/$totalBytesToDownload)';
}

/// Thrown by [InAppUpdate] when the store or the platform refuses a request.
class InAppUpdateException implements Exception {
  const InAppUpdateException(this.code, this.message);

  static const checkFailed = 'E_CHECK_FAILED';
  static const noActivity = 'E_NO_ACTIVITY';
  static const notAvailable = 'E_NOT_AVAILABLE';
  static const inProgress = 'E_IN_PROGRESS';
  static const startFailed = 'E_START_FAILED';
  static const completeFailed = 'E_COMPLETE_FAILED';
  static const installFailed = 'E_INSTALL_FAILED';
  static const unsupported = 'E_UNSUPPORTED';
  static const unknown = 'E_UNKNOWN';

  /// One of the `E_*` constants above.
  final String code;
  final String message;

  @override
  String toString() => 'InAppUpdateException($code): $message';
}

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
