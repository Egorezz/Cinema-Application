import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TC9: no imageUrl shows placeholder, title and handles tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: PosterCard(
                title: 'Дюна',
                subtitle: '2021',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('poster_placeholder')), findsOneWidget);
    expect(find.text('Дюна'), findsOneWidget);

    await tester.tap(find.byType(PosterCard));
    expect(taps, 1);
  });
}
