import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Neutral poster box with a movie icon, shown when there is no image.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('poster_placeholder'),
      color: AppColors.skeleton,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }
}
