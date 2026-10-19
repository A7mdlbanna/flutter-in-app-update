import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Scriptable stand-in for the Kotlin/Swift side.
class FakeInAppUpdatePlatform extends InAppUpdatePlatform
    with MockPlatformInterfaceMixin {
  Future<UpdateInfo> Function() onCheck = () async => upToDate;
  Future<UpdateFlowResult> Function(UpdateType type) onStart =
      (_) async => UpdateFlowResult.accepted;
  Future<void> Function() onComplete = () async {};

  final installStates = StreamController<InstallState>.broadcast();

  int checkCalls = 0;
  final startCalls = <UpdateType>[];
  int completeCalls = 0;

  /// Answers checks in order, repeating the last one.
  void checkReturns(List<UpdateInfo> infos) {
    var i = 0;
    onCheck = () async => infos[i < infos.length - 1 ? i++ : i];
  }

  /// Answers starts in order, repeating the last one.
  void startReturns(List<UpdateFlowResult> results) {
    var i = 0;
    onStart = (_) async => results[i < results.length - 1 ? i++ : i];
  }

  void emit(InstallState state) => installStates.add(state);

  @override
  Future<UpdateInfo> checkForUpdate() {
    checkCalls++;
    return onCheck();
  }

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) {
    startCalls.add(type);
    return onStart(type);
  }

  @override
  Future<void> completeUpdate() {
    completeCalls++;
    return onComplete();
  }

  @override
  Stream<InstallState> get installStateChanges => installStates.stream;
}

const upToDate = UpdateInfo(
  updateAvailability: UpdateAvailability.notAvailable,
);

/// A Play update with both flows allowed.
const playUpdate = UpdateInfo(
  updateAvailability: UpdateAvailability.available,
  availableVersionCode: 42,
  isImmediateAllowed: true,
  isFlexibleAllowed: true,
  clientVersionStalenessDays: 3,
);

/// What iOS reports for a newer App Store version.
const appStoreUpdate = UpdateInfo(
  updateAvailability: UpdateAvailability.available,
  availableVersion: '2.1.0',
  releaseNotes: 'Bug fixes',
  isImmediateAllowed: true,
  isFlexibleAllowed: true,
  clientVersionStalenessDays: 2,
);

const notInStore = UpdateInfo(
  updateAvailability: UpdateAvailability.notAvailable,
);

UpdateInfo withInstallStatus(UpdateInfo info, InstallStatus status) =>
    UpdateInfo(
      updateAvailability: info.updateAvailability,
      installStatus: status,
      availableVersionCode: info.availableVersionCode,
      isImmediateAllowed: info.isImmediateAllowed,
      isFlexibleAllowed: info.isFlexibleAllowed,
    );

/// Installs a fresh fake and pretends to run on [platform]. Call from setUp.
FakeInAppUpdatePlatform installFakePlatform(TargetPlatform platform) {
  final fake = FakeInAppUpdatePlatform();
  InAppUpdatePlatform.instance = fake;
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    setLifecycle(AppLifecycleState.resumed);
  });
  return fake;
}

const _lifecycleOrder = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

/// Walks the app through each lifecycle step to [target], like the OS does.
void setLifecycle(AppLifecycleState target) {
  final binding = TestWidgetsFlutterBinding.instance;
  var current = binding.lifecycleState ?? AppLifecycleState.resumed;
  if (binding.lifecycleState == null) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
  var i = _lifecycleOrder.indexOf(current);
  final to = _lifecycleOrder.indexOf(target);
  while (i != to) {
    i += to > i ? 1 : -1;
    current = _lifecycleOrder[i];
    binding.handleAppLifecycleStateChanged(current);
  }
}

Future<void> sendToBackground() async {
  setLifecycle(AppLifecycleState.paused);
  await pumpEventQueue();
}

Future<void> bringToForeground() async {
  setLifecycle(AppLifecycleState.resumed);
  await pumpEventQueue();
}
