import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/app_button.dart';
import 'package:cinema_app/core/ui/widgets/content_container.dart';
import 'package:cinema_app/core/ui/widgets/error_view.dart';
import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:cinema_app/core/ui/widgets/responsive_grid.dart';
import 'package:cinema_app/core/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Debug-only showcase of every ui-kit component (route `/ui-kit`).
class UiKitPage extends StatelessWidget {
  const UiKitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('ui_kit_page'),
      appBar: AppBar(title: const Text(UiKitStrings.title)),
      body: const SingleChildScrollView(
        key: Key('ui_kit_scroll'),
        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(title: UiKitStrings.buttons, child: _ButtonsDemo()),
              _Section(title: UiKitStrings.inputs, child: _InputsDemo()),
              _Section(title: UiKitStrings.posters, child: _PostersDemo()),
              _Section(title: UiKitStrings.skeletons, child: _SkeletonsDemo()),
              _Section(title: UiKitStrings.errors, child: _ErrorDemo()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.m),
          child,
        ],
      ),
    );
  }
}

class _ButtonsDemo extends StatelessWidget {
  const _ButtonsDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        AppButton(label: UiKitStrings.primary, onPressed: () {}),
        AppButton(
          label: UiKitStrings.secondary,
          variant: AppButtonVariant.secondary,
          icon: Icons.add,
          onPressed: () {},
        ),
        AppButton(
          label: UiKitStrings.text,
          variant: AppButtonVariant.text,
          onPressed: () {},
        ),
        AppButton(
          label: UiKitStrings.loading,
          isLoading: true,
          onPressed: () {},
        ),
        const AppButton(label: UiKitStrings.disabled, onPressed: null),
      ],
    );
  }
}

class _InputsDemo extends StatelessWidget {
  const _InputsDemo();

  @override
  Widget build(BuildContext context) {
    return const TextField(
      decoration: InputDecoration(
        labelText: UiKitStrings.inputLabel,
        hintText: UiKitStrings.inputHint,
      ),
    );
  }
}

class _PostersDemo extends StatelessWidget {
  const _PostersDemo();

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

class _SkeletonsDemo extends StatelessWidget {
  const _SkeletonsDemo();

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => const PosterCardSkeleton(),
    );
  }
}

class _ErrorDemo extends StatelessWidget {
  const _ErrorDemo();

  static const double _height = 320;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ErrorView(message: UiKitStrings.errorMessage, onRetry: () {}),
    );
  }
}
