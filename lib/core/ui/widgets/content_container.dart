import 'package:cinema_app/core/ui/breakpoints.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:flutter/widgets.dart';

/// Centers page content horizontally, limits its width and applies the
/// horizontal page padding of the current [ScreenSize].
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    required this.child,
    super.key,
    this.maxWidth = 1440,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = switch (context.screenSize) {
      ScreenSize.mobile => AppSpacing.m,
      ScreenSize.tablet => AppSpacing.l,
      ScreenSize.desktop => AppSpacing.xl,
    };
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
