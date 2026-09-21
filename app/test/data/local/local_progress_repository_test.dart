import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_store.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  late LocalProgressRepository progress;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rd-local-progress');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
    progress = LocalProgressRepository(store);
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('page increases append page_activity rows', () async {
    final first = await progress.update('book-1', page: 10);
    expect(first.isOk, isTrue);
    expect(first.value!.currentPage, 10);

    final second = await progress.update('book-1', page: 25);
    expect(second.value!.currentPage, 25);

    final rows = await store.list(LocalCollections.pageActivity);
    expect(rows, hasLength(2));
    expect(rows.map((r) => r['pages']), [10, 15]);
    expect(rows.every((r) => r['bookEntryId'] == 'book-1'), isTrue);
  });

  test('backward page edits do not append activity', () async {
    await progress.update('book-1', page: 40);
    await progress.update('book-1', page: 12);
    final rows = await store.list(LocalCollections.pageActivity);
    expect(rows, hasLength(1));
    expect(rows.single['pages'], 40);
  });
}

class _EmptyStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
