import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update_kit/in_app_update_kit.dart';

import 'fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeInAppUpdatePlatform fake;

  group('Android', () {
    setUp(() => fake = installFakePlatform(TargetPlatform.android));

    test('checkForUpdate returns Play update info', () async {
      fake.checkReturns([playUpdate]);
      expect(await InAppUpdate.checkForUpdate(), playUpdate);
    });

    test('checkForUpdate passes native errors through', () async {
      fake.onCheck = () => throw const InAppUpdateException(
            InAppUpdateException.checkFailed,
            'Install Error(-10): The app is not owned by any user on this device.',
          );
      await expectLater(
        InAppUpdate.checkForUpdate(),
        throwsA(isA<InAppUpdateException>()),
      );
    });

    test('startUpdate defaults to the immediate flow', () async {
      expect(await InAppUpdate.startUpdate(), UpdateFlowResult.accepted);
      expect(fake.startCalls, [UpdateType.immediate]);
    });

    test('startUpdate starts the flexible flow', () async {
      fake.startReturns([UpdateFlowResult.canceled]);
      expect(
        await InAppUpdate.startUpdate(UpdateType.flexible),
        UpdateFlowResult.canceled,
      );
      expect(fake.startCalls, [UpdateType.flexible]);
    });

    test('completeUpdate installs the downloaded update', () async {
      await InAppUpdate.completeUpdate();
      expect(fake.completeCalls, 1);
    });

    test('forwards Play install states', () async {
      final states = <InstallState>[];
      final sub = InAppUpdate.installStateChanges.listen(states.add);
      const state = InstallState(
        installStatus: InstallStatus.downloading,
        bytesDownloaded: 25,
        totalBytesToDownload: 100,
      );
      fake.emit(state);
      await pumpEventQueue();
      expect(states, [state]);
      await sub.cancel();
      expect(fake.installStates.hasListener, isFalse);
    });
  });

  group('iOS', () {
    setUp(() => fake = installFakePlatform(TargetPlatform.iOS));

    test('checkForUpdate returns the App Store version', () async {
      fake.checkReturns([appStoreUpdate]);
      final info = await InAppUpdate.checkForUpdate();
      expect(info.availableVersion, '2.1.0');
      expect(info.releaseNotes, 'Bug fixes');
    });

    test('startUpdate shows the App Store page', () async {
      fake.startReturns([UpdateFlowResult.canceled]);
      expect(await InAppUpdate.startUpdate(), UpdateFlowResult.canceled);
    });

    test('completeUpdate is a no-op: the App Store installs updates', () async {
      await InAppUpdate.completeUpdate();
      expect(fake.completeCalls, 0);
    });

    test('never subscribes to install states', () async {
      final sub = InAppUpdate.installStateChanges.listen((_) {});
      expect(fake.installStates.hasListener, isFalse);
      await sub.cancel();
    });
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.fuchsia,
  ]) {
    group(platform.name, () {
      setUp(() => fake = installFakePlatform(platform));

      test('reports unsupported without touching native', () async {
        expect(await InAppUpdate.checkForUpdate(), UpdateInfo.unsupported);
        expect(fake.checkCalls, 0);
      });

      test('refuses to start an update', () async {
        await expectLater(
          InAppUpdate.startUpdate(),
          throwsA(
            isA<InAppUpdateException>().having(
              (e) => e.code,
              'code',
              InAppUpdateException.unsupported,
            ),
          ),
        );
        expect(fake.startCalls, isEmpty);
      });

      test('completeUpdate and install states are no-ops', () async {
        await InAppUpdate.completeUpdate();
        expect(await InAppUpdate.installStateChanges.isEmpty, isTrue);
        expect(fake.completeCalls, 0);
      });
    });
  }
}
