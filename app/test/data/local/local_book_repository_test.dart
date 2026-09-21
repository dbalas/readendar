import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/local/local_book_repository.dart';
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_store.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  late LocalBookRepository books;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rd-local-book');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
    books = LocalBookRepository(store);
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('update and finish stay on the local store', () async {
    final created = await books.create(
      title: 'Rayuela',
      authors: const ['Cortazar'],
      pageCount: 700,
    );
    expect(created.isOk, isTrue);
    final id = created.value!.id;

    final updated = await books.update(id, pageCount: 728, title: 'Rayuela');
    expect(updated.isOk, isTrue);
    expect(updated.value!.pageCount, 728);

    final finished = await books.finish(id, idempotencyKey: 'finish-1');
    expect(finished.value!.status, BookStatus.read);

    final progress = await store.get(LocalCollections.progress, id);
    expect(progress?['currentPercentage'], 100);
    expect(progress?['currentPage'], 728);
    final activity = await store.list(LocalCollections.pageActivity);
    expect(activity.single['pages'], 728);

    final listed = await books.listMine();
    expect(listed.value!.single.id, id);
    expect(listed.value!.single.pageCount, 728);
  });

  test('create appends libraryOrder after existing rows', () async {
    final first = await books.create(title: 'A', authors: const ['A']);
    final second = await books.create(title: 'B', authors: const ['B']);
    final rows = await store.list(LocalCollections.books);
    expect(
      rows.firstWhere((r) => r['id'] == first.value!.id)['libraryOrder'],
      0,
    );
    expect(
      rows.firstWhere((r) => r['id'] == second.value!.id)['libraryOrder'],
      1,
    );
  });

  test('delete cascades progress, events, notes, and cover files', () async {
    final created = await books.create(title: 'Rayuela', authors: const ['A']);
    final id = created.value!.id;
    await store.put(LocalCollections.progress, id, {
      'bookEntryId': id,
      'currentPage': 3,
    });
    await store.put(LocalCollections.events, 'ev-1', {
      'id': 'ev-1',
      'ownerType': 'user',
      'ownerId': 'local-guest',
      'bookId': id,
      'type': 'start',
      'title': 'Inicio',
      'dateLocal': '2026-09-01',
      'status': EventStatus.active,
    });
    await store.put(LocalCollections.annotations, 'note-1', {
      'id': 'note-1',
      'bookId': id,
      'body': 'x',
    });
    await store.put(LocalCollections.pageActivity, 'act-1', {
      'id': 'act-1',
      'bookEntryId': id,
      'pages': 2,
    });
    final cover = await store.coverFile(id);
    await cover.writeAsBytes(const [1, 2, 3]);

    final deleted = await books.delete(id);
    expect(deleted.isOk, isTrue);
    expect(await store.get(LocalCollections.books, id), isNull);
    expect(await store.get(LocalCollections.progress, id), isNull);
    expect(await store.list(LocalCollections.events), isEmpty);
    expect(await store.list(LocalCollections.annotations), isEmpty);
    expect(await store.list(LocalCollections.pageActivity), isEmpty);
    expect(cover.existsSync(), isFalse);
  });

  test('saveCover copies a staged file into the sidecar', () async {
    final src = File('${temp.path}/staged.jpg')..writeAsBytesSync(const [4, 5]);
    final dest = await store.saveCover('book-9', src.path);
    expect(await dest.readAsBytes(), [4, 5]);
  });

  test('LocalUploadRepository writes the cover sidecar', () async {
    final src = File('${temp.path}/upload.jpg')..writeAsBytesSync(const [9, 8]);
    final uploaded = await LocalUploadRepository(store).uploadBookCover(
      'book-up',
      src.path,
    );
    expect(uploaded.isOk, isTrue);
    expect(await File(uploaded.value!).readAsBytes(), [9, 8]);
  });

  test('create maps provider subjects onto canonical category codes', () async {
    final created = await books.create(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      categories: const ['Ciencia ficción'],
    );
    expect(created.value!.categoryCodes, ['science_fiction']);
    expect(created.value!.categories, ['Ciencia ficción']);
  });

  test('clearAll drops cover sidecars', () async {
    final cover = await store.coverFile('book-1');
    await cover.writeAsBytes(const [1, 2, 3]);
    await store.clearAll();
    expect(cover.existsSync(), isFalse);
  });

  test('create persists custom field values locally', () async {
    final fields = LocalCustomFieldRepository(store);
    final def = await fields.create(
      idempotencyKey: 'k1',
      name: 'Traductor',
      iconKey: 'tag',
      type: 'text',
    );
    final book = await books.create(
      title: 'Rayuela',
      authors: const ['Cortazar'],
      customFieldChanges: [
        CustomFieldChange(
          def.value!.id,
          CustomFieldValue.fromJson(const {'kind': 'text', 'text': 'Cortazar'}),
        ),
      ],
    );
    final stored = await fields.listForBook(book.value!.id);
    expect(stored.value!.single.value.text, 'Cortazar');
  });
}

class _EmptyStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
