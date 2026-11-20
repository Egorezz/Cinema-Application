import 'package:cinema_app/core/l10n/ui_kit_strings.dart';
import 'package:cinema_app/core/ui/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// [ErrorView] with a retry button in a fixed-height box.
class ErrorDemo extends StatelessWidget {
  const ErrorDemo({super.key});

  static const double _height = 320;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ErrorView(message: UiKitStrings.errorMessage, onRetry: () {}),
    );
  }
}
