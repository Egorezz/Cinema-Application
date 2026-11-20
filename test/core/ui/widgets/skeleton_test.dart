import 'package:cinema_app/core/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool disableAnimations}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Skeleton(width: 100, height: 20)),
      ),
    );
  }

  testWidgets('TC11: static without animations, pulses without errors', (
    tester,
  ) async {
    await tester.pumpWidget(host(disableAnimations: true));
    await tester.pumpAndSettle();
    expect(find.byType(Skeleton), findsOneWidget);

    await tester.pumpWidget(host(disableAnimations: false));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isTrue);
  });
}
