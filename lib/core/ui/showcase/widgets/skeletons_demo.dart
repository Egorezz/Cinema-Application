import 'package:cinema_app/core/ui/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Grid of [PosterCardSkeleton]s.
class SkeletonsDemo extends StatelessWidget {
  const SkeletonsDemo({super.key});

  static const _count = 6;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      itemCount: _count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => const PosterCardSkeleton(),
    );
  }
}
