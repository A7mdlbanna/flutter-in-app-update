import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

import 'fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeInAppUpdatePlatform fake;

  setUp(() {
    fake = installFakePlatform(TargetPlatform.iOS);
    // Apple never says whether the user updated: the page always "cancels".
    fake.startReturns([UpdateFlowResult.canceled]);
  });

  Future<InAppUpdateController> start({bool mandatory = true}) async {
    final controller = InAppUpdateController(mandatory: mandatory);
    addTearDown(controller.dispose);
    controller.start();
    await pumpEventQueue();
    return controller;
  }

  group('mandatory (default)', () {
    test('does nothing when the App Store version is not newer', () async {
      fake.checkReturns([
        const UpdateInfo(
          updateAvailability: UpdateAvailability.notAvailable,
          availableVersion: '2.0.0',
        ),
      ]);
      final controller = await start();
      expect(controller.status, UpdateStatus.upToDate);
      expect(controller.updateInfo?.availableVersion, '2.0.0');
      expect(fake.startCalls, isEmpty);
    });

    test('does nothing when the app is not in the App Store', () async {
      fake.checkReturns([notInStore]);
      final controller = await start();
      expect(controller.status, UpdateStatus.upToDate);
      expect(fake.startCalls, isEmpty);
    });

    test('shows the App Store page with the new version info', () async {
      fake.checkReturns([appStoreUpdate]);
      final page = Completer<UpdateFlowResult>();
      fake.onStart = (_) => page.future;
      final controller = await start();
      expect(controller.status, UpdateStatus.prompting);
      expect(controller.updateInfo?.availableVersion, '2.1.0');
      expect(controller.updateInfo?.releaseNotes, 'Bug fixes');
      page.complete(UpdateFlowResult.canceled);
    });

    test('re-shows the App Store page until the user updates', () async {
      fake.checkReturns([
        appStoreUpdate,
        appStoreUpdate,
        appStoreUpdate,
        upToDate,
      ]);
      final controller = await start();
      expect(fake.startCalls, hasLength(3));
      expect(controller.status, UpdateStatus.upToDate);
    });

    test('re-shows the page on return from the App Store app', () async {
      fake.checkReturns([appStoreUpdate]);
      final page = Completer<UpdateFlowResult>();
      fake.onStart = (_) => page.future;
      final controller = await start();

      // The itms-apps fallback left the app.
      await sendToBackground();
      page.complete(UpdateFlowResult.canceled);
      await pumpEventQueue();
      expect(controller.status, UpdateStatus.canceled);
      expect(fake.startCalls, hasLength(1));

      fake.checkReturns([appStoreUpdate, upToDate]);
      fake.startReturns([UpdateFlowResult.canceled]);
      await bringToForeground();
      expect(fake.startCalls, hasLength(2));
      expect(controller.status, UpdateStatus.upToDate);
    });

    test('reports a failed App Store lookup', () async {
      fake.onCheck = () => throw const InAppUpdateException(
            InAppUpdateException.checkFailed,
            'The Internet connection appears to be offline.',
          );
      final controller = await start();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.checkFailed);
    });

    test('reports when the page cannot be shown', () async {
      fake.checkReturns([appStoreUpdate]);
      fake.onStart = (_) => throw const InAppUpdateException(
            InAppUpdateException.startFailed,
            "Couldn't open the App Store",
          );
      final controller = await start();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.startFailed);
      expect(fake.startCalls, hasLength(1));
    });
  });

  group('not mandatory', () {
    test('shows the App Store page once', () async {
      fake.checkReturns([appStoreUpdate]);
      final controller = await start(mandatory: false);
      expect(fake.startCalls, hasLength(1));
      expect(controller.status, UpdateStatus.canceled);
    });

    test('shows it again on the next resume', () async {
      fake.checkReturns([appStoreUpdate]);
      await start(mandatory: false);
      await sendToBackground();
      await bringToForeground();
      expect(fake.startCalls, hasLength(2));
    });
  });

  group('Android-only behaviour', () {
    test('never subscribes to install states', () async {
      await start();
      expect(fake.installStates.hasListener, isFalse);
    });

    test('completeUpdate does not call native', () async {
      final controller = await start();
      await controller.completeUpdate();
      expect(fake.completeCalls, 0);
    });
  });
}
