import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Titled block of the ui-kit showcase.
class ShowcaseSection extends StatelessWidget {
  const ShowcaseSection({required this.title, required this.child, super.key});

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
