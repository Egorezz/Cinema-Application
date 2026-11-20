import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/widgets.dart';
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
        AppButton.primary(label: UiKitStrings.primary, onPressed: () {}),
        AppButton.secondary(
          label: UiKitStrings.secondary,
          icon: Icons.add,
          onPressed: () {},
        ),
        AppButton.text(label: UiKitStrings.text, onPressed: () {}),
        AppButton.primary(
          label: UiKitStrings.loading,
          isLoading: true,
          onPressed: () {},
        ),
        const AppButton.primary(label: UiKitStrings.disabled, onPressed: null),
      ],
    );
  }
}
