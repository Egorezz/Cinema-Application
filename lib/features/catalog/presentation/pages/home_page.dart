import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:cinema_app/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_page'),
      body: CustomScrollView(
        slivers: [
          const AppSliverHeader(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ContentContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppButton.text(
                      label: AppStrings.aboutLink,
                      onPressed: () => context.go(AppRoutes.about),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
