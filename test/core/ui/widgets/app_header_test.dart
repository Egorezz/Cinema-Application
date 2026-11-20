import 'package:cinema_app/core/ui/widgets/app_header.dart';
import 'package:cinema_app/core/ui/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(AppSliverHeader header) => MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          header,
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );

  SliverAppBar bar(WidgetTester tester) =>
      tester.widget<SliverAppBar>(find.byType(SliverAppBar));

  const action = IconButton(
    key: Key('header_action'),
    icon: Icon(Icons.search),
    onPressed: null,
  );

  testWidgets('TC19: pinned / floating behavior and default logo', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AppSliverHeader()));
    expect(bar(tester).floating, isTrue);
    expect(bar(tester).snap, isTrue);
    expect(bar(tester).pinned, isFalse);
    expect(find.byType(AppLogo), findsOneWidget);

    await tester.pumpWidget(host(const AppSliverHeader(actions: [action])));
    expect(bar(tester).pinned, isTrue);

    await tester.pumpWidget(
      host(const AppSliverHeader(actions: [action], pinned: false)),
    );
    expect(bar(tester).pinned, isFalse);
  });

  testWidgets('TC20: floating header hides and returns; pinned stays', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const AppSliverHeader()));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final logo = find.byType(AppLogo);
    expect(logo.evaluate().isEmpty || tester.getRect(logo).bottom <= 0, isTrue);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppLogo)).top >= 0, isTrue);

    await tester.pumpWidget(host(const AppSliverHeader(actions: [action])));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const Key('header_action')));
    expect(rect.top >= 0 && rect.bottom <= 600, isTrue);
  });
}
