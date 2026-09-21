import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appDirectory = Directory.current.path.endsWith('/app')
      ? Directory.current
      : Directory('${Directory.current.path}/app');

  String source(String path) =>
      File('${appDirectory.path}/$path').readAsStringSync();

  test('search UIs use RdSearchField instead of a local RdTextField chrome', () {
    const sites = [
      'lib/features/library/library_screen.dart',
      'lib/features/quotes/book_annotations_screen.dart',
    ];
    for (final path in sites) {
      final dart = source(path);
      expect(dart, contains('RdSearchField('), reason: path);
      expect(dart, contains("import 'package:readendar/core/widgets/search_field.dart';"), reason: path);
    }
    expect(
      source('lib/features/library/library_screen.dart'),
      isNot(contains('RdTextField(')),
    );
    expect(
      source('lib/features/quotes/book_annotations_screen.dart'),
      isNot(contains('RdTextField(')),
    );
  });
}
