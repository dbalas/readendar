import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/data_export_file.dart';

void main() {
  test('stale account exports are removed before a new export', () async {
    final directory = await Directory.systemTemp.createTemp(
      'readendar-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final stale = File('${directory.path}/readendar-export-1.json');
    final unrelated = File('${directory.path}/keep-me.json');
    await stale.writeAsString('private');
    await unrelated.writeAsString('public');

    await shareTemporaryDataExport(
      directory: directory,
      contents: '{"fresh":true}',
      share: (_) async {
        expect(await stale.exists(), isFalse);
        expect(await unrelated.exists(), isTrue);
      },
    );
  });

  test('account export is deleted after sharing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'readendar-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    late String path;

    await shareTemporaryDataExport(
      directory: directory,
      contents: '{"email":"reader@example.com"}',
      share: (file) async {
        path = file.path;
        expect(await file.readAsString(), contains('reader@example.com'));
      },
    );

    expect(await File(path).exists(), isFalse);
  });

  test('account export is deleted when sharing fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'readendar-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    late String path;

    await expectLater(
      shareTemporaryDataExport(
        directory: directory,
        contents: '{"private":true}',
        share: (file) async {
          path = file.path;
          throw StateError('share failed');
        },
      ),
      throwsStateError,
    );

    expect(await File(path).exists(), isFalse);
  });
}
