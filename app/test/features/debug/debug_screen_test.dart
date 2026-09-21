import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/debug/debug_screen.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  LocalStore memoryStore() {
    final dir = Directory.systemTemp.createTempSync('debug-scr');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return LocalStore.memory(Directory('${dir.path}/covers')..createSync());
  }

  Widget wrap(DebugRepository repo, {LocalStore? store}) => ProviderScope(
    overrides: [
      debugRepoProvider.overrideWithValue(repo),
      if (store != null) localStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const DebugScreen(),
    ),
  );

  testWidgets('delete-all-events confirms before calling, then reports count', (
    tester,
  ) async {
    // Tall surface so every debug card fits without scrolling wipe buttons off.
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = memoryStore();
    for (var i = 0; i < 4; i++) {
      await store.put(LocalCollections.events, 'e$i', {
        'id': 'e$i',
        'ownerType': 'user',
        'ownerId': 'local-guest',
        'type': 'start',
        'title': 'Event $i',
        'dateLocal': '2026-09-21',
        'status': 'active',
      });
    }
    final repo = _FakeDebugRepository();
    await tester.pumpWidget(wrap(repo, store: store));
    await tester.pumpAndSettle();
    expect(find.text('Previsualizar notificaciones'), findsNothing);
    expect(find.text('Cargar datos de prueba'), findsOneWidget);

    // First tap surfaces a confirmation; nothing is deleted yet.
    await tester.tap(
      find.widgetWithText(FilledButton, 'Borrar todos los eventos'),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar todos los eventos?'), findsOneWidget);
    expect((await store.list(LocalCollections.events)).length, 4);

    // Cancelling aborts.
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect((await store.list(LocalCollections.events)).length, 4);

    // Confirming runs the wipe and shows the count in a snackbar.
    await tester.tap(
      find.widgetWithText(FilledButton, 'Borrar todos los eventos'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Borrar todos los eventos').last,
    );
    await tester.pumpAndSettle();

    expect((await store.list(LocalCollections.events)).length, 0);
    expect(find.text('4 eventos borrados'), findsOneWidget);
  });

  testWidgets('delete-all-books confirms then reports count', (tester) async {
    // Tall surface so every debug card fits without scrolling wipe buttons off.
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = memoryStore();
    for (var i = 0; i < 2; i++) {
      await store.put(LocalCollections.books, 'b$i', {
        'id': 'b$i',
        'ownerType': 'user',
        'ownerId': 'local-guest',
        'title': 'Book $i',
        'authors': ['A'],
        'status': 'pending',
      });
    }
    final repo = _FakeDebugRepository();
    await tester.pumpWidget(wrap(repo, store: store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Borrar todos los libros'),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar todos los libros?'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Borrar todos los libros').last,
    );
    await tester.pumpAndSettle();

    expect((await store.list(LocalCollections.books)).length, 0);
    expect(find.text('2 libros borrados'), findsOneWidget);
  });

  testWidgets(
    'store review preview opens the modal without wipe side effects',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeDebugRepository();
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Previsualizar modal de valoración'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('¿Te está gustando Readendar?'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('¿Te está gustando Readendar?'), findsNothing);
      expect(repo.eventsCalls, 0);
      expect(repo.booksCalls, 0);
    },
  );

  testWidgets(
    'feedback preview opens the modal without wipe side effects',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeDebugRepository();
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Previsualizar modal de feedback'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('¿Cómo va Readendar?'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('¿Cómo va Readendar?'), findsNothing);
      expect(repo.eventsCalls, 0);
      expect(repo.booksCalls, 0);
    },
  );

  testWidgets(
    'feedback preview CTA mails hello@readendar.com, not the compose screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final launched = <Uri>[];
      feedbackLaunchUrl = (uri) async {
        launched.add(uri);
        return true;
      };
      addTearDown(() {
        feedbackLaunchUrl = (uri) =>
            throw StateError('feedbackLaunchUrl must be stubbed in tests');
      });
      final repo = _FakeDebugRepository();
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Previsualizar modal de feedback'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Enviar feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Enviar comentarios'), findsNothing);
      expect(launched, hasLength(1));
      expect(launched.single.scheme, 'mailto');
      expect(launched.single.path, feedbackSupportEmail);
      expect(repo.eventsCalls, 0);
      expect(repo.booksCalls, 0);
    },
  );

  testWidgets(
    'feedback preview CTA shows an error when mail cannot open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      feedbackLaunchUrl = (uri) async => false;
      addTearDown(() {
        feedbackLaunchUrl = (uri) =>
            throw StateError('feedbackLaunchUrl must be stubbed in tests');
      });
      await tester.pumpWidget(wrap(_FakeDebugRepository()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Previsualizar modal de feedback'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Enviar feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(
          'No se pudo abrir el correo. Escríbenos a hello@readendar.com.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('update preview with notes does not wipe data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeDebugRepository();
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Previsualizar actualización con novedades'),
      200,
    );
    await tester.tap(find.text('Previsualizar actualización con novedades'));
    await tester.pumpAndSettle();

    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(find.textContaining('Widgets de inicio'), findsOneWidget);
    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(repo.eventsCalls, 0);
    expect(repo.booksCalls, 0);
  });

  testWidgets('update preview Update stays on debug tools', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(_FakeDebugRepository()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Previsualizar actualización genérica'),
      200,
    );
    await tester.tap(find.text('Previsualizar actualización genérica'));
    await tester.pumpAndSettle();
    expect(find.text('Actualización disponible'), findsOneWidget);
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(find.text('Herramientas de depuración'), findsOneWidget);
  });

  testWidgets('update preview with generic body uses ARB copy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(_FakeDebugRepository()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Previsualizar actualización genérica'),
      200,
    );
    await tester.tap(find.text('Previsualizar actualización genérica'));
    await tester.pumpAndSettle();

    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(
      find.text('Hay una versión nueva de Readendar en la tienda.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(find.text('Actualización disponible'), findsNothing);
  });

  testWidgets('archetype preview opens the live card gallery', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(_FakeDebugRepository()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ver arquetipos lectores'),
      200,
    );
    await tester.tap(find.text('Ver arquetipos lectores'));
    await tester.pumpAndSettle();

    expect(find.text('Arquetipos lectores'), findsWidgets);
    expect(find.byKey(const Key('debug-archetype-keeper')), findsOneWidget);
    expect(find.text('El Guardián'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('debug-archetype-leviathan')),
      400,
    );
    expect(find.byKey(const Key('debug-archetype-leviathan')), findsOneWidget);
    expect(find.text('El Leviatán'), findsOneWidget);
  });

  testWidgets('local seed confirms, cancel does not touch storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(_FakeDebugRepository()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Cargar datos de prueba'),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Sustituir los datos locales?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Sustituir los datos locales?'), findsNothing);
    expect(find.text('Herramientas de depuración'), findsOneWidget);
  });

  testWidgets('local seed confirm without a store reports failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(_FakeDebugRepository()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Cargar datos de prueba'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Cargar datos de prueba').last,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('localStoreProvider must be overridden'),
      findsOneWidget,
    );
  });

  testWidgets('restore cloud import token saves JWT and shows success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(const {
      'migration_prompt_dismissed:v1': true,
      'migration_banner_hidden:v1': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = _RecordingTokenStorage();
    final repo = _FakeDebugRepository(session: _qaSession());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugRepoProvider.overrideWithValue(repo),
          secureStorageProvider.overrideWithValue(storage),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const DebugScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Restaurar token de importación'),
      200,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Restaurar token de importación'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.importSessionCalls, 1);
    expect(storage.access, 'access-qa');
    expect(storage.refresh, 'refresh-qa');
    expect(prefs.getBool('migration_prompt_dismissed:v1'), isFalse);
    expect(prefs.getBool('migration_banner_hidden:v1'), isFalse);
    expect(
      find.text('Token restaurado. Se muestra el aviso de descarga.'),
      findsOneWidget,
    );
  });

  testWidgets('restore cloud import token failure does not save JWT', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final storage = _RecordingTokenStorage();
    final repo = _FakeDebugRepository(
      sessionError: const NotFoundFailure('user_not_found'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugRepoProvider.overrideWithValue(repo),
          secureStorageProvider.overrideWithValue(storage),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const DebugScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Restaurar token de importación'),
      200,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Restaurar token de importación'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.importSessionCalls, 1);
    expect(storage.access, isNull);
    expect(
      find.text('No se ha podido emitir el token. Reinicia el API local en modo dev.'),
      findsOneWidget,
    );
  });
}

class _FakeDebugRepository extends DebugRepository {
  _FakeDebugRepository({
    this.events = 0,
    this.books = 0,
    this.session,
    this.sessionError,
  }) : super(
         ApiClient(
           baseUrl: 'http://localhost',
           storage: _FakeSecureTokenStorage(),
           localeProvider: () => 'en',
         ),
       );

  final int events;
  final int books;
  final AuthSession? session;
  final Failure? sessionError;
  int eventsCalls = 0;
  int booksCalls = 0;
  int importSessionCalls = 0;

  @override
  Future<Result<AuthSession>> issueCloudImportSession() async {
    importSessionCalls += 1;
    if (sessionError != null) return Err(sessionError!);
    return Ok(session!);
  }
}

AuthSession _qaSession() => AuthSession(
  user: AppUser(
    id: 'user-qa',
    email: 'qa@example.com',
    displayName: 'QA',
    preferredLocale: 'es',
    timezone: 'Europe/Madrid',
    onboardingCompletedAt: DateTime.utc(2026, 1, 1),
  ),
  accessToken: 'access-qa',
  refreshToken: 'refresh-qa',
  isNewUser: false,
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

class _RecordingTokenStorage extends SecureTokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> getAccess() async => access;

  @override
  Future<String?> getRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
