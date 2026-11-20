import 'package:cinema_app/core/ui/widgets/poster_card.dart';
import 'package:cinema_app/core/ui/widgets/poster_card_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TC18: skeleton has the same size as PosterCard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: PosterCard(title: 'Title')),
              SizedBox(width: 150, child: PosterCardSkeleton()),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(PosterCardSkeleton)),
      tester.getSize(find.byType(PosterCard)),
    );
  });
}
