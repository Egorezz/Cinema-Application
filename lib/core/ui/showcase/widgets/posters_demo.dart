import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:cinema_app/core/ui/widgets/responsive_grid.dart';
import 'package:flutter/widgets.dart';

/// [PosterCard] grid: long title, broken image and placeholders.
class PostersDemo extends StatelessWidget {
  const PostersDemo({super.key});

  static const _brokenImageUrl = 'https://invalid.example/poster.jpg';
  static const _count = 6;

  @override
  Widget build(BuildContext context) {
    const titles = UiKitStrings.sampleTitles;
    return ResponsiveGrid(
      itemCount: _count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => PosterCard(
        title: index == 0 ? UiKitStrings.longTitle : titles[index - 1],
        subtitle: UiKitStrings.sampleYears[index],
        imageUrl: index == 1 ? _brokenImageUrl : null,
        onTap: () {},
      ),
    );
  }
}
