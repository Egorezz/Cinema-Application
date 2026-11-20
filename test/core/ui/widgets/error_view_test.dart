import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/ui/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, ErrorView view) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
  }

  testWidgets('TC10: retry button is shown only with onRetry', (tester) async {
    var retries = 0;

    await pumpView(
      tester,
      ErrorView(message: 'Ошибка сети', onRetry: () => retries++),
    );
    expect(find.text('Ошибка сети'), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    expect(retries, 1);

    await pumpView(tester, const ErrorView(message: 'Ошибка сети'));
    expect(find.text(AppStrings.retry), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await pumpView(
      tester,
      ErrorView(message: 'Ошибка', onRetry: () {}, retryLabel: 'Назад'),
    );
    expect(find.text('Назад'), findsOneWidget);
  });
}
