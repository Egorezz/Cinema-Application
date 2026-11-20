import 'package:cinema_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC5: real main() boots in Chrome with path URLs (no #)', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_page')), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_page')), findsOneWidget);
    expect(Uri.base.path, '/about');
    expect(Uri.base.toString(), isNot(contains('#')));
  });
}
