import 'package:cinema_app/core/ui/widgets/app_header_line.dart';
import 'package:cinema_app/core/ui/widgets/app_logo.dart';
import 'package:flutter/material.dart';

/// App header as a sliver. Without `actions` it hides on scroll down and
/// returns on any scroll up (floating + snap); with actions it is pinned.
/// Colors come from `AppTheme.appBarTheme`.
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({
    super.key,
    this._title,
    this._actions = const [],
    this._pinned,
    this._leading,
  });

  /// Defaults to [AppLogo].
  final Widget? _title;
  final List<Widget> _actions;

  /// Defaults to `actions.isNotEmpty`.
  final bool? _pinned;
  final Widget? _leading;

  bool get _isPinned => _pinned ?? _actions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      key: const Key('app_sliver_header'),
      pinned: _isPinned,
      floating: !_isPinned,
      snap: !_isPinned,
      title: _title ?? const AppLogo(),
      leading: _leading,
      actions: _actions,
      bottom: const AppHeaderLine(),
    );
  }
}
