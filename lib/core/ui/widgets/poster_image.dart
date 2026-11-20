import 'package:cinema_app/core/ui/widgets/poster_placeholder.dart';
import 'package:cinema_app/core/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Network poster image: a skeleton while loading, [PosterPlaceholder] when
/// the url is missing or fails to load.
class PosterImage extends StatelessWidget {
  const PosterImage({required this.imageUrl, super.key});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl;
    if (imageUrl == null) return const PosterPlaceholder();
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Skeleton(borderRadius: 0);
      },
      errorBuilder: (context, error, stackTrace) => const PosterPlaceholder(),
    );
  }
}
