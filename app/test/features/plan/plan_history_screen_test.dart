import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/plan/presentation/plan_history_empty_art.dart';
import 'package:readendar/features/plan/presentation/plan_history_screen.dart';
import '../../helpers/api_repo_stubs.dart';

PlanRun _run({
  String id = 'p1',
  int eventCount = 7,
  String mode = 'pace',
  String unit = 'chapters',
  int? perDay = 2,
}) => PlanRun(
  id: id,
  bookId: 'b1',
  eventCount: eventCount,
  mode: mode,
  unit: unit,
  perDay: perDay,
  startDate: DateTime.utc(2026, 6, 8),
  endDate: DateTime.utc(2026, 6, 20),
  total: 24,
  createdAt: DateTime.utc(2026, 6, 8, 10),
);

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
  @override
  Future<String?> getRefresh() async => null;
  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}
  @override
  Future<void> clear() async {}
}

class _FakePlanRepository extends ApiPlanRepository {
  _FakePlanRepository(this._runs)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  List<PlanRun> _runs;
  int undoCalls = 0;
  String? lastUndoId;
  int undoDeleted = 3;
  bool failList = false;
  bool failUndo = false;

  @override
  Future<Result<List<PlanRun>>> listPlans(
    String bookId, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (failList) return const Err(NetworkFailure('offline'));
    // Mirror the server's offset/limit paging so the screen's infinite scroll
    // terminates (a short page signals "done").
    if (offset >= _runs.length) return const Ok([]);
    final end = (offset + limit) > _runs.length ? _runs.length : offset + limit;
    return Ok(_runs.sublist(offset, end));
  }

  @override
  Future<Result<int>> undoPlan(String planId) async {
    undoCalls += 1;
    lastUndoId = planId;
    if (failUndo) return const Err(NetworkFailure('offline'));
    _runs = _runs.where((r) => r.id != planId).toList();
    return Ok(undoDeleted);
  }
}

Future<void> _pump(WidgetTester tester, _FakePlanRepository repo) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const PlanHistoryScreen(bookId: 'b1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a card per plan run', (tester) async {
    final repo = _FakePlanRepository([
      _run(),
      _run(id: 'p2', eventCount: 3),
    ]);
    await _pump(tester, repo);

    expect(find.byType(RdCard), findsNWidgets(2));
    expect(find.text('7 eventos'), findsOneWidget);
    expect(find.text('3 eventos'), findsOneWidget);
    // Summary line uses existing plan keys ("Meta diaria", "2 ch/day").
    expect(find.textContaining('Meta diaria'), findsWidgets);
  });

  testWidgets('empty state when there are no runs', (tester) async {
    final repo = _FakePlanRepository([]);
    await _pump(tester, repo);
    expect(find.text('Aún no hay planificaciones para este libro.'), findsOneWidget);
    expect(find.byType(PlanHistoryEmptyArt), findsOneWidget);
  });

  testWidgets('load failure offers retry and recovers in place', (
    tester,
  ) async {
    final repo = _FakePlanRepository([_run()])..failList = true;
    await _pump(tester, repo);

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(RdCard), findsNothing);

    repo.failList = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(RdCard), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('empty state offers a "Planificar lectura" launcher when a book is '
      'supplied', (tester) async {
    final repo = _FakePlanRepository([]);
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: 'reading',
    );
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planRepoProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: PlanHistoryScreen(bookId: book.id, book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay planificaciones para este libro.'), findsOneWidget);
    expect(find.byType(PlanHistoryEmptyArt), findsOneWidget);
    // The same gradient "Planificar lectura" launcher the book detail offers.
    expect(find.text('Planificar lectura'), findsOneWidget);
  });

  testWidgets('undo confirms, calls the repo and shows the deletion toast', (
    tester,
  ) async {
    final repo = _FakePlanRepository([_run()])..undoDeleted = 5;
    await _pump(tester, repo);

    // Tap the row's icon-only Undo button.
    await tester.tap(find.byIcon(LucideIcons.undo2));
    await tester.pumpAndSettle();

    // The confirm dialog appears with its destructive title.
    expect(find.text('¿Deshacer este plan?'), findsOneWidget);

    // Confirm — the dialog's "Deshacer" button (the only "Deshacer" text on screen now
    // that the row button is icon-only).
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repo.undoCalls, 1);
    expect(repo.lastUndoId, 'p1');
    // Localized deletion toast with the returned count.
    expect(find.text('Se han borrado 5 eventos del plan'), findsOneWidget);
    // The run disappears from the list (now empty state).
    expect(find.text('Aún no hay planificaciones para este libro.'), findsOneWidget);
  });

  testWidgets('cancelling the confirm does not call undo', (tester) async {
    final repo = _FakePlanRepository([_run()]);
    await _pump(tester, repo);

    await tester.tap(find.byIcon(LucideIcons.undo2));
    await tester.pumpAndSettle();
    expect(find.text('¿Deshacer este plan?'), findsOneWidget);

    // Cancel.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.undoCalls, 0);
    expect(find.byType(RdCard), findsOneWidget);
  });

  testWidgets('undo failure keeps the plan and reports the error', (
    tester,
  ) async {
    final repo = _FakePlanRepository([_run()])..failUndo = true;
    await _pump(tester, repo);

    await tester.tap(find.byIcon(LucideIcons.undo2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repo.undoCalls, 1);
    expect(find.byType(RdCard), findsOneWidget);
    expect(find.text("No se pudo deshacer el plan."), findsOneWidget);
  });
}
