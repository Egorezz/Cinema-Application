import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button: [AppButtonVariant.primary] is a [FilledButton],
/// [AppButtonVariant.secondary] an [OutlinedButton], [AppButtonVariant.text]
/// a [TextButton].
class AppButton extends StatelessWidget {
  const AppButton({
    required this._label,
    required this._onPressed,
    super.key,
    this._variant = AppButtonVariant.primary,
    this._icon,
    this._isLoading = false,
    this._expand = false,
  });

  final String _label;

  /// `null` disables the button.
  final VoidCallback? _onPressed;
  final AppButtonVariant _variant;
  final IconData? _icon;

  /// Shows a progress indicator instead of `icon` and disables the button.
  final bool _isLoading;

  /// Stretches the button to the available width.
  final bool _expand;

  static const double _indicatorSize = 16;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = _isLoading ? null : _onPressed;
    final text = Text(_label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final leading = _isLoading
        ? const SizedBox.square(
            dimension: _indicatorSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _icon == null
        ? null
        : Icon(_icon, size: 18);
    // Framework .icon constructors lay out icon + label safely under both
    // bounded and unbounded width (AppBar actions, Row, dialog actions).
    final button = switch ((_variant, leading)) {
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
    if (!_expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
