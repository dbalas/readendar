import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/profile/widgets/behavior_preference_card.dart';

void main() {
  testWidgets('title wraps completely at narrow width and large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const title = 'Toujours afficher les citations à spoilers';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: BehaviorPreferenceCard(
              switchKey: Key('switch'),
              icon: Icons.visibility_outlined,
              title: title,
              bullets: ['Description remains visible.'],
              value: false,
              onChanged: null,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.getSize(find.text(title)).height, greaterThan(50));
    expect(tester.takeException(), isNull);
  });
}
