import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button: [AppButtonVariant.primary] is a [FilledButton],
/// [AppButtonVariant.secondary] an [OutlinedButton], [AppButtonVariant.text]
/// a [TextButton].
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Shows a progress indicator instead of [icon] and disables the button.
  final bool isLoading;

  /// Stretches the button to the available width.
  final bool expand;

  static const double _indicatorSize = 16;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final leading = isLoading
        ? const SizedBox.square(
            dimension: _indicatorSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
        ? null
        : Icon(icon, size: 18);
    // Framework .icon constructors lay out icon + label safely under both
    // bounded and unbounded width (AppBar actions, Row, dialog actions).
    final button = switch ((variant, leading)) {
      (AppButtonVariant.primary, null) => FilledButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (AppButtonVariant.primary, final Widget icon) => FilledButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
      (AppButtonVariant.secondary, null) => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (AppButtonVariant.secondary, final Widget icon) => OutlinedButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
      (AppButtonVariant.text, null) => TextButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (AppButtonVariant.text, final Widget icon) => TextButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
    };
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
