import 'package:flutter/material.dart';

enum _AppButtonVariant { primary, secondary, text }

/// The app's button: [AppButton.primary] is a [FilledButton],
/// [AppButton.secondary] an [OutlinedButton], [AppButton.text]
/// a [TextButton].
///
/// `onPressed: null` disables the button. `isLoading` shows a progress
/// indicator instead of `icon` and disables the button. `expand` stretches
/// the button to the available width.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this._label,
    required this._onPressed,
    super.key,
    this._icon,
    this._isLoading = false,
    this._expand = false,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    required this._label,
    required this._onPressed,
    super.key,
    this._icon,
    this._isLoading = false,
    this._expand = false,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.text({
    required this._label,
    required this._onPressed,
    super.key,
    this._icon,
    this._isLoading = false,
    this._expand = false,
  }) : _variant = _AppButtonVariant.text;

  final String _label;
  final VoidCallback? _onPressed;
  final _AppButtonVariant _variant;
  final IconData? _icon;
  final bool _isLoading;
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
      (_AppButtonVariant.primary, null) => FilledButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (_AppButtonVariant.primary, final Widget icon) => FilledButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
      (_AppButtonVariant.secondary, null) => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (_AppButtonVariant.secondary, final Widget icon) => OutlinedButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
      (_AppButtonVariant.text, null) => TextButton(
        onPressed: effectiveOnPressed,
        child: text,
      ),
      (_AppButtonVariant.text, final Widget icon) => TextButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: text,
      ),
    };
    if (!_expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
