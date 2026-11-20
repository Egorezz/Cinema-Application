import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TC23: plain AppBar picks up header colors from the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(appBar: AppBar(title: const Text('x'))),
      ),
    );
    final material = tester.widget<Material>(
      find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first,
    );
    expect(material.color, AppColors.header);
    final context = tester.element(find.byType(AppBar));
    expect(Theme.of(context).appBarTheme.surfaceTintColor, Colors.transparent);
  });
}
