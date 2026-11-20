import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:cinema_app/core/ui/widgets/responsive_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gridHeight = 3000.0;
  const itemCount = 12;

  Future<int> firstRowCount(WidgetTester tester, double width) async {
    tester.view
      ..physicalSize = const Size(2000, gridHeight)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: gridHeight,
            child: ResponsiveGrid(
              itemCount: itemCount,
              itemBuilder: (context, index) =>
                  ColoredBox(key: Key('item_$index'), color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    final firstDy = tester.getTopLeft(find.byKey(const Key('item_0'))).dy;
    var count = 0;
    for (var i = 0; i < itemCount; i++) {
      final finder = find.byKey(Key('item_$i'));
      if (finder.evaluate().isEmpty) continue;
      if (tester.getTopLeft(finder).dy == firstDy) count++;
    }
    return count;
  }

  testWidgets('TC7: first row has 2 / 4 / 6 items at 360 / 800 / 1920', (
    tester,
  ) async {
    expect(await firstRowCount(tester, 360), 2);
    expect(await firstRowCount(tester, 800), 4);
    expect(await firstRowCount(tester, 1920), 6);
  });

  testWidgets('TC17: very narrow width (10px) does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 10,
            height: 400,
            child: ResponsiveGrid(
              itemCount: 4,
              itemBuilder: (context, index) =>
                  const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TC18: posters with long titles fit at text scale 1.3', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 2000),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: ResponsiveGrid(
              itemCount: 4,
              itemBuilder: (context, index) => const PosterCard(
                title: 'Очень длинное название фильма в две строки и больше',
                subtitle: '2021',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
