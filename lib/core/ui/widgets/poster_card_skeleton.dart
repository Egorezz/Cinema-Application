import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:cinema_app/core/ui/widgets/skeleton.dart';
import 'package:flutter/widgets.dart';

/// Loading placeholder with the same geometry as `PosterCard`:
/// a 2:3 poster box and two text bars.
class PosterCardSkeleton extends StatelessWidget {
  const PosterCardSkeleton({super.key});

  static const double _titleBarHeight = 14;
  static const double _subtitleBarHeight = 12;
  static const double _subtitleWidthFactor = 0.6;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AspectRatio(
          aspectRatio: 2 / 3,
          child: Skeleton(borderRadius: AppSpacing.radiusM),
        ),
        SizedBox(
          height: PosterCard.textAreaHeightOf(context),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.s),
              Skeleton(height: _titleBarHeight),
              SizedBox(height: AppSpacing.xs),
              FractionallySizedBox(
                widthFactor: _subtitleWidthFactor,
                child: Skeleton(height: _subtitleBarHeight),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
