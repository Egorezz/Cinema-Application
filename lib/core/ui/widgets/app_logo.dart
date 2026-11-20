import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Brand logo: red mark followed by the brand name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Text(
          AppStrings.brandName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: AppColors.onHeader,
          ),
        ),
      ],
    );
  }
}
