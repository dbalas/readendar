import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/emphasized_text.dart';

void main() {
  test('spansFor bolds **marked** segments', () {
    final spans = EmphasizedText.spansFor(
      'Creates a **start** event and a **finish** event.',
      style: const TextStyle(fontSize: 12),
    );
    expect(spans, hasLength(5));
    expect((spans[0] as TextSpan).text, 'Creates a ');
    expect((spans[1] as TextSpan).text, 'start');
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.w600);
    expect((spans[2] as TextSpan).text, ' event and a ');
    expect((spans[3] as TextSpan).text, 'finish');
    expect((spans[4] as TextSpan).text, ' event.');
  });

  test('spansFor leaves plain text alone', () {
    final spans = EmphasizedText.spansFor('No emphasis here');
    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).text, 'No emphasis here');
  });
}
