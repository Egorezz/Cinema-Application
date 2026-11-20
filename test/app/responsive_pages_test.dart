import 'package:cinema_app/app/app.dart';
import 'package:cinema_app/app/router.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:cinema_app/core/ui/widgets/app_button.dart';
import 'package:cinema_app/core/ui/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, String location, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createRouter(initialLocation: location);
    addTearDown(router.dispose);
    // A new key per location: CinemaApp must not swap its router in place.
    await tester.pumpWidget(CinemaApp(key: ValueKey(location), router: router));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 800), Size(1920, 1080)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('TC13: pages use the kit without errors at $label', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.home, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppButton), findsOneWidget);

      await pumpAt(tester, AppRoutes.about, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppButton), findsOneWidget);

      await pumpAt(tester, '/no-such-page', size);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorView), findsOneWidget);
    });
  }
}
