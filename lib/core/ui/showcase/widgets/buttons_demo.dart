import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Every [AppButton] variant and state.
class ButtonsDemo extends StatelessWidget {
  const ButtonsDemo({super.key});

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
