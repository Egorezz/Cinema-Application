import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:cinema_app/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ErrorView(
        title: AppStrings.notFoundTitle,
        message: path,
        onRetry: () => context.go(AppRoutes.home),
        retryLabel: AppStrings.toHome,
      ),
    );
  }
}
