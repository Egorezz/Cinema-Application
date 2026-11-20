import 'package:cinema_app/app/app.dart';
import 'package:cinema_app/app/router.dart';
import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:cinema_app/core/ui/not_found_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = createRouter(initialLocation: location);
    addTearDown(router.dispose);
    await tester.pumpWidget(CinemaApp(router: router));
    await tester.pumpAndSettle();
  }

  testWidgets('TC2: deep link /about shows AboutPage', (tester) async {
    await pumpAt(tester, AppRoutes.about);

    expect(find.byKey(const Key('about_page')), findsOneWidget);
    expect(find.byKey(const Key('home_page')), findsNothing);
  });

  testWidgets('TC3: unknown path shows NotFoundPage with a way home', (
    tester,
  ) async {
    await pumpAt(tester, '/no-such-page');

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.text('/no-such-page'), findsOneWidget);

    await tester.tap(find.text(AppStrings.toHome));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_page')), findsOneWidget);
  });

  testWidgets('TC4: tapping the about link on home opens AboutPage', (
    tester,
  ) async {
    await pumpAt(tester, AppRoutes.home);

    await tester.tap(find.text(AppStrings.aboutLink));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_page')), findsOneWidget);
  });
}
