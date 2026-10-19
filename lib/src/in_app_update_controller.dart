import 'dart:async';

import 'package:flutter/widgets.dart';

import 'in_app_update_api.dart';
import 'types.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,

  /// The Play update UI (Android) or App Store page (iOS) is on screen.
  prompting,

  /// User dismissed the update UI (re-prompted when `mandatory`).
  canceled,
  downloading,

  /// Flexible update ready — call [InAppUpdateController.completeUpdate].
  downloaded,
  installing,
  unsupported,
  error,
}

/// Runs the check → update flow and keeps its state.
///
/// Call [start] to check now, and again every time the app returns to the
/// foreground. [InAppUpdateScope] does this for you.
class InAppUpdateController extends ChangeNotifier {
  InAppUpdateController({
    this.mandatory = true,
    this.type = UpdateType.flexible,
    this.checkOnStart = true,
    this.checkOnResume = true,
    this.onError,
  });

  /// Force every user onto the latest store version. On Android uses the
  /// immediate (full-screen) flow, re-shows it if the user backs out, and
  /// installs flexible downloads as soon as they finish. On iOS shows the App
  /// Store page and re-shows it until the user updates.
  bool mandatory;

  /// Android flow used when [mandatory] is false.
  UpdateType type;

  /// Check as soon as [start] is called (app open).
  final bool checkOnStart;

  /// Check again whenever the app returns to the foreground.
  final bool checkOnResume;

  void Function(InAppUpdateException error)? onError;

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  InAppUpdateException? _error;
  double _progress = 0;

  bool _busy = false;
  bool _started = false;
  bool _disposed = false;
  StreamSubscription<InstallState>? _installStates;
  AppLifecycleListener? _lifecycle;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  InAppUpdateException? get error => _error;

  /// 0–1 download progress for flexible updates.
  double get progress => _progress;

  bool get isStarted => _started;

  /// Starts listening for install progress and app resumes, and checks for an
  /// update if [checkOnStart].
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _installStates = InAppUpdate.installStateChanges.listen(
      _onInstallState,
      onError: _fail,
    );
    if (checkOnResume) _lifecycle = AppLifecycleListener(onResume: checkNow);
    if (checkOnStart) checkNow();
  }

  /// Stops listening. [start] picks up again.
  void stop() {
    _started = false;
    _installStates?.cancel();
    _installStates = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Runs the check → update flow now.
  Future<void> checkNow() async {
    if (_busy || _disposed) return;
    _busy = true;
    var reprompt = false;
    try {
      _error = null;
      _setStatus(UpdateStatus.checking);
      final info = await InAppUpdate.checkForUpdate();
      if (_disposed) return;
      _updateInfo = info;

      if (info.updateAvailability == UpdateAvailability.unsupported) {
        _setStatus(UpdateStatus.unsupported);
        return;
      }
      // A flexible download finished while the app was closed.
      if (info.installStatus == InstallStatus.downloaded) {
        if (mandatory) {
          await completeUpdate();
        } else {
          _setStatus(UpdateStatus.downloaded);
        }
        return;
      }
      if (info.installStatus == InstallStatus.downloading ||
          info.installStatus == InstallStatus.pending) {
        _setStatus(UpdateStatus.downloading);
        return;
      }

      var flow = mandatory ? UpdateType.immediate : type;
      final resumeImmediate =
          info.updateAvailability == UpdateAvailability.inProgress;
      if (!resumeImmediate &&
          info.updateAvailability != UpdateAvailability.available) {
        _setStatus(UpdateStatus.upToDate);
        return;
      }
      if (resumeImmediate) {
        flow = UpdateType.immediate;
      } else if (!info.isAllowed(flow)) {
        // Mandatory but Play won't allow immediate: download flexibly and
        // install automatically once downloaded.
        if (mandatory && info.isFlexibleAllowed) {
          flow = UpdateType.flexible;
        } else {
          _setStatus(UpdateStatus.upToDate);
          return;
        }
      }

      _setStatus(UpdateStatus.prompting);
      final result = await InAppUpdate.startUpdate(flow);
      if (_disposed) return;
      switch (result) {
        case UpdateFlowResult.accepted:
          _setStatus(
            flow == UpdateType.flexible
                ? UpdateStatus.downloading
                : UpdateStatus.installing,
          );
        case UpdateFlowResult.canceled:
          _setStatus(UpdateStatus.canceled);
          reprompt = mandatory;
        case UpdateFlowResult.failed:
          _fail(
            const InAppUpdateException(
              InAppUpdateException.startFailed,
              'The update failed. Please try again.',
            ),
          );
      }
    } catch (e) {
      _fail(e);
    } finally {
      _busy = false;
    }
    // Mandatory: put the update UI straight back. If we're backgrounded, the
    // resume listener re-prompts on return instead.
    if (reprompt && _started && !_disposed && _isForeground) {
      await checkNow();
    }
  }

  /// Installs a downloaded flexible update (restarts the app).
  Future<void> completeUpdate() async {
    _setStatus(UpdateStatus.installing);
    try {
      await InAppUpdate.completeUpdate();
    } catch (e) {
      _fail(e);
    }
  }

  void _onInstallState(InstallState state) {
    if (_disposed) return;
    if (state.totalBytesToDownload > 0) {
      _progress = state.bytesDownloaded / state.totalBytesToDownload;
    }
    switch (state.installStatus) {
      case InstallStatus.pending:
      case InstallStatus.downloading:
        _setStatus(UpdateStatus.downloading);
      case InstallStatus.downloaded:
        _progress = 1;
        if (mandatory) {
          completeUpdate();
        } else {
          _setStatus(UpdateStatus.downloaded);
        }
      case InstallStatus.installing:
        _setStatus(UpdateStatus.installing);
      case InstallStatus.failed:
        _fail(
          InAppUpdateException(
            InAppUpdateException.installFailed,
            'Update install failed (code ${state.installErrorCode})',
          ),
        );
      case InstallStatus.canceled:
        _setStatus(UpdateStatus.canceled);
      case InstallStatus.unknown:
      case InstallStatus.installed:
      case InstallStatus.requiresUiIntent:
        notifyListeners(); // progress may have moved
    }
  }

  void _fail(Object e) {
    if (_disposed) return;
    final error = e is InAppUpdateException
        ? e
        : InAppUpdateException(InAppUpdateException.unknown, e.toString());
    _error = error;
    _setStatus(UpdateStatus.error);
    onError?.call(error);
  }

  void _setStatus(UpdateStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  static bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
