import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'in_app_update_platform_interface.dart';
import 'types.dart';

/// [InAppUpdatePlatform] backed by the plugin's Kotlin and Swift code.
class MethodChannelInAppUpdate extends InAppUpdatePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('in_app_update_kit');

  @visibleForTesting
  final eventChannel = const EventChannel('in_app_update_kit/install_state');

  Stream<InstallState>? _installStateChanges;

  @override
  Future<UpdateInfo> checkForUpdate() => _guard(() async {
        final map = await methodChannel.invokeMapMethod<Object?, Object?>(
          'checkForUpdate',
        );
        return UpdateInfo.fromMap(map ?? const {});
      });

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) => _guard(() async {
        final result = await methodChannel.invokeMethod<String>('startUpdate', {
          'type': type.name,
        });
        return UpdateFlowResult.fromWire(result);
      });

  @override
  Future<void> completeUpdate() =>
      _guard(() => methodChannel.invokeMethod<void>('completeUpdate'));

  @override
  Stream<InstallState> get installStateChanges =>
      _installStateChanges ??= eventChannel.receiveBroadcastStream().map(
            (event) => InstallState.fromMap(event as Map<Object?, Object?>),
          );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw InAppUpdateException(e.code, e.message ?? e.code);
    }
  }
}
