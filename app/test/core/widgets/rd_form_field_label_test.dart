import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('RdFormFieldLabel required shows asterisk', (tester) async {
    await tester.pumpWidget(
      wrap(const RdFormFieldLabel(text: 'Name', required: true)),
    );

    final label = tester.widget<RdFormFieldLabel>(
      find.byType(RdFormFieldLabel),
    );
    expect(label.required, isTrue);
    expect(find.textContaining('Name'), findsOneWidget);
    expect(find.textContaining('*'), findsOneWidget);
  });

  testWidgets('RdFormFieldLabel optional hides asterisk', (tester) async {
    await tester.pumpWidget(
      wrap(const RdFormFieldLabel(text: 'Notes')),
    );

    expect(find.text('Notes'), findsOneWidget);
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('RdFormFieldLabel.decoration applies required label widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => RdTextField(
            decoration: RdFormFieldLabel.decoration(
              context,
              labelText: 'Email',
              required: true,
              decoration: const InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Email'), findsOneWidget);
    expect(find.textContaining('*'), findsOneWidget);
  });
}
