import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:in_app_update_example/main.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Platform extends InAppUpdatePlatform with MockPlatformInterfaceMixin {
  UpdateInfo info = const UpdateInfo(
    updateAvailability: UpdateAvailability.notAvailable,
  );
  final starts = <UpdateType>[];

  @override
  Future<UpdateInfo> checkForUpdate() async => info;

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) async {
    starts.add(type);
    return UpdateFlowResult.canceled;
  }

  @override
  Future<void> completeUpdate() async {}

  @override
  Stream<InstallState> get installStateChanges => const Stream.empty();
}

void main() {
  late _Platform platform;

  setUp(() => InAppUpdatePlatform.instance = platform = _Platform());

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('shows the check result', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(find.text('upToDate'), findsOneWidget);
    expect(find.text('notAvailable'), findsOneWidget);
  }, variant: android);

  testWidgets('switches to flexible updates', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Flexible'));
    await tester.pump();
    // Only now, or mandatory mode would re-prompt the "canceled" fake forever.
    platform.info = const UpdateInfo(
      updateAvailability: UpdateAvailability.available,
      isImmediateAllowed: true,
      isFlexibleAllowed: true,
    );
    await tester.tap(find.text('Check for update'));
    await tester.pump();
    expect(platform.starts.last, UpdateType.flexible);
    expect(find.text('canceled'), findsOneWidget);
  }, variant: android);
}
