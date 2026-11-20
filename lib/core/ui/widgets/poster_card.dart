import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/poster_image.dart';
import 'package:flutter/material.dart';

/// Poster (2:3) with the title below and an optional subtitle (e.g. year).
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.title,
    super.key,
    this.imageUrl,
    this.subtitle,
    this.onTap,
  });

  /// Height of the text block under the poster at text scale 1.0: gaps +
  /// 2 title lines (titleSmall) + 1 subtitle line (bodySmall) + small margin.
  static const double baseTextAreaHeight = 76;

  /// [baseTextAreaHeight] scaled by the user's text scale, so titles don't
  /// overflow when the browser/OS font size is increased.
  static double textAreaHeightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(baseTextAreaHeight);

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Semantics(
      button: onTap != null,
      label: title,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  child: PosterImage(imageUrl: imageUrl),
                ),
              ),
              SizedBox(
                height: textAreaHeightOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      title,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
