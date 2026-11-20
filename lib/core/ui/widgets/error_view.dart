import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:cinema_app/core/ui/widgets/app_button.dart';
import 'package:cinema_app/core/ui/widgets/content_container.dart';
import 'package:flutter/material.dart';

/// Error screen: icon, title, message and an optional retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this._message,
    super.key,
    this._title = AppStrings.errorTitle,
    this._onRetry,
    this._retryLabel = AppStrings.retry,
  });

  final String _message;
  final String _title;
  final VoidCallback? _onRetry;
  final String _retryLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: ContentContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      _title,
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      _message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_onRetry != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      AppButton(label: _retryLabel, onPressed: _onRetry),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
