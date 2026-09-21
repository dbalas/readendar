import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

void main() {
  test('emptyArtDensityForHeight is compact when tight and full when tall', () {
    expect(emptyArtDensityForHeight(200), 0.0);
    expect(emptyArtDensityForHeight(300), 0.0);
    expect(emptyArtDensityForHeight(370), closeTo(0.5, 0.01));
    expect(emptyArtDensityForHeight(440), 1.0);
    expect(emptyArtDensityForHeight(600), 1.0);
  });

  testWidgets('EmptyArtBackdrop shrinks under tight EmptyStateDensity', (
    tester,
  ) async {
    const designed = 188.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateDensity(
            density: 0,
            child: EmptyArtBackdrop(
              accent: ReadendarTokens.periwinkle500,
              height: designed,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    final compact = tester.getSize(find.byType(EmptyArtBackdrop));
    expect(compact.height, closeTo(designed * 0.72, 0.5));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateDensity(
            density: 1,
            child: EmptyArtBackdrop(
              accent: ReadendarTokens.periwinkle500,
              height: designed,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    final full = tester.getSize(find.byType(EmptyArtBackdrop));
    expect(full.height, closeTo(designed, 0.5));
  });

  testWidgets('EmptyState density grows with available height', (tester) async {
    Widget host(double height) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: height,
          width: 360,
          child: const EmptyState(
            message: 'Nothing here',
            illustration: EmptyArtBackdrop(
              accent: ReadendarTokens.teal500,
              height: 188,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(280));
    final tight = tester.getSize(find.byType(EmptyArtBackdrop));

    await tester.pumpWidget(host(480));
    final roomy = tester.getSize(find.byType(EmptyArtBackdrop));

    expect(tight.height, lessThan(roomy.height));
    expect(roomy.height, closeTo(188, 0.5));
  });
}
