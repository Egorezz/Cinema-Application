import 'package:cinema_app/core/ui/widgets/app_header_line.dart';
import 'package:cinema_app/core/ui/widgets/app_logo.dart';
import 'package:flutter/material.dart';

/// App header as a sliver. Without [actions] it hides on scroll down and
/// returns on any scroll up (floating + snap); with actions it is pinned.
/// Colors come from `AppTheme.appBarTheme`.
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({
    super.key,
    this.title,
    this.actions = const [],
    this.pinned,
    this.leading,
  });

  /// Defaults to [AppLogo].
  final Widget? title;
  final List<Widget> actions;

  /// Defaults to `actions.isNotEmpty`.
  final bool? pinned;
  final Widget? leading;

  bool get isPinned => pinned ?? actions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      key: const Key('app_sliver_header'),
      pinned: isPinned,
      floating: !isPinned,
      snap: !isPinned,
      title: title ?? const AppLogo(),
      leading: leading,
      actions: actions,
      bottom: const AppHeaderLine(),
    );
  }
}
