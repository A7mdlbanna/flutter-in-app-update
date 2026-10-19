import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_in_app_update.dart';
import 'types.dart';

/// Native side of the plugin. Apps use [InAppUpdate] instead.
abstract class InAppUpdatePlatform extends PlatformInterface {
  InAppUpdatePlatform() : super(token: _token);

  static final Object _token = Object();

  static InAppUpdatePlatform _instance = MethodChannelInAppUpdate();

  /// Defaults to [MethodChannelInAppUpdate].
  static InAppUpdatePlatform get instance => _instance;

  static set instance(InAppUpdatePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<UpdateInfo> checkForUpdate() {
    throw UnimplementedError('checkForUpdate() has not been implemented.');
  }

  Future<UpdateFlowResult> startUpdate(UpdateType type) {
    throw UnimplementedError('startUpdate() has not been implemented.');
  }

  Future<void> completeUpdate() {
    throw UnimplementedError('completeUpdate() has not been implemented.');
  }

  /// Flexible update progress. Android only.
  Stream<InstallState> get installStateChanges {
    throw UnimplementedError('installStateChanges has not been implemented.');
  }
}
