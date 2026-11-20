import 'package:cinema_app/app/app.dart';
import 'package:cinema_app/app/router.dart';
import 'package:cinema_app/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(360, 800), Size(1920, 1080)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('TC12: UiKitPage renders and scrolls cleanly at $label', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createRouter(initialLocation: AppRoutes.uiKit);
      addTearDown(router.dispose);

      await tester.pumpWidget(CinemaApp(router: router));
      await tester.pump();

      expect(find.byKey(const Key('ui_kit_page')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const Key('ui_kit_scroll')),
        const Offset(0, -10000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  }
}
