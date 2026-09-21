import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/widgets/rd_switch_list_tile.dart';

void main() {
  testWidgets('switchOnSubtitle keeps the title full width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: RdSwitchListTile(
              value: true,
              onChanged: (_) {},
              switchOnSubtitle: true,
              secondary: const Icon(Icons.people),
              title: const Text('Daily quote reminder'),
              subtitle: const Text(
                'Show a saved quote on the home screen each morning',
              ),
            ),
          ),
        ),
      ),
    );

    final title = tester.getRect(find.text('Daily quote reminder'));
    final subtitle = tester.getRect(
      find.text('Show a saved quote on the home screen each morning'),
    );
    final toggle = tester.getRect(find.byType(Switch));

    expect(toggle.center.dy, greaterThan(title.bottom));
    expect(
      (toggle.center.dy - subtitle.center.dy).abs(),
      lessThan((toggle.center.dy - title.center.dy).abs()),
    );
    expect(title.right, greaterThan(subtitle.right));
  });
}
