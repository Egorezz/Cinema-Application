import 'dart:math' as math;

import 'package:cinema_app/core/ui/breakpoints.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:flutter/widgets.dart';

/// Adaptive grid of posters (or poster skeletons). The column count follows
/// the available width, not the screen width, so it works inside
/// `ContentContainer` and side panels.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this._itemCount,
    required this._itemBuilder,
    super.key,
    this._shrinkWrap = false,
    this._physics,
  });

  final int _itemCount;
  final IndexedWidgetBuilder _itemBuilder;
  final bool _shrinkWrap;
  final ScrollPhysics? _physics;

  static int columnsFor(ScreenSize size) => switch (size) {
    ScreenSize.mobile => 2,
    ScreenSize.tablet => 4,
    ScreenSize.desktop => 6,
  };

  static double _spacingFor(ScreenSize size) =>
      size == ScreenSize.mobile ? AppSpacing.m : AppSpacing.l;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth,
          'ResponsiveGrid needs a bounded width (not inside a horizontal '
          'scroll view or an unconstrained Row).',
        );
        final size = ScreenSize.fromWidth(constraints.maxWidth);
        final columns = columnsFor(size);
        final spacing = _spacingFor(size);
        // Clamped: during width animations maxWidth can be smaller than the
        // gaps, and a negative extent would trip the grid delegate asserts.
        final cellWidth = math.max(
          0,
          (constraints.maxWidth - spacing * (columns - 1)) / columns,
        );
        return GridView.builder(
          shrinkWrap: _shrinkWrap,
          physics: _physics,
          padding: EdgeInsets.zero,
          itemCount: _itemCount,
          itemBuilder: _itemBuilder,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent:
                cellWidth * 1.5 + PosterCard.textAreaHeightOf(context),
          ),
        );
      },
    );
  }
}
