import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:uuid/uuid.dart';

const eventsCol = LocalCollections.events;
const progressCol = LocalCollections.progress;
const plansCol = LocalCollections.planRuns;
const annotationsCol = LocalCollections.annotations;

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> eventToJson(ReadingEvent e) => {
  'id': e.id,
  'ownerType': e.ownerType,
  'ownerId': e.ownerId,
  'bookId': e.bookId,
  'type': e.type,
  'title': e.title,
  'description': e.description,
  'dateLocal': _ymd(e.dateLocal),
  'timeLocal': e.timeLocal,
  'tz': e.tz,
  'targetChapter': e.targetChapter,
  'targetPage': e.targetPage,
  'status': e.status,
  'reminderEnabled': e.reminderEnabled,
  'reminderMinutesBefore': e.reminderMinutesBefore,
  'seenAt': e.seenAt?.toUtc().toIso8601String(),
  'muted': e.muted,
  'createdAt': e.createdAt?.toUtc().toIso8601String(),
  'updatedAt': e.updatedAt?.toUtc().toIso8601String(),
  'planId': e.planId,
};

class LocalEventRepository implements EventRepository {
  LocalEventRepository(this._store);

  final LocalStore _store;
  static const _uuid = Uuid();

  List<ReadingEvent> _decodeEvents(List<Map<String, dynamic>> rows) {
    final items = <ReadingEvent>[];
    for (final row in rows) {
      try {
        items.add(ReadingEvent.fromJson(row));
      } on Object {
        continue;
      }
    }
    return items;
  }

  @override
  Future<Result<List<ReadingEvent>>> list({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final rows = await _store.list(
        eventsCol,
        query: LocalListQuery(
          dateLocalFrom: from == null ? null : _ymd(from),
          dateLocalToExclusive: to == null ? null : _ymd(to),
          orderByPath: 'dateLocal',
        ),
      );
      return Ok(_decodeEvents(rows));
    } on Object catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ReadingEvent>>> listForBook(String bookId) async {
    try {
      final rows = await _store.list(
        eventsCol,
        query: LocalListQuery(
          equals: {'bookId': bookId},
          orderByPath: 'dateLocal',
        ),
      );
      return Ok(_decodeEvents(rows));
    } on Object catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ReadingEvent>>> listAllForBook(String bookId) =>
      listForBook(bookId);

  @override
  Future<Result<ReadingEvent>> get(String id) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    return Ok(ReadingEvent.fromJson(row));
  }

  @override
  Future<Result<ReadingEvent>> create({
    required String ownerType,
    required String ownerId,
    required String type,
    required String title,
    required DateTime dateLocal,
    String? bookId,
    String? timeLocal,
    String? tz,
    String description = '',
    int? targetChapter,
    int? targetPage,
    bool reminderEnabled = true,
    int? reminderMinutesBefore,
    String? idempotencyKey,
  }) async {
    final id = idempotencyKey ?? _uuid.v4();
    final event = ReadingEvent(
      id: id,
      ownerType: 'user',
      ownerId: localGuestUserId,
      type: type,
      title: title,
      dateLocal: dateLocal,
      status: EventStatus.active,
      description: description,
      bookId: bookId,
      timeLocal: timeLocal,
      tz: tz,
      targetChapter: targetChapter,
      targetPage: targetPage,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
    );
    await _store.put(eventsCol, id, eventToJson(event));
    return Ok(event);
  }

  @override
  Future<Result<List<EventBatchResult>>> createBatch(
    List<Map<String, dynamic>> events, {
    String? idempotencyKey,
  }) async {
    final results = <EventBatchResult>[];
    for (var i = 0; i < events.length; i++) {
      final raw = Map<String, dynamic>.from(events[i]);
      raw['id'] = raw['id'] ?? _uuid.v4();
      raw['ownerType'] = 'user';
      raw['ownerId'] = localGuestUserId;
      raw['status'] = raw['status'] ?? EventStatus.active;
      await _store.put(eventsCol, raw['id'] as String, raw);
      results.add(
        EventBatchResult(index: i, outcome: 'created', id: raw['id'] as String),
      );
    }
    return Ok(results);
  }

  @override
  Future<Result<int>> deleteBatch(List<String> ids) async {
    for (final id in ids) {
      await _store.delete(eventsCol, id);
    }
    return Ok(ids.length);
  }

  @override
  Future<Result<ReadingEvent>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    row.addAll(body);
    await _store.put(eventsCol, id, row);
    return Ok(ReadingEvent.fromJson(row));
  }

  @override
  Future<Result<ReadingEvent>> complete(String id) =>
      update(id, {'status': EventStatus.completed});

  @override
  Future<Result<ReadingEvent>> uncomplete(String id) =>
      update(id, {'status': EventStatus.active});

  @override
  Future<Result<void>> delete(String id) async {
    await _store.delete(eventsCol, id);
    return const Ok(null);
  }

  @override
  Future<Result<EventUserState>> getUserState(String id) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    return Ok(_userState(id, row));
  }

  @override
  Future<Result<EventUserState>> markSeen(String id) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    row['seenAt'] = DateTime.now().toUtc().toIso8601String();
    await _store.put(eventsCol, id, row);
    return Ok(_userState(id, row));
  }

  @override
  Future<Result<EventUserState>> setMuted(String id, bool muted) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    row['muted'] = muted;
    await _store.put(eventsCol, id, row);
    return Ok(_userState(id, row));
  }

  @override
  Future<Result<EventUserState>> setUserReminder(
    String id, {
    required bool enabled,
    int? minutesBefore,
  }) async {
    final row = await _store.get(eventsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    row['reminderEnabled'] = enabled;
    if (minutesBefore != null) {
      row['reminderMinutesBefore'] = minutesBefore;
    }
    await _store.put(eventsCol, id, row);
    return Ok(_userState(id, row));
  }

  EventUserState _userState(String id, Map<String, dynamic> row) =>
      EventUserState.fromJson({
        'eventId': id,
        'status': row['status'] ?? EventStatus.active,
        'reminderEnabled': row['reminderEnabled'] ?? true,
        'muted': row['muted'] ?? false,
        'seenAt': row['seenAt'],
        'completedAt': row['completedAt'],
        'reminderMinutesBefore': row['reminderMinutesBefore'],
      });
}

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._store);
  final LocalStore _store;
  static const _uuid = Uuid();

  @override
  Future<Result<Progress>> get(String bookId) async {
    final row = await _store.get(progressCol, bookId);
    if (row == null) return Ok(Progress(bookEntryId: bookId));
    return Ok(Progress.fromJson(row));
  }

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async {
    final existing =
        await _store.get(progressCol, bookId) ??
        <String, dynamic>{'bookEntryId': bookId};
    final prevPage = (existing['currentPage'] as num?)?.toInt() ?? 0;
    if (page != null) existing['currentPage'] = page;
    if (chapter != null) existing['currentChapter'] = chapter;
    if (percentage != null) existing['currentPercentage'] = percentage;
    existing['bookEntryId'] = bookId;
    existing['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _store.put(progressCol, bookId, existing);
    if (page != null && page > prevPage) {
      final id = _uuid.v4();
      await _store.put(LocalCollections.pageActivity, id, {
        'id': id,
        'bookEntryId': bookId,
        'pages': page - prevPage,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return Ok(Progress.fromJson(existing));
  }
}

class LocalPlanRepository implements PlanRepository {
  LocalPlanRepository(this._store);
  final LocalStore _store;

  @override
  Future<Result<PlanRun>> createPlanRun({
    required String id,
    required String bookId,
    required int eventCount,
    required String mode,
    required String unit,
    int? perDay,
    DateTime? startDate,
    DateTime? endDate,
    int? total,
    int? startUnit,
    Set<int>? excludedWeekdays,
    bool? remindersOn,
    bool? includeStart,
    bool? includeFinish,
    String? anchorEventId,
    String? anchorEventTitle,
  }) async {
    final json = <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'eventCount': eventCount,
      'mode': mode,
      'unit': unit,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      if (perDay != null) 'perDay': perDay,
      if (startDate != null) 'startDate': _ymd(startDate),
      if (endDate != null) 'endDate': _ymd(endDate),
      if (total != null) 'total': total,
      if (startUnit != null) 'startUnit': startUnit,
      if (excludedWeekdays != null)
        'excludedWeekdays': (excludedWeekdays.toList()..sort()),
      if (remindersOn != null) 'remindersOn': remindersOn,
      if (includeStart != null) 'includeStart': includeStart,
      if (includeFinish != null) 'includeFinish': includeFinish,
      if (anchorEventId != null) 'anchorEventId': anchorEventId,
      if (anchorEventTitle != null) 'anchorEventTitle': anchorEventTitle,
    };
    await _store.put(plansCol, id, json);
    return Ok(PlanRun.fromJson(json));
  }

  @override
  Future<Result<List<PlanRun>>> listPlans(
    String bookId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _store.list(plansCol);
    final items = [
      for (final row in rows)
        if (row['bookId'] == bookId) PlanRun.fromJson(row),
    ];
    final slice = items.skip(offset).take(limit).toList();
    return Ok(slice);
  }

  @override
  Future<Result<int>> undoPlan(String planId) async {
    final events = await _store.list(eventsCol);
    var deleted = 0;
    for (final event in events) {
      if (event['planId'] != planId) continue;
      final id = event['id'];
      if (id is! String) continue;
      await _store.delete(eventsCol, id);
      deleted++;
    }
    await _store.delete(plansCol, planId);
    return Ok(deleted);
  }
}

class LocalAnnotationRepository implements AnnotationRepository {
  LocalAnnotationRepository(this._store);
  final LocalStore _store;
  static const _uuid = Uuid();

  Map<String, dynamic> _toJson(Annotation a) => {
    'id': a.id,
    'bookId': a.bookId,
    'category': a.category.wire,
    'body': a.body,
    'commentary': a.commentary,
    'page': a.page,
    'chapter': a.chapter,
    'spoiler': a.spoiler,
    'pinned': a.pinned,
    'favorite': a.favorite,
    'createdAt': a.createdAt.toUtc().toIso8601String(),
    'updatedAt': a.updatedAt.toUtc().toIso8601String(),
    'bookTitle': a.bookTitle,
    'bookAuthors': a.bookAuthors,
    'bookCoverUrl': a.bookCoverUrl,
    'isbn13': a.isbn13,
  };

  @override
  Future<Result<List<Annotation>>> listMine() async {
    final rows = await _store.list(annotationsCol);
    return Ok([
      for (final row in rows)
        if (Annotation.fromJson(row).category == AnnotationCategory.quote)
          Annotation.fromJson(row),
    ]);
  }

  @override
  Future<Result<List<Annotation>>> listForBook(
    String bookId, {
    AnnotationCategory? category,
    String q = '',
  }) async {
    final rows = await _store.list(annotationsCol);
    var items = [
      for (final row in rows)
        if (row['bookId'] == bookId) Annotation.fromJson(row),
    ];
    if (category != null) {
      items = items.where((a) => a.category == category).toList();
    }
    return Ok(items);
  }

  @override
  Future<Result<Annotation>> get(String id) async {
    final row = await _store.get(annotationsCol, id);
    if (row == null) return const Err(NotFoundFailure());
    return Ok(Annotation.fromJson(row));
  }

  @override
  Future<Result<Annotation>> create({
    required String bookId,
    required String body,
    AnnotationCategory category = AnnotationCategory.quote,
    int? page,
    int? chapter,
    bool pinned = false,
    String commentary = '',
    bool spoiler = false,
    String? text,
    bool favorite = false,
    String note = '',
  }) async {
    final a = Annotation(
      id: _uuid.v4(),
      bookId: bookId,
      body: body.isNotEmpty ? body : (text ?? ''),
      category: category,
      page: page,
      chapter: chapter,
      pinned: pinned,
      commentary: commentary.isNotEmpty ? commentary : note,
      spoiler: spoiler,
      favorite: favorite,
    );
    await _store.put(annotationsCol, a.id, _toJson(a));
    return Ok(a);
  }

  @override
  Future<Result<Annotation>> update(Annotation a) async {
    await _store.put(annotationsCol, a.id, _toJson(a));
    return Ok(a);
  }

  @override
  Future<Result<void>> delete(String id) async {
    await _store.delete(annotationsCol, id);
    return const Ok(null);
  }

  @override
  Future<Result<List<AnnotationBatchRowResult>>> createBatch(
    List<AnnotationBatchItem> items,
  ) async {
    final results = <AnnotationBatchRowResult>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final created = await create(
        bookId: item.bookId,
        body: item.body,
        category: item.category,
        page: item.page,
      );
      final annotation = created.value;
      results.add(
        AnnotationBatchRowResult(
          index: i,
          outcome: annotation == null ? 'failed' : 'created',
          id: annotation?.id,
          error: created.failure?.toString(),
        ),
      );
    }
    return Ok(results);
  }
}

const _layoutDocId = '__layout__';

String _customFieldTypeWire(CustomFieldType type) => switch (type) {
  CustomFieldType.singleSelect => 'single_select',
  CustomFieldType.text => 'text',
  CustomFieldType.number => 'number',
  CustomFieldType.datetime => 'datetime',
  CustomFieldType.boolean => 'boolean',
};

Map<String, dynamic> _definitionToJson(CustomFieldDefinition def) => {
  'id': def.id,
  'name': def.name,
  'iconKey': def.iconKey,
  'type': _customFieldTypeWire(def.type),
  'textMode': def.textMode,
  'position': def.position,
  'usageCount': def.usageCount,
  'options': [
    for (final option in def.options)
      {
        'id': option.id,
        'label': option.label,
        'position': option.position,
        'usageCount': option.usageCount,
      },
  ],
};

Future<void> applyLocalCustomFieldChanges(
  LocalStore store,
  String bookId,
  List<CustomFieldChange> changes,
) async {
  final defs = {
    for (final row in await store.list(LocalCollections.customFieldDefinitions))
      if (row['id'] != _layoutDocId)
        (row['id'] as String? ?? ''): CustomFieldDefinition.fromJson(row),
  };
  final existing =
      await store.get(LocalCollections.customFieldValues, bookId) ??
      <String, dynamic>{'id': bookId, 'items': <dynamic>[]};
  final items = <Map<String, dynamic>>[
    for (final item in (existing['items'] as List?) ?? const [])
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  for (final change in changes) {
    items.removeWhere((item) => item['fieldId'] == change.fieldId);
    if (change.value == null) continue;
    final def = defs[change.fieldId];
    items.add({
      'fieldId': change.fieldId,
      'name': def?.name ?? '',
      'iconKey': def?.iconKey ?? 'tag',
      'textMode': def?.textMode ?? '',
      'position': def?.position ?? items.length,
      'source': 'personal',
      'readOnly': false,
      'historical': false,
      'value': change.value!.toJson(),
    });
  }
  await store.put(LocalCollections.customFieldValues, bookId, {
    'id': bookId,
    'items': items,
  });
}

class LocalCustomFieldRepository implements CustomFieldRepository {
  LocalCustomFieldRepository(this._store);

  final LocalStore _store;
  static const _uuid = Uuid();

  Future<List<CustomFieldDefinition>> _definitions() async {
    final rows = await _store.list(LocalCollections.customFieldDefinitions);
    final defs = [
      for (final row in rows)
        if (row['id'] != _layoutDocId) CustomFieldDefinition.fromJson(row),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return defs;
  }

  @override
  Future<Result<List<CustomFieldDefinition>>> listDefinitions() async =>
      Ok(await _definitions());

  @override
  Future<Result<List<BookCustomField>>> listForBook(String bookId) async {
    final defs = await _definitions();
    final row = await _store.get(LocalCollections.customFieldValues, bookId);
    final stored = <String, BookCustomField>{
      for (final item in (row?['items'] as List?) ?? const [])
        if (item is Map)
          (item['fieldId'] as String? ?? ''): BookCustomField.fromJson(
            Map<String, dynamic>.from(item),
          ),
    };
    return Ok([
      for (final def in defs)
        stored[def.id] ??
            BookCustomField(
              fieldId: def.id,
              name: def.name,
              iconKey: def.iconKey,
              textMode: def.textMode,
              position: def.position,
              source: 'personal',
              readOnly: false,
              historical: false,
              value: CustomFieldValue.fromJson(const {}),
            ),
    ]);
  }

  @override
  Future<Result<void>> reorder(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final row = await _store.get(
        LocalCollections.customFieldDefinitions,
        ids[i],
      );
      if (row == null) continue;
      row['position'] = i;
      await _store.put(LocalCollections.customFieldDefinitions, ids[i], row);
    }
    return const Ok(null);
  }

  Future<List<BookDetailFieldLayoutItem>> _defaultLayout() async {
    final defs = await _definitions();
    return [
      for (final key in bookDetailSystemFieldKeys)
        BookDetailFieldLayoutItem(
          key: key,
          kind: BookDetailFieldKind.system,
          hidden: false,
        ),
      for (final def in defs)
        BookDetailFieldLayoutItem(
          key: def.id,
          kind: BookDetailFieldKind.custom,
          hidden: false,
        ),
    ];
  }

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() async {
    final row = await _store.get(
      LocalCollections.customFieldDefinitions,
      _layoutDocId,
    );
    final raw = row?['items'];
    if (raw is! List) return Ok(await _defaultLayout());
    return Ok([
      for (final item in raw)
        if (item is Map)
          BookDetailFieldLayoutItem.fromJson(Map<String, dynamic>.from(item)),
    ]);
  }

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> saveLayout(
    List<BookDetailFieldLayoutItem> items,
  ) async {
    await _store.put(LocalCollections.customFieldDefinitions, _layoutDocId, {
      'id': _layoutDocId,
      'items': [for (final item in items) item.toJson()],
    });
    return Ok(items);
  }

  @override
  Future<Result<CustomFieldDefinition>> create({
    required String idempotencyKey,
    required String name,
    required String iconKey,
    required String type,
    String textMode = '',
    List<Map<String, dynamic>>? options,
  }) async {
    final defs = await _definitions();
    final def = CustomFieldDefinition(
      id: _uuid.v4(),
      name: name,
      iconKey: iconKey,
      type: _customFieldType(type),
      textMode: textMode,
      position: defs.length,
      options: [
        for (final option in options ?? const <Map<String, dynamic>>[])
          CustomFieldOption.fromJson(option),
      ],
    );
    await _store.put(
      LocalCollections.customFieldDefinitions,
      def.id,
      _definitionToJson(def),
    );
    return Ok(def);
  }

  @override
  Future<Result<CustomFieldDefinition>> update(
    String fieldId, {
    required String name,
    required String iconKey,
    required String type,
    String textMode = '',
    List<Map<String, dynamic>>? options,
    List<String> cascadeOptionDeleteIds = const [],
  }) async {
    final row = await _store.get(
      LocalCollections.customFieldDefinitions,
      fieldId,
    );
    if (row == null) return const Err(NotFoundFailure());
    final current = CustomFieldDefinition.fromJson(row);
    final kept = [
      for (final option in current.options)
        if (!cascadeOptionDeleteIds.contains(option.id)) option,
    ];
    final next = CustomFieldDefinition(
      id: fieldId,
      name: name,
      iconKey: iconKey,
      type: _customFieldType(type),
      textMode: textMode,
      position: current.position,
      usageCount: current.usageCount,
      options: options == null
          ? kept
          : [
              for (final option in options) CustomFieldOption.fromJson(option),
            ],
    );
    await _store.put(
      LocalCollections.customFieldDefinitions,
      fieldId,
      _definitionToJson(next),
    );
    return Ok(next);
  }

  @override
  Future<Result<void>> delete(String fieldId, {bool cascade = false}) async {
    await _store.delete(LocalCollections.customFieldDefinitions, fieldId);
    if (cascade) {
      final rows = await _store.list(LocalCollections.customFieldValues);
      for (final row in rows) {
        final items = [
          for (final item in (row['items'] as List?) ?? const [])
            if (item is Map && item['fieldId'] != fieldId)
              Map<String, dynamic>.from(item),
        ];
        row['items'] = items;
        final id = row['id'] as String? ?? '';
        if (id.isNotEmpty) {
          await _store.put(LocalCollections.customFieldValues, id, row);
        }
      }
    }
    return const Ok(null);
  }
}

CustomFieldType _customFieldType(String raw) => switch (raw) {
  'number' => CustomFieldType.number,
  'datetime' => CustomFieldType.datetime,
  'boolean' => CustomFieldType.boolean,
  'single_select' => CustomFieldType.singleSelect,
  _ => CustomFieldType.text,
};

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._store);

  final LocalStore _store;

  NotificationPreferences _defaults() => NotificationPreferences(
    globalEnabled: true,
    defaultReminderMinutesBefore: 1440,
    allDayReminderHour: 9,
  );

  @override
  Future<Result<NotificationPreferences>> get() async {
    final row = await _store.get(
      LocalCollections.notificationPreferences,
      'me',
    );
    if (row == null) return Ok(_defaults());
    return Ok(NotificationPreferences.fromJson(row));
  }

  @override
  Future<Result<NotificationPreferences>> update({
    bool? globalEnabled,
    int? defaultReminderMinutesBefore,
    int? allDayReminderHour,
  }) async {
    final current = (await get()).value ?? _defaults();
    final next = NotificationPreferences(
      globalEnabled: globalEnabled ?? current.globalEnabled,
      defaultReminderMinutesBefore:
          defaultReminderMinutesBefore ?? current.defaultReminderMinutesBefore,
      allDayReminderHour: allDayReminderHour ?? current.allDayReminderHour,
    );
    await _store.put(LocalCollections.notificationPreferences, 'me', {
      'id': 'me',
      'globalEnabled': next.globalEnabled,
      'defaultReminderMinutesBefore': next.defaultReminderMinutesBefore,
      'allDayReminderHour': next.allDayReminderHour,
    });
    return Ok(next);
  }
}

/// Copies a staged cover into the on-device sidecar. Product uploads never
/// go to the retired API.
class LocalUploadRepository implements UploadRepository {
  LocalUploadRepository(this._store);
  final LocalStore _store;

  @override
  Future<Result<String>> uploadBookCover(String bookId, String filePath) async {
    try {
      final dest = await _store.saveCover(bookId, filePath);
      return Ok(dest.path);
    } on Object catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }
}
