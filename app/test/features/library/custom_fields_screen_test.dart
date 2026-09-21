import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/settings_group.dart';
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/custom_fields_manage_cache.dart';
import 'package:readendar/features/library/custom_fields_screen.dart';

void main() {
  test('onReorderItem indices insert without extra adjustment', () {
    expect(reorderCustomFieldItems(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(reorderCustomFieldItems(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
  });

  void largeSheetSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  List<Map<String, dynamic>> systemLayout({
    List<Map<String, dynamic>> customs = const [],
  }) => [
    ...customs,
    for (final key in bookDetailSystemFieldKeys)
      {'key': key, 'kind': 'system', 'hidden': false},
  ];

  LocalStore memoryStore() {
    final dir = Directory.systemTemp.createTempSync('cf-ui');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return LocalStore.memory(Directory('${dir.path}/covers')..createSync());
  }

  Future<void> putDefinition(
    LocalStore store, {
    required String id,
    required String name,
    String iconKey = 'tag',
    String type = 'text',
    String textMode = 'single_line',
    int position = 0,
    int usageCount = 0,
    List<Map<String, dynamic>> options = const [],
  }) {
    return store.put(LocalCollections.customFieldDefinitions, id, {
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'type': type,
      'textMode': textMode,
      'position': position,
      'usageCount': usageCount,
      'options': options,
    });
  }

  Future<void> putLayout(
    LocalStore store,
    List<Map<String, dynamic>> items,
  ) {
    return store.put(LocalCollections.customFieldDefinitions, '__layout__', {
      'id': '__layout__',
      'items': items,
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CustomFieldRepository repo,
    CustomFieldsManageCache? cache,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customFieldRepoProvider.overrideWithValue(repo),
          if (cache != null)
            customFieldsManageCacheProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme().copyWith(platform: platform),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CustomFieldsScreen(),
        ),
      ),
    );
  }

  CustomFieldDefinition named(
    List<CustomFieldDefinition> defs,
    String name,
  ) => defs.singleWhere((def) => def.name == name);

  testWidgets('new definition requires a name and stores the field locally', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final repo = LocalCustomFieldRepository(memoryStore());
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir campo'));
    await tester.pumpAndSettle();

    RdButton saveButton() => tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Guardar'),
    );
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(RdTextField).first, 'Mood');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Campo personalizado guardado.'), findsOneWidget);
    expect(find.text('Mood'), findsOneWidget);
    final defs = (await repo.listDefinitions()).value!;
    expect(named(defs, 'Mood').iconKey, 'tag');
    expect(named(defs, 'Mood').textMode, 'single_line');
  });

  testWidgets(
    'failed create rotates idempotency key and shows an error toast',
    (
      tester,
    ) async {
      largeSheetSurface(tester);
      final failing = _CreateFailingFields(
        LocalCustomFieldRepository(memoryStore()),
      );
      await pumpScreen(tester, repo: failing);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Añadir campo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(RdTextField).first, 'Mood');
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa los datos introducidos.'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(failing.keys, hasLength(2));
      expect(failing.keys[0], isNot(failing.keys[1]));
      expect((await failing.listDefinitions()).value, isEmpty);
    },
  );

  testWidgets('post-save reload wins over a stale silent refresh', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final cache = CustomFieldsManageCache()
      ..write(
        CustomFieldsManageSnapshot(
          layout: systemLayout()
              .map(BookDetailFieldLayoutItem.fromJson)
              .toList(),
          definitions: const {},
        ),
      );
    final releaseStale = Completer<void>();
    final repo = _StaleLayoutFields(
      LocalCustomFieldRepository(memoryStore()),
      releaseStale,
    );
    await pumpScreen(tester, repo: repo, cache: cache);
    await tester.pump();
    await tester.tap(find.byTooltip('Añadir campo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(RdTextField).first, 'Mood');
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Campo personalizado guardado.'), findsOneWidget);

    releaseStale.complete();
    await tester.pumpAndSettle();
    expect(find.text('Mood'), findsOneWidget);
  });

  testWidgets(
    'editor uses adaptive fields and saves definition with options once',
    (tester) async {
      largeSheetSurface(tester);
      final store = memoryStore();
      await putDefinition(
        store,
        id: 'field-1',
        name: 'Shelf',
        iconKey: 'library',
        type: 'single_select',
        textMode: '',
        options: const [
          {
            'id': 'option-1',
            'label': 'Owned',
            'position': 0,
            'usageCount': 0,
          },
        ],
      );
      await putLayout(
        store,
        systemLayout(
          customs: const [
            {'key': 'field-1', 'kind': 'custom', 'hidden': false},
          ],
        ),
      );
      final repo = LocalCustomFieldRepository(store);
      await pumpScreen(tester, repo: repo, platform: TargetPlatform.iOS);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shelf'));
      await tester.pumpAndSettle();

      expect(find.byType(RdFormSelectField), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('customFieldIconSelector')), findsOneWidget);
      expect(find.byKey(const Key('customFieldIcon-library')), findsNothing);
      await tester.enterText(find.byType(RdTextField).first, 'My shelf');
      await tester.tap(find.byKey(const Key('customFieldIconSelector')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customFieldIcon-library')), findsOneWidget);
      await tester.tap(find.byKey(const Key('customFieldIcon-library')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final def = named((await repo.listDefinitions()).value!, 'My shelf');
      expect(def.iconKey, 'library');
      expect(def.options, [
        const CustomFieldOption(id: 'option-1', label: 'Owned', position: 0),
      ]);
    },
  );

  testWidgets('icon gallery selects an icon and datetime can hide time', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final repo = LocalCustomFieldRepository(memoryStore());
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir campo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(RdTextField).first, 'Published');
    await tester.tap(find.text('Texto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fecha y hora').last);
    await tester.pumpAndSettle();

    expect(find.text('Mostrar hora'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('customFieldIconSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customFieldIcon-coffee')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final def = named((await repo.listDefinitions()).value!, 'Published');
    expect(def.iconKey, 'coffee');
    expect(def.textMode, 'date');
    expect(def.type, CustomFieldType.datetime);
  });

  testWidgets('hide and reorder persist without a success toast', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final store = memoryStore();
    await putDefinition(
      store,
      id: 'field-a',
      name: 'Alpha',
      position: 0,
    );
    await putDefinition(
      store,
      id: 'field-b',
      name: 'Beta',
      position: 1,
    );
    await putLayout(store, [
      const {'key': 'field-a', 'kind': 'custom', 'hidden': false},
      const {'key': 'field-b', 'kind': 'custom', 'hidden': false},
      ...[
        for (final key in bookDetailSystemFieldKeys)
          {'key': key, 'kind': 'system', 'hidden': false},
      ],
    ]);
    final repo = LocalCustomFieldRepository(store);
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();

    final publisherRow = find.ancestor(
      of: find.text('Editorial'),
      matching: find.byType(SettingsGroup),
    );
    await tester.tap(
      find.descendant(of: publisherRow, matching: find.byIcon(LucideIcons.eye)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campo personalizado guardado.'), findsNothing);
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Editorial'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, lessThan(1));

    final hidden = (await repo.listLayout()).value!.singleWhere(
      (item) => item.key == 'publisher',
    );
    expect(hidden.hidden, isTrue);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 2);
    await tester.pumpAndSettle();
    expect(
      (await repo.listLayout()).value!.map((item) => item.key).take(3).toList(),
      ['field-b', 'synopsis', 'field-a'],
    );
  });

  testWidgets('re-entry paints cached layout then refreshes silently', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final cache = CustomFieldsManageCache();
    cache.write(
      const CustomFieldsManageSnapshot(
        layout: [
          BookDetailFieldLayoutItem(
            key: 'publisher',
            kind: BookDetailFieldKind.system,
            hidden: false,
          ),
        ],
        definitions: {},
      ),
    );
    final store = memoryStore();
    await putDefinition(
      store,
      id: 'field-1',
      name: 'Shelf',
      iconKey: 'library',
    );
    await putLayout(
      store,
      systemLayout(
        customs: const [
          {'key': 'field-1', 'kind': 'custom', 'hidden': false},
        ],
      ),
    );
    final repo = _DelayedFields(LocalCustomFieldRepository(store));

    await pumpScreen(tester, repo: repo, cache: cache);
    await tester.pump();
    expect(find.text('Editorial'), findsOneWidget);
    expect(find.text('Shelf'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Shelf'), findsOneWidget);
  });

  testWidgets('existing text field can change its text style', (tester) async {
    largeSheetSurface(tester);
    final store = memoryStore();
    await putDefinition(
      store,
      id: 'field-1',
      name: 'Notas',
      iconKey: 'pen-line',
    );
    await putLayout(
      store,
      systemLayout(
        customs: const [
          {'key': 'field-1', 'kind': 'custom', 'hidden': false},
        ],
      ),
    );
    final repo = LocalCustomFieldRepository(store);
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Una línea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Varias líneas').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(named((await repo.listDefinitions()).value!, 'Notas').textMode, 'multiline');
  });

  testWidgets('manage screen lists standard metadata with hide controls', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final repo = LocalCustomFieldRepository(memoryStore());
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('Editorial'), findsOneWidget);
    expect(find.text('Estándar'), findsWidgets);
    expect(find.text('Páginas'), findsNothing);
    expect(find.text('Capítulos'), findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsNothing);
    expect(find.byIcon(LucideIcons.eye), findsWidgets);

    final publisherRow = find.ancestor(
      of: find.text('Editorial'),
      matching: find.byType(SettingsGroup),
    );
    await tester.tap(
      find.descendant(of: publisherRow, matching: find.byIcon(LucideIcons.eye)),
    );
    await tester.pumpAndSettle();
    final items = (await repo.listLayout()).value!;
    expect(items, isNotEmpty);
    expect(
      items.any((item) => item.key == 'publisher' && item.hidden),
      isTrue,
    );
  });

  testWidgets('single-select editor groups options under their own section', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final repo = LocalCustomFieldRepository(memoryStore());
    await pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir campo'));
    await tester.pumpAndSettle();

    expect(find.text('Texto'), findsWidgets);
    await tester.tap(find.text('Texto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selector simple').last);
    await tester.pumpAndSettle();

    expect(find.text('OPCIONES'), findsOneWidget);
    expect(find.text('Añadir opción'), findsOneWidget);
    await tester.tap(find.text('Añadir opción'));
    await tester.pump();
    expect(find.byType(RdTextField), findsAtLeastNWidgets(2));
  });

  testWidgets('definition rows put drag left and danger delete right', (
    tester,
  ) async {
    largeSheetSurface(tester);
    final store = memoryStore();
    await putDefinition(
      store,
      id: 'field-1',
      name: 'Shelf',
      iconKey: 'library',
    );
    await putLayout(
      store,
      systemLayout(
        customs: const [
          {'key': 'field-1', 'kind': 'custom', 'hidden': false},
        ],
      ),
    );
    await pumpScreen(tester, repo: LocalCustomFieldRepository(store));
    await tester.pumpAndSettle();

    final drag = find.byIcon(LucideIcons.gripVertical).first;
    final trash = find.byIcon(LucideIcons.trash2);
    final title = find.text('Shelf');
    expect(trash, findsOneWidget);
    expect(tester.getCenter(drag).dx, lessThan(tester.getCenter(title).dx));
    expect(tester.getCenter(title).dx, lessThan(tester.getCenter(trash).dx));

    final colors = tester.element(title).colors;
    final deleteButton = tester.widget<RdIconButton>(
      find.widgetWithIcon(RdIconButton, LucideIcons.trash2),
    );
    expect(deleteButton.color, colors.danger);

    final fieldIcon = tester.widget<Icon>(find.byIcon(LucideIcons.library));
    expect(fieldIcon.color, colors.accentSoftFg);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.proxyDecorator, isNotNull);
  });

  testWidgets('drag proxy elevates the row without inter-row gap fill', (
    tester,
  ) async {
    const rowSize = Size(280, 64);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return fieldLayoutDragProxy(
                  context: context,
                  animation: const AlwaysStoppedAnimation<double>(1),
                  child: SizedBox.fromSize(
                    size: rowSize,
                    child: const ColoredBox(color: Colors.orange),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final elevated = tester
        .widgetList<Material>(find.byType(Material))
        .firstWhere((m) => m.elevation > 0);
    expect(elevated.color, Colors.transparent);
    expect(elevated.elevation, 6);
    expect(tester.getSize(find.byWidget(elevated)), rowSize);
  });
}

class _ForwardingCustomFields implements CustomFieldRepository {
  _ForwardingCustomFields(this.inner);
  final CustomFieldRepository inner;

  @override
  Future<Result<List<CustomFieldDefinition>>> listDefinitions() =>
      inner.listDefinitions();

  @override
  Future<Result<List<BookCustomField>>> listForBook(String bookId) =>
      inner.listForBook(bookId);

  @override
  Future<Result<void>> reorder(List<String> ids) => inner.reorder(ids);

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() =>
      inner.listLayout();

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> saveLayout(
    List<BookDetailFieldLayoutItem> items,
  ) => inner.saveLayout(items);

  @override
  Future<Result<CustomFieldDefinition>> create({
    required String idempotencyKey,
    required String name,
    required String iconKey,
    required String type,
    String textMode = '',
    List<Map<String, dynamic>>? options,
  }) => inner.create(
    idempotencyKey: idempotencyKey,
    name: name,
    iconKey: iconKey,
    type: type,
    textMode: textMode,
    options: options,
  );

  @override
  Future<Result<CustomFieldDefinition>> update(
    String fieldId, {
    required String name,
    required String iconKey,
    required String type,
    String textMode = '',
    List<Map<String, dynamic>>? options,
    List<String> cascadeOptionDeleteIds = const [],
  }) => inner.update(
    fieldId,
    name: name,
    iconKey: iconKey,
    type: type,
    textMode: textMode,
    options: options,
    cascadeOptionDeleteIds: cascadeOptionDeleteIds,
  );

  @override
  Future<Result<void>> delete(String fieldId, {bool cascade = false}) =>
      inner.delete(fieldId, cascade: cascade);
}

class _CreateFailingFields extends _ForwardingCustomFields {
  _CreateFailingFields(super.inner);

  final keys = <String>[];

  @override
  Future<Result<CustomFieldDefinition>> create({
    required String idempotencyKey,
    required String name,
    required String iconKey,
    required String type,
    String textMode = '',
    List<Map<String, dynamic>>? options,
  }) async {
    keys.add(idempotencyKey);
    return const Err(ValidationFailure('constraint_violation'));
  }
}

class _DelayedFields extends _ForwardingCustomFields {
  _DelayedFields(super.inner);

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return inner.listLayout();
  }

  @override
  Future<Result<List<CustomFieldDefinition>>> listDefinitions() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return inner.listDefinitions();
  }
}

class _StaleLayoutFields extends _ForwardingCustomFields {
  _StaleLayoutFields(super.inner, this.releaseStale);

  final Completer<void> releaseStale;
  var layoutGets = 0;

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() async {
    layoutGets++;
    if (layoutGets == 1) {
      final stale = await inner.listLayout();
      await releaseStale.future;
      return stale;
    }
    return inner.listLayout();
  }
}
