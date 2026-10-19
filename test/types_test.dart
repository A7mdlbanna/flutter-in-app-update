import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

void main() {
  group('UpdateInfo.fromMap', () {
    test('parses a Play update', () {
      final info = UpdateInfo.fromMap({
        'updateAvailability': 'available',
        'installStatus': 'downloading',
        'availableVersionCode': 42,
        'isImmediateAllowed': true,
        'isFlexibleAllowed': false,
        'clientVersionStalenessDays': 3,
        'updatePriority': 4,
        'bytesDownloaded': 3000000000,
        'totalBytesToDownload': 4000000000,
      });
      expect(
        info,
        const UpdateInfo(
          updateAvailability: UpdateAvailability.available,
          installStatus: InstallStatus.downloading,
          availableVersionCode: 42,
          isImmediateAllowed: true,
          isFlexibleAllowed: false,
          clientVersionStalenessDays: 3,
          updatePriority: 4,
          bytesDownloaded: 3000000000,
          totalBytesToDownload: 4000000000,
        ),
      );
    });

    test('has no version string or release notes on Play', () {
      final info = UpdateInfo.fromMap({'updateAvailability': 'available'});
      expect(info.availableVersion, isNull);
      expect(info.releaseNotes, isNull);
    });

    test('parses an App Store update', () {
      final info = UpdateInfo.fromMap({
        'updateAvailability': 'available',
        'availableVersion': '2.1.0',
        'releaseNotes': 'Bug fixes',
        'clientVersionStalenessDays': 0,
      });
      expect(info.availableVersion, '2.1.0');
      expect(info.releaseNotes, 'Bug fixes');
      // 0 means published today, not unknown.
      expect(info.clientVersionStalenessDays, 0);
    });

    test('maps empty strings and nulls to null', () {
      final info = UpdateInfo.fromMap({
        'updateAvailability': 'not_available',
        'availableVersion': '',
        'releaseNotes': null,
        'clientVersionStalenessDays': null,
      });
      expect(info.availableVersion, isNull);
      expect(info.releaseNotes, isNull);
      expect(info.clientVersionStalenessDays, isNull);
    });

    test('reads every availability', () {
      const names = {
        'unknown': UpdateAvailability.unknown,
        'not_available': UpdateAvailability.notAvailable,
        'available': UpdateAvailability.available,
        'in_progress': UpdateAvailability.inProgress,
        'unsupported': UpdateAvailability.unsupported,
        'something_new': UpdateAvailability.unknown,
      };
      names.forEach((wire, value) {
        expect(
          UpdateInfo.fromMap({'updateAvailability': wire}).updateAvailability,
          value,
        );
      });
    });

    test('defaults missing fields', () {
      final info = UpdateInfo.fromMap(const {});
      expect(info.updateAvailability, UpdateAvailability.unknown);
      expect(info.installStatus, InstallStatus.unknown);
      expect(info.availableVersionCode, 0);
      expect(info.isImmediateAllowed, isFalse);
      expect(info.isFlexibleAllowed, isFalse);
    });
  });

  group('InstallState.fromMap', () {
    test('reads every install status', () {
      const names = {
        'unknown': InstallStatus.unknown,
        'pending': InstallStatus.pending,
        'downloading': InstallStatus.downloading,
        'downloaded': InstallStatus.downloaded,
        'installing': InstallStatus.installing,
        'installed': InstallStatus.installed,
        'failed': InstallStatus.failed,
        'canceled': InstallStatus.canceled,
        'requires_ui_intent': InstallStatus.requiresUiIntent,
        'something_new': InstallStatus.unknown,
      };
      names.forEach((wire, value) {
        expect(
            InstallState.fromMap({'installStatus': wire}).installStatus, value);
      });
    });

    test('passes progress and the Play error code through', () {
      expect(
        InstallState.fromMap({
          'installStatus': 'failed',
          'installErrorCode': -6,
          'bytesDownloaded': 25,
          'totalBytesToDownload': 100,
        }),
        const InstallState(
          installStatus: InstallStatus.failed,
          installErrorCode: -6,
          bytesDownloaded: 25,
          totalBytesToDownload: 100,
        ),
      );
    });
  });

  test('UpdateFlowResult treats unknown results as failed', () {
    expect(UpdateFlowResult.fromWire('accepted'), UpdateFlowResult.accepted);
    expect(UpdateFlowResult.fromWire('canceled'), UpdateFlowResult.canceled);
    expect(UpdateFlowResult.fromWire('failed'), UpdateFlowResult.failed);
    expect(UpdateFlowResult.fromWire(null), UpdateFlowResult.failed);
  });
}
