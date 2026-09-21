import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/auth/login_screen.dart';
import 'package:readendar/features/auth/magic_link_deep_link.dart';
import 'package:readendar/features/offline/migration_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStorage> dismissedPrefs() async {
    SharedPreferences.setMockInitialValues({
      'migration_prompt_dismissed:v1': true,
    });
    return PrefsStorage(await SharedPreferences.getInstance());
  }

  testWidgets('shows a home row after the prompt was dismissed', (
    tester,
  ) async {
    final prefs = await dismissedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('migrationHomeRow')), findsOneWidget);
    expect(
      find.text('Descarga tu biblioteca antes del cierre'),
      findsOneWidget,
    );
    expect(find.text('Descargar mis datos'), findsOneWidget);
  });

  testWidgets('uses accent color, wraps body copy, and compact download CTA', (
    tester,
  ) async {
    final prefs = await dismissedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    final outer = tester.widget<Padding>(
      find.ancestor(
        of: find.byType(RdCard),
        matching: find.byType(Padding),
      ),
    );
    expect(outer.padding, const EdgeInsets.fromLTRB(20, 0, 20, 14));

    final card = tester.widget<RdCard>(find.byType(RdCard));
    expect(card.padding, const EdgeInsets.all(12));
    expect(card.backgroundColor, ReadendarColors.light.accentSoftBg);

    final body = tester.widget<Text>(
      find.textContaining('Los servidores de Readendar se apagarán'),
    );
    expect(body.maxLines, isNull);
    expect(body.overflow, isNot(TextOverflow.ellipsis));

    final button = tester.widget<RdButton>(find.byType(RdButton));
    expect(button.expand, isFalse);
    expect(button.label, 'Descargar mis datos');
  });

  testWidgets('hides the row after a successful import flag', (tester) async {
    final prefs = await dismissedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('migrationHomeRow')), findsNothing);
  });

  testWidgets('download without a token opens the restored login screen', (
    tester,
  ) async {
    final prefs = await dismissedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
          secureStorageProvider.overrideWithValue(_EmptyTokenStorage()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Descargar mis datos'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('login success starts the cloud download', (tester) async {
    final prefs = await dismissedPrefs();
    final import = _TrackingImportService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
          secureStorageProvider.overrideWithValue(_EmptyTokenStorage()),
          importServiceProvider.overrideWithValue(import),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Descargar mis datos'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final loginContext = tester.element(find.byType(LoginScreen));
    Navigator.of(loginContext).pop(true);
    await tester.pumpAndSettle();

    expect(import.calls, 1);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('valid token starts download without login', (tester) async {
    final prefs = await dismissedPrefs();
    final import = _TrackingImportService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
          secureStorageProvider.overrideWithValue(_AccessTokenStorage()),
          userRepoProvider.overrideWithValue(_OkUserRepository()),
          importServiceProvider.overrideWithValue(import),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Descargar mis datos'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(import.calls, 1);
  });

  testWidgets('rejected leftover JWT opens login and drops the stale tokens', (
    tester,
  ) async {
    final prefs = await dismissedPrefs();
    final storage = _StaleTokenStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
          secureStorageProvider.overrideWithValue(storage),
          userRepoProvider.overrideWithValue(
            _FailureUserRepository(const UnauthorizedFailure()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Descargar mis datos'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(storage.cleared, isTrue);
  });

  testWidgets(
    'magic link sign-in on Home starts import without another tap',
    (tester) async {
      final prefs = await dismissedPrefs();
      final import = _TrackingImportService(prefs);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStorageProvider.overrideWithValue(prefs),
            cloudImportAvailableProvider.overrideWith((ref) => true),
            secureStorageProvider.overrideWithValue(_AccessTokenStorage()),
            userRepoProvider.overrideWithValue(_OkUserRepository()),
            importServiceProvider.overrideWithValue(import),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(body: MigrationBanner());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(import.calls, 0);

      container.read(magicLinkSignedInTickProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(import.calls, 1);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets(
    'magic link does not start a second import while another surface is in flight',
    (tester) async {
      final prefs = await dismissedPrefs();
      final import = _TrackingImportService(prefs);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStorageProvider.overrideWithValue(prefs),
            cloudImportAvailableProvider.overrideWith((ref) => true),
            secureStorageProvider.overrideWithValue(_AccessTokenStorage()),
            userRepoProvider.overrideWithValue(_OkUserRepository()),
            importServiceProvider.overrideWithValue(import),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(body: MigrationBanner());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      container.read(cloudImportInFlightProvider.notifier).state = true;

      container.read(magicLinkSignedInTickProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(import.calls, 0);
    },
  );

  testWidgets('download tap is ignored while login is already open', (
    tester,
  ) async {
    final prefs = await dismissedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          cloudImportAvailableProvider.overrideWith((ref) => true),
          secureStorageProvider.overrideWithValue(_EmptyTokenStorage()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: MigrationBanner()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Descargar mis datos'));
    await tester.pump();
    expect(tester.widget<RdButton>(find.byType(RdButton)).onPressed, isNull);

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

class _EmptyTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;
}

class _AccessTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => 'access';

  @override
  Future<String?> getRefresh() async => 'refresh';
}

class _StaleTokenStorage extends SecureTokenStorage {
  String? access = 'stale';
  bool cleared = false;

  @override
  Future<String?> getAccess() async => access;

  @override
  Future<String?> getRefresh() async => cleared ? null : 'stale-refresh';

  @override
  Future<void> clear() async {
    cleared = true;
    access = null;
  }
}

class _FailureUserRepository extends ApiUserRepository {
  _FailureUserRepository(this.failure)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _EmptyTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  final Failure failure;

  @override
  Future<Result<AppUser>> getMe() async => Err(failure);
}

class _OkUserRepository extends ApiUserRepository {
  _OkUserRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _EmptyTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  @override
  Future<Result<AppUser>> getMe() async => Ok(
    AppUser(
      id: 'cloud-1',
      email: 'a@b.c',
      displayName: 'Ada',
      preferredLocale: 'es',
      timezone: 'Europe/Madrid',
      onboardingCompletedAt: DateTime.utc(2026),
    ),
  );
}

class _TrackingImportService extends ImportService {
  _TrackingImportService(PrefsStorage prefs)
    : super(
        store: LocalStore.memory(Directory.systemTemp),
        prefs: prefs,
        fetchExport: () async => <String, dynamic>{},
        fetchCover: (_) async => const CoverBytes(statusCode: 404),
      );

  int calls = 0;

  @override
  Future<Result<void>> importFromApi({
    ImportProgressListener? onProgress,
  }) async {
    calls += 1;
    return const Err(NetworkFailure('skip success path'));
  }
}
