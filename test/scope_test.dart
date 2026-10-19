import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

import 'fake_platform.dart';

void main() {
  late FakeInAppUpdatePlatform fake;

  setUp(() {
    fake = FakeInAppUpdatePlatform();
    InAppUpdatePlatform.instance = fake;
  });

  tearDown(() => setLifecycle(AppLifecycleState.resumed));

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Widget app({
    bool mandatory = true,
    bool enabled = true,
    InAppUpdateController? controller,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppUpdateScope(
          mandatory: mandatory,
          enabled: enabled,
          controller: controller,
          child: Builder(
            builder: (context) =>
                Text(InAppUpdateScope.of(context).status.name),
          ),
        ),
      );

  testWidgets('checks on mount and rebuilds dependents', (tester) async {
    fake.checkReturns([playUpdate]);
    fake.startReturns([UpdateFlowResult.accepted]);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(fake.checkCalls, 1);
    expect(fake.startCalls, [UpdateType.immediate]);
    expect(find.text('installing'), findsOneWidget);
  }, variant: android);

  testWidgets('enabled: false does nothing until enabled', (tester) async {
    await tester.pumpWidget(app(enabled: false));
    await tester.pump();
    expect(fake.checkCalls, 0);
    expect(find.text('idle'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pump();
    expect(fake.checkCalls, 1);
    expect(find.text('upToDate'), findsOneWidget);
  }, variant: android);

  testWidgets('passes mandatory changes to its controller', (tester) async {
    fake.checkReturns([playUpdate]);
    await tester.pumpWidget(app(mandatory: false));
    await tester.pump();
    expect(fake.startCalls, [UpdateType.flexible]);

    await tester.pumpWidget(app());
    final controller = InAppUpdateScope.of(tester.element(find.byType(Text)));
    await controller.checkNow();
    expect(fake.startCalls, [UpdateType.flexible, UpdateType.immediate]);
  }, variant: android);

  testWidgets('stops its own controller on unmount', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(fake.installStates.hasListener, isFalse);
    setLifecycle(AppLifecycleState.paused);
    setLifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(fake.checkCalls, 1);
  }, variant: android);

  testWidgets('starts but never disposes an external controller', (
    tester,
  ) async {
    final controller = InAppUpdateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller));
    await tester.pump();
    expect(controller.isStarted, isTrue);
    expect(fake.checkCalls, 1);

    await tester.pumpWidget(const SizedBox());
    expect(controller.isStarted, isFalse);
    await controller.checkNow(); // still usable, so not disposed
    expect(fake.checkCalls, 2);
  }, variant: android);

  testWidgets('maybeOf is null outside a scope', (tester) async {
    late InAppUpdateController? found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = InAppUpdateScope.maybeOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(found, isNull);
  });
}
