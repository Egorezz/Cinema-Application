import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.notFoundTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(path),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text(AppStrings.toHome),
            ),
          ],
        ),
      ),
    );
  }
}
