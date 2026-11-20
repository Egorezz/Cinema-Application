import 'package:cinema_app/core/router/app_routes.dart';
import 'package:cinema_app/core/ui/not_found_page.dart';
import 'package:cinema_app/features/about/presentation/pages/about_page.dart';
import 'package:cinema_app/features/catalog/presentation/pages/home_page.dart';
import 'package:go_router/go_router.dart';

/// Creates a fresh router; the caller owns it and must dispose it.
GoRouter createRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutPage(),
      ),
    ],
    errorBuilder: (context, state) => NotFoundPage(path: state.uri.toString()),
  );
}
