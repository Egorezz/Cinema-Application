import 'package:cinema_app/core/ui/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, AppButton button) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: button)),
      ),
    );
  }

  testWidgets('TC8: tap calls onPressed; loading and null disable it', (
    tester,
  ) async {
    var taps = 0;

    await pumpButton(tester, AppButton(label: 'Go', onPressed: () => taps++));
    await tester.tap(find.text('Go'));
    expect(taps, 1);

    await pumpButton(
      tester,
      AppButton(label: 'Go', isLoading: true, onPressed: () => taps++),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(taps, 1);

    await pumpButton(tester, const AppButton(label: 'Go', onPressed: null));
    final inner = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(inner.onPressed, isNull);
  });

  testWidgets('TC16: icon / loading button lays out under unbounded width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AppButton(label: 'Добавить', icon: Icons.add, onPressed: () {}),
            ],
          ),
          body: Row(
            children: [
              AppButton(label: 'Сохранить', isLoading: true, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Добавить'), findsOneWidget);
  });
}
