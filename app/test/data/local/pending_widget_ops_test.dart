import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/features/widget/widget_sync.dart';

void main() {
  late Directory temp;
  late LocalStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rd-pending-ops');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('applyPendingWidgetOps writes local progress and event completion', () async {
    await store.put(LocalCollections.books, 'book-1', {
      'id': 'book-1',
      'pageCount': 200,
    });
    await store.put(LocalCollections.events, 'ev-1', {
      'id': 'ev-1',
      'status': EventStatus.active,
    });

    await applyPendingWidgetOps(store, '''
[
  {"op":"progress","bookId":"book-1","field":"page","value":40},
  {"op":"complete","eventId":"ev-1","complete":true}
]
''');

    final progress = await store.get(LocalCollections.progress, 'book-1');
    expect(progress?['currentPage'], 40);
    expect(progress?['currentPercentage'], 20);
    final event = await store.get(LocalCollections.events, 'ev-1');
    expect(event?['status'], EventStatus.completed);
  });
}
