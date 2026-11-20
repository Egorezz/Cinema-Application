import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:flutter/widgets.dart';

/// Pulsing placeholder box shown while content is loading.
/// Static when the platform asks to disable animations.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppSpacing.radiusS,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.4,
    end: 1,
  ).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.skeleton,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

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
