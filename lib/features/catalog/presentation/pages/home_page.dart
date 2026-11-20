import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_page'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.appTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.about),
              child: const Text(AppStrings.aboutLink),
            ),
          ],
        ),
      ),
    );
  }
}
