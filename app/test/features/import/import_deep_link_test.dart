import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/import/import_deep_link.dart';
import 'package:readendar/features/import/import_intro_screen.dart';

void main() {
  test('reads a file:// CSV and ignores everything else', () async {
    final tmp = File(
      '${Directory.systemTemp.path}/readendar_import_test.csv',
    );
    await tmp.writeAsString('Title,Exclusive Shelf\n"Dune",read');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete();
    });

    final content = await readCsvFromUri(tmp.uri);
    expect(content, contains('Dune'));

    // Non-CSV file:// → ignored.
    expect(await readCsvFromUri(Uri.parse('file:///tmp/photo.jpg')), isNull);
    // content:// (Android) with no platform handler (as in tests) fails
    // gracefully to null rather than throwing.
    expect(
      await readCsvFromUri(Uri.parse('content://downloads/123')),
      isNull,
    );
    // https deep links are not ours to handle here.
    expect(
      await readCsvFromUri(Uri.parse('https://example.test/not-csv')),
      isNull,
    );
  });

  test('reads a content:// CSV through the platform reader (Android)', () async {
    // On Android the OS hands us a content:// URI; readCsvFromUri delegates to
    // the platform ContentResolver. Inject the reader to keep the test hermetic.
    final content = await readCsvFromUri(
      Uri.parse('content://downloads/42'),
      contentReader: (uri) async => 'Title,Exclusive Shelf\n"Dune",read',
    );
    expect(content, contains('Dune'));
  });

  test('refuses an oversized file:// CSV', () async {
    final big = File(
      '${Directory.systemTemp.path}/readendar_import_big.csv',
    );
    // Just over the 10 MB cap — must be ignored before being read into memory.
    await big.writeAsString('a' * (10 * 1024 * 1024 + 1));
    addTearDown(() async {
      if (big.existsSync()) await big.delete();
    });

    expect(await readCsvFromUri(big.uri), isNull);
  });

  test('stages opened CSV before the navigation handoff', () async {
    final dir = await Directory.systemTemp.createTemp(
      'readendar-import-stage-',
    );
    addTearDown(() => dir.delete(recursive: true));
    Future<Directory> stagingDirectory() async => dir;

    expect(
      await stageOpenedCsv(
        'Title,Exclusive Shelf\nDune,read',
        directoryProvider: stagingDirectory,
      ),
      isTrue,
    );
    expect(
      await readStagedOpenedCsv(directoryProvider: stagingDirectory),
      contains('Dune'),
    );
    await deleteStagedOpenedCsv(directoryProvider: stagingDirectory);
    expect(
      await readStagedOpenedCsv(directoryProvider: stagingDirectory),
      isNull,
    );
  });

  test('detects the supported CSV source before opening the import', () {
    expect(
      detectCsvImportSource(
        'Title,Authors,ISBN/UID,Read Status\nDune,Frank Herbert,,read',
      ),
      ImportFileSource.storygraph,
    );
    expect(
      detectCsvImportSource(
        'Title,Author,Exclusive Shelf\nDune,Frank Herbert,read',
      ),
      ImportFileSource.goodreads,
    );
    expect(
      detectCsvImportSource(
        'ISBN;Titre;Auteur;Statut\n;Dune;Frank Herbert;Lu',
      ),
      ImportFileSource.babelio,
    );
  });
}
