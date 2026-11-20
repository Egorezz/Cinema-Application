import 'package:cinema_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TC1: CinemaApp shows the home page on start', (tester) async {
    await tester.pumpWidget(const CinemaApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_page')), findsOneWidget);
  });
}
