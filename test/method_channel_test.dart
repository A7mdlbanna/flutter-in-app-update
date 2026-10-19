import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update_kit/in_app_update_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelInAppUpdate platform;
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) reply;

  setUp(() {
    platform = MethodChannelInAppUpdate();
    calls = [];
    reply = (_) => null;
    messenger.setMockMethodCallHandler(platform.methodChannel, (call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(platform.methodChannel, null);
    messenger.setMockStreamHandler(platform.eventChannel, null);
  });

  test('is the default platform', () {
    expect(InAppUpdatePlatform.instance, isA<MethodChannelInAppUpdate>());
  });

  test('checkForUpdate parses the native map', () async {
    reply = (_) => {
          'updateAvailability': 'available',
          'availableVersionCode': 7,
          'isImmediateAllowed': true,
        };
    final info = await platform.checkForUpdate();
    expect(calls.single.method, 'checkForUpdate');
    expect(info.updateAvailability, UpdateAvailability.available);
    expect(info.availableVersionCode, 7);
    expect(info.isImmediateAllowed, isTrue);
  });

  test('startUpdate sends the flow type', () async {
    reply = (_) => 'canceled';
    expect(
      await platform.startUpdate(UpdateType.flexible),
      UpdateFlowResult.canceled,
    );
    expect(calls.single.method, 'startUpdate');
    expect(calls.single.arguments, {'type': 'flexible'});
  });

  test('completeUpdate calls native', () async {
    await platform.completeUpdate();
    expect(calls.single.method, 'completeUpdate');
  });

  test('native errors become InAppUpdateException', () async {
    reply = (_) => throw PlatformException(
          code: 'E_NOT_AVAILABLE',
          message: 'No immediate update is available',
        );
    await expectLater(
      platform.startUpdate(UpdateType.immediate),
      throwsA(
        isA<InAppUpdateException>()
            .having((e) => e.code, 'code', InAppUpdateException.notAvailable)
            .having(
              (e) => e.message,
              'message',
              'No immediate update is available',
            ),
      ),
    );
  });

  test('installStateChanges parses native events', () async {
    messenger.setMockStreamHandler(
      platform.eventChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success({
            'installStatus': 'downloading',
            'installErrorCode': 0,
            'bytesDownloaded': 25,
            'totalBytesToDownload': 100,
          });
          sink.endOfStream();
        },
      ),
    );
    expect(await platform.installStateChanges.toList(), const [
      InstallState(
        installStatus: InstallStatus.downloading,
        bytesDownloaded: 25,
        totalBytesToDownload: 100,
      ),
    ]);
  });
}
