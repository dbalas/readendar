import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/search/cover_picker_screen.dart';

class _FakeSearchRepo extends Fake implements SearchRepository {
  _FakeSearchRepo({this.items = const [], this.result});

  List<SearchHit> items;
  Result<SearchPage>? result;
  Future<Result<SearchPage>>? pending;
  int searchCalls = 0;
  String? lastQuery;
  bool? lastAllLanguages;

  @override
  Future<Result<SearchPage>> search(
    String query, {
    String? column,
    int page = 1,
    int limit = 20,
    bool allLanguages = false,
  }) async {
    searchCalls++;
    lastQuery = query;
    lastAllLanguages = allLanguages;
    if (pending != null) return pending!;
    if (result != null) return result!;
    return Ok(SearchPage(items: items, page: 1, limit: 20, hasMore: false));
  }
}

SearchHit _hit({
  required String title,
  String coverUrl = 'https://covers.example/dune.jpg',
  String isbn = '9780441172719',
}) {
  return SearchHit(
    title: title,
    authors: const ['Herbert'],
    isbn: isbn,
    coverUrl: coverUrl,
  );
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required SearchRepository repo,
  String query = 'Dune',
  String author = 'Herbert',
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [searchRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: CoverPickerScreen(query: query, author: author),
      ),
    ),
  );
}

void main() {
  testWidgets('CoverPickerScreen uses RdSearchField with clear and submit', (
    tester,
  ) async {
    final repo = _FakeSearchRepo();
    await _pumpPicker(tester, repo: repo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(RdSearchField), findsOneWidget);
    expect(find.text('Dune Herbert'), findsOneWidget);
    expect(repo.searchCalls, 1);
    expect(repo.lastAllLanguages, isTrue);

    await tester.enterText(find.byType(SearchBar), 'Foundation Asimov');
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    expect(find.text('Foundation Asimov'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'Neuromancer');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.searchCalls, 2);
    expect(repo.lastQuery, 'Neuromancer');
  });

  testWidgets('CoverPickerScreen submits from the iOS search glyph', (
    tester,
  ) async {
    final repo = _FakeSearchRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchRepoProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CoverPickerScreen(query: 'Dune', author: 'Herbert'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(RdSearchField.iosFieldKey), findsOneWidget);
    expect(repo.searchCalls, 1);

    await tester.enterText(find.byType(CupertinoTextField), 'Neuromancer');
    await tester.tap(find.byIcon(LucideIcons.search));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.searchCalls, 2);
    expect(repo.lastQuery, 'Neuromancer');
  });

  testWidgets('CoverPickerScreen shows ErrorRetry when search fails', (
    tester,
  ) async {
    final repo = _FakeSearchRepo(result: const Err(NetworkFailure()));
    await _pumpPicker(tester, repo: repo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ErrorRetry), findsOneWidget);
  });

  testWidgets('CoverPickerScreen shows loading while search is in flight', (
    tester,
  ) async {
    final pending = Completer<Result<SearchPage>>();
    final repo = _FakeSearchRepo()..pending = pending.future;
    await _pumpPicker(tester, repo: repo);
    await tester.pump();
    await tester.pump();

    expect(find.byType(RdProgress), findsOneWidget);
    expect(find.text('Buscando libros…'), findsOneWidget);

    pending.complete(
      const Ok(SearchPage(items: [], page: 1, limit: 20, hasMore: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(RdProgress), findsNothing);
  });

  testWidgets(
    'CoverPickerScreen hides unusable covers and shows empty state',
    (tester) async {
      final repo = _FakeSearchRepo(
        items: [
          _hit(title: 'No jacket', coverUrl: '', isbn: '1'),
          _hit(
            title: 'Placeholder',
            coverUrl: 'https://imagessl4.casadellibro.com/a/l/t1/defecto4.jpg',
            isbn: '2',
          ),
        ],
      );
      await _pumpPicker(tester, repo: repo);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Sin resultados.'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    },
  );

  testWidgets('CoverPickerScreen shows usable covers and pops the tap', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final dune = _hit(title: 'Dune');
      final skipped = _hit(title: 'No jacket', coverUrl: '', isbn: '1');
      final repo = _FakeSearchRepo(items: [skipped, dune]);
      SearchHit? picked;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [searchRepoProvider.overrideWithValue(repo)],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  picked = await Navigator.of(context).push<SearchHit>(
                    MaterialPageRoute(
                      builder: (_) => const CoverPickerScreen(
                        query: 'Dune',
                        author: 'Herbert',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byKey(const ValueKey('cover-pick-isbn:1')), findsNothing);
      final tile = find.byKey(const ValueKey('cover-pick-isbn:9780441172719'));
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(picked?.title, 'Dune');
      expect(picked?.coverUrl, dune.coverUrl);
    });
  });
}
