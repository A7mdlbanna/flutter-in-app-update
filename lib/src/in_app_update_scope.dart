import 'package:flutter/widgets.dart';

import 'in_app_update_controller.dart';
import 'types.dart';

/// Keeps the app on the latest store version. Real-app usage is one widget at
/// the root:
///
/// ```dart
/// InAppUpdateScope(child: MyApp()) // mandatory: every user must update
/// ```
///
/// Descendants read the state with [InAppUpdateScope.of].
class InAppUpdateScope extends StatefulWidget {
  const InAppUpdateScope({
    super.key,
    this.controller,
    this.mandatory = true,
    this.type = UpdateType.flexible,
    this.checkOnResume = true,
    this.enabled = true,
    this.onError,
    required this.child,
  });

  /// Use your own controller instead of one created by the scope. The scope
  /// starts and stops it but never disposes it, and [mandatory], [type],
  /// [checkOnResume] and [onError] are ignored: set them on the controller.
  final InAppUpdateController? controller;

  /// See [InAppUpdateController.mandatory].
  final bool mandatory;

  /// See [InAppUpdateController.type].
  final UpdateType type;

  /// See [InAppUpdateController.checkOnResume]. Read once, when the scope is
  /// first built.
  final bool checkOnResume;

  /// Turn updates off, e.g. in dev builds not installed from the store.
  final bool enabled;

  final void Function(InAppUpdateException error)? onError;

  final Widget child;

  /// The nearest scope's controller. Rebuilds [context] when it changes.
  static InAppUpdateController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No InAppUpdateScope found in context');
    return controller!;
  }

  static InAppUpdateController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_InAppUpdateInherited>()
      ?.notifier;

  @override
  State<InAppUpdateScope> createState() => _InAppUpdateScopeState();
}

class _InAppUpdateScopeState extends State<InAppUpdateScope> {
  InAppUpdateController? _owned;

  InAppUpdateController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _owned = _createController();
    if (widget.enabled) _controller.start();
  }

  InAppUpdateController _createController() => InAppUpdateController(
        mandatory: widget.mandatory,
        type: widget.type,
        checkOnResume: widget.checkOnResume,
        onError: widget.onError,
      );

  @override
  void didUpdateWidget(InAppUpdateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _owned!;
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _owned!.dispose();
        _owned = null;
      } else {
        old.stop();
      }
      if (widget.controller == null) _owned = _createController();
      if (widget.enabled) _controller.start();
      return;
    }
    if (_owned != null) {
      _owned!
        ..mandatory = widget.mandatory
        ..type = widget.type
        ..onError = widget.onError;
    }
    if (widget.enabled && !_controller.isStarted) {
      _controller.start();
    } else if (!widget.enabled && _controller.isStarted) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    if (_owned != null) {
      _owned!.dispose();
    } else {
      widget.controller!.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _InAppUpdateInherited(notifier: _controller, child: widget.child);
}

class _InAppUpdateInherited extends InheritedNotifier<InAppUpdateController> {
  const _InAppUpdateInherited({required super.notifier, required super.child});
}
