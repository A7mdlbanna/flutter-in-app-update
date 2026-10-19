import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

import 'fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeInAppUpdatePlatform fake;

  setUp(() => fake = installFakePlatform(TargetPlatform.android));

  Future<InAppUpdateController> start({
    bool mandatory = true,
    UpdateType type = UpdateType.flexible,
    bool checkOnStart = true,
    bool checkOnResume = true,
    void Function(InAppUpdateException error)? onError,
  }) async {
    final controller = InAppUpdateController(
      mandatory: mandatory,
      type: type,
      checkOnStart: checkOnStart,
      checkOnResume: checkOnResume,
      onError: onError,
    );
    addTearDown(controller.dispose);
    controller.start();
    await pumpEventQueue();
    return controller;
  }

  group('mandatory (default)', () {
    test('checks for an update on start', () async {
      await start();
      expect(fake.checkCalls, 1);
    });

    test('does nothing when the app is up to date', () async {
      final controller = await start();
      expect(controller.status, UpdateStatus.upToDate);
      expect(controller.updateInfo, upToDate);
      expect(fake.startCalls, isEmpty);
    });

    test('treats unknown availability as up to date', () async {
      fake.checkReturns([
        const UpdateInfo(updateAvailability: UpdateAvailability.unknown),
      ]);
      final controller = await start();
      expect(controller.status, UpdateStatus.upToDate);
      expect(fake.startCalls, isEmpty);
    });

    test('shows "prompting" while the Play UI is open', () async {
      fake.checkReturns([playUpdate]);
      final flow = Completer<UpdateFlowResult>();
      fake.onStart = (_) => flow.future;
      final controller = await start();
      expect(controller.status, UpdateStatus.prompting);
      flow.complete(UpdateFlowResult.accepted);
    });

    test('starts an immediate update when one is available', () async {
      fake.checkReturns([playUpdate]);
      final controller = await start();
      expect(fake.startCalls, [UpdateType.immediate]);
      expect(controller.status, UpdateStatus.installing);
    });

    test('uses immediate even when type is flexible', () async {
      fake.checkReturns([playUpdate]);
      await start(type: UpdateType.flexible);
      expect(fake.startCalls, [UpdateType.immediate]);
    });

    test('re-prompts straight away when the user cancels', () async {
      fake.checkReturns([playUpdate]);
      fake.startReturns([UpdateFlowResult.canceled, UpdateFlowResult.accepted]);
      final controller = await start();
      expect(fake.checkCalls, 2);
      expect(fake.startCalls, [UpdateType.immediate, UpdateType.immediate]);
      expect(controller.status, UpdateStatus.installing);
    });

    test('re-prompts on resume when canceled in the background', () async {
      fake.checkReturns([playUpdate]);
      final flow = Completer<UpdateFlowResult>();
      fake.onStart = (_) => flow.future;
      final controller = await start();

      await sendToBackground();
      flow.complete(UpdateFlowResult.canceled);
      await pumpEventQueue();
      expect(controller.status, UpdateStatus.canceled);
      expect(fake.startCalls, hasLength(1));

      fake.startReturns([UpdateFlowResult.accepted]);
      await bringToForeground();
      expect(fake.startCalls, hasLength(2));
      expect(controller.status, UpdateStatus.installing);
    });

    test('resumes an immediate update that was left in progress', () async {
      fake.checkReturns([
        const UpdateInfo(updateAvailability: UpdateAvailability.inProgress),
      ]);
      await start(type: UpdateType.flexible);
      expect(fake.startCalls, [UpdateType.immediate]);
    });

    test(
      'falls back to flexible and auto-installs when immediate is not allowed',
      () async {
        fake.checkReturns([
          const UpdateInfo(
            updateAvailability: UpdateAvailability.available,
            isImmediateAllowed: false,
            isFlexibleAllowed: true,
          ),
        ]);
        final controller = await start();
        expect(fake.startCalls, [UpdateType.flexible]);
        expect(controller.status, UpdateStatus.downloading);

        fake.emit(const InstallState(installStatus: InstallStatus.downloaded));
        await pumpEventQueue();
        expect(fake.completeCalls, 1);
        expect(controller.status, UpdateStatus.installing);
      },
    );

    test('stays up to date when Play allows neither flow', () async {
      fake.checkReturns([
        const UpdateInfo(updateAvailability: UpdateAvailability.available),
      ]);
      final controller = await start();
      expect(controller.status, UpdateStatus.upToDate);
      expect(fake.startCalls, isEmpty);
    });

    test('installs a flexible update downloaded in a previous session',
        () async {
      fake.checkReturns([
        withInstallStatus(playUpdate, InstallStatus.downloaded),
      ]);
      final controller = await start();
      expect(fake.completeCalls, 1);
      expect(fake.startCalls, isEmpty);
      expect(controller.status, UpdateStatus.installing);
    });

    test('waits for a download already in progress', () async {
      for (final status in [InstallStatus.downloading, InstallStatus.pending]) {
        fake.checkReturns([withInstallStatus(playUpdate, status)]);
        final controller = await start();
        expect(controller.status, UpdateStatus.downloading);
      }
      expect(fake.startCalls, isEmpty);
    });

    test('installs automatically when a flexible download finishes', () async {
      final controller = await start();
      fake.emit(
        const InstallState(
          installStatus: InstallStatus.downloading,
          bytesDownloaded: 50,
          totalBytesToDownload: 100,
        ),
      );
      await pumpEventQueue();
      expect(controller.status, UpdateStatus.downloading);
      expect(controller.progress, 0.5);

      fake.emit(const InstallState(installStatus: InstallStatus.downloaded));
      await pumpEventQueue();
      expect(controller.progress, 1);
      expect(fake.completeCalls, 1);
    });
  });

  group('not mandatory', () {
    test('uses the flexible flow by default', () async {
      fake.checkReturns([playUpdate]);
      final controller = await start(mandatory: false);
      expect(fake.startCalls, [UpdateType.flexible]);
      expect(controller.status, UpdateStatus.downloading);
    });

    test('uses the immediate flow when asked', () async {
      fake.checkReturns([playUpdate]);
      final controller = await start(
        mandatory: false,
        type: UpdateType.immediate,
      );
      expect(fake.startCalls, [UpdateType.immediate]);
      expect(controller.status, UpdateStatus.installing);
    });

    test('lets the user choose when to install', () async {
      final controller = await start(mandatory: false);
      fake.emit(const InstallState(installStatus: InstallStatus.downloaded));
      await pumpEventQueue();
      expect(controller.status, UpdateStatus.downloaded);
      expect(fake.completeCalls, 0);

      await controller.completeUpdate();
      expect(fake.completeCalls, 1);
      expect(controller.status, UpdateStatus.installing);
    });

    test('reports a download from a previous session as downloaded', () async {
      fake.checkReturns([
        withInstallStatus(playUpdate, InstallStatus.downloaded),
      ]);
      final controller = await start(mandatory: false);
      expect(controller.status, UpdateStatus.downloaded);
      expect(fake.completeCalls, 0);
    });

    test('does not re-prompt when the user cancels', () async {
      fake.checkReturns([playUpdate]);
      fake.startReturns([UpdateFlowResult.canceled]);
      final controller = await start(mandatory: false);
      expect(controller.status, UpdateStatus.canceled);
      expect(fake.startCalls, hasLength(1));
    });

    test('does not let Play pick a flow it disallows', () async {
      fake.checkReturns([
        const UpdateInfo(
          updateAvailability: UpdateAvailability.available,
          isImmediateAllowed: true,
        ),
      ]);
      final controller = await start(mandatory: false);
      expect(controller.status, UpdateStatus.upToDate);
      expect(fake.startCalls, isEmpty);
    });
  });

  group('when to check', () {
    test('checks again when the app returns to the foreground', () async {
      await start();
      await sendToBackground();
      await bringToForeground();
      expect(fake.checkCalls, 2);
    });

    test('checkOnResume: false only checks on start', () async {
      await start(checkOnResume: false);
      await sendToBackground();
      await bringToForeground();
      expect(fake.checkCalls, 1);
    });

    test('checkOnStart: false waits for checkNow', () async {
      final controller = await start(checkOnStart: false);
      expect(fake.checkCalls, 0);
      expect(controller.status, UpdateStatus.idle);
      await controller.checkNow();
      expect(fake.checkCalls, 1);
    });

    test('ignores checks while one is running', () async {
      final check = Completer<UpdateInfo>();
      fake.onCheck = () => check.future;
      final controller = await start();
      await controller.checkNow();
      await sendToBackground();
      await bringToForeground();
      expect(fake.checkCalls, 1);
      check.complete(upToDate);
    });

    test('stop() stops listening until start() again', () async {
      final controller = await start();
      controller.stop();
      expect(fake.installStates.hasListener, isFalse);
      await sendToBackground();
      await bringToForeground();
      expect(fake.checkCalls, 1);

      controller.start();
      await pumpEventQueue();
      expect(fake.installStates.hasListener, isTrue);
      expect(fake.checkCalls, 2);
    });

    test('dispose mid-check drops the result quietly', () async {
      final check = Completer<UpdateInfo>();
      fake.onCheck = () => check.future;
      final controller = InAppUpdateController()..start();
      controller.dispose();
      check.complete(playUpdate);
      await pumpEventQueue();
      expect(fake.startCalls, isEmpty);
    });
  });

  group('errors', () {
    test('reports a failed check without throwing', () async {
      const failure = InAppUpdateException(
        InAppUpdateException.checkFailed,
        'Install Error(-10)',
      );
      fake.onCheck = () => throw failure;
      final errors = <InAppUpdateException>[];
      final controller = await start(onError: errors.add);
      expect(controller.status, UpdateStatus.error);
      expect(controller.error, failure);
      expect(errors, [failure]);
    });

    test('reports a failed startUpdate', () async {
      fake.checkReturns([playUpdate]);
      fake.onStart = (_) => throw const InAppUpdateException(
            InAppUpdateException.noActivity,
            'No foreground activity',
          );
      final controller = await start();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.noActivity);
    });

    test('reports a "failed" update result', () async {
      fake.checkReturns([playUpdate]);
      fake.startReturns([UpdateFlowResult.failed]);
      final controller = await start();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.startFailed);
      expect(fake.startCalls, hasLength(1)); // no re-prompt loop
    });

    test('wraps other errors', () async {
      fake.onCheck = () => throw StateError('boom');
      final controller = await start();
      expect(controller.error?.code, InAppUpdateException.unknown);
      expect(controller.error?.message, contains('boom'));
    });

    test('reports a failed install', () async {
      fake.checkReturns([
        withInstallStatus(playUpdate, InstallStatus.downloaded),
      ]);
      fake.onComplete = () => throw const InAppUpdateException(
            InAppUpdateException.completeFailed,
            'Install failed',
          );
      final controller = await start();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.completeFailed);
    });

    test('reports a failed download with the Play error code', () async {
      final controller = await start();
      fake.emit(
        const InstallState(
          installStatus: InstallStatus.failed,
          installErrorCode: -6,
        ),
      );
      await pumpEventQueue();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, InAppUpdateException.installFailed);
      expect(controller.error?.message, contains('-6'));
    });

    test('clears the error on the next check', () async {
      fake.onCheck = () => throw StateError('offline');
      final controller = await start();
      expect(controller.error, isNotNull);

      fake.checkReturns([upToDate]);
      await controller.checkNow();
      expect(controller.error, isNull);
      expect(controller.status, UpdateStatus.upToDate);
    });

    test('calls the latest onError', () async {
      final first = <InAppUpdateException>[];
      final second = <InAppUpdateException>[];
      fake.onCheck = () => throw StateError('offline');
      final controller = await start(onError: first.add);
      controller.onError = second.add;
      await controller.checkNow();
      expect(first, hasLength(1));
      expect(second, hasLength(1));
    });
  });
}
