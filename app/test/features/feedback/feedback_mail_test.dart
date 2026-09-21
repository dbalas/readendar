import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';

void main() {
  test('builds a mailto URI to hello@readendar.com with kind and diagnostics', () {
    final uri = feedbackMailtoUri(
      kind: 'idea',
      message: 'me gustaría un modo oscuro',
      version: '1.2.0+3',
      os: 'ios 18.0',
    );

    expect(uri.scheme, 'mailto');
    expect(uri.path, feedbackSupportEmail);
    final query = uri.query;
    expect(query, contains('subject='));
    expect(query, contains(Uri.encodeComponent('Readendar (idea)')));
    expect(query, contains(Uri.encodeComponent('me gustaría un modo oscuro')));
    expect(query, contains(Uri.encodeComponent('version: 1.2.0+3')));
    expect(query, contains(Uri.encodeComponent('os: ios 18.0')));
  });
}
