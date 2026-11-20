import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/showcase/widgets/widgets.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Debug-only showcase of every ui-kit component (route `/ui-kit`).
class UiKitPage extends StatelessWidget {
  const UiKitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('ui_kit_page'),
      body: CustomScrollView(
        key: Key('ui_kit_scroll'),
        slivers: [
          AppSliverHeader(title: Text(UiKitStrings.title)),
          SliverPadding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
            sliver: SliverToBoxAdapter(
              child: ContentContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShowcaseSection(
                      title: UiKitStrings.header,
                      child: Text(UiKitStrings.headerHint),
                    ),
                    ShowcaseSection(
                      title: UiKitStrings.buttons,
                      child: ButtonsDemo(),
                    ),
                    ShowcaseSection(
                      title: UiKitStrings.inputs,
                      child: InputsDemo(),
                    ),
                    ShowcaseSection(
                      title: UiKitStrings.posters,
                      child: PostersDemo(),
                    ),
                    ShowcaseSection(
                      title: UiKitStrings.skeletons,
                      child: SkeletonsDemo(),
                    ),
                    ShowcaseSection(
                      title: UiKitStrings.errors,
                      child: ErrorDemo(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
