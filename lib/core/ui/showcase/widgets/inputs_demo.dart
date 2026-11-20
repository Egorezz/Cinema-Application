import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:flutter/material.dart';

/// Text field styled by the app input theme.
class InputsDemo extends StatelessWidget {
  const InputsDemo({super.key});

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
