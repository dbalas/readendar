import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/analytics/analytics_service.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/timezone_picker_sheet.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_deep_link.dart';
import 'package:readendar/features/import/import_sources_screen.dart';
import 'package:readendar/features/profile/profile_editor_screen.dart';
import 'package:readendar/features/profile/profile_screen.dart';
import 'package:readendar/features/profile/settings_screen.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';
import 'package:readendar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quotes/quotes_test_utils.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The notification resync (fired when a timezone change is saved) reaches the
  // flutter_local_notifications + flutter_timezone plugins. Stub their channels
  // so those calls resolve instead of leaving the save spinner pumping forever.
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'pendingNotificationRequests'
          ? <Map<Object?, Object?>>[]
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => {'identifier': 'Europe/Madrid'},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => true,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
  });

  Future<void> _acceptTermsAndSave(WidgetTester tester) async {
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester
        .widget<RdButton>(
          find.widgetWithText(RdButton, 'Guardar y empezar'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('app gate shows the feature tour before home', (
    tester,
  ) async {
    // Incomplete profile + no device intro flag: tour first.
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(env.wrapApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Bienvenido a Readendar'), findsOneWidget);
    expect(find.text('Configura el perfil de lectura'), findsNothing);
    expect(find.text('Inicio'), findsNothing);
  });

  testWidgets('existing users are gated on the current terms version', (
    tester,
  ) async {
    final env = await _TestEnv.create(
      _pendingUser().copyWith(
        onboardingCompletedAt: DateTime(2026, 5, 19),
        termsVersion: '2026-05-01',
      ),
    );

    await tester.pumpWidget(env.wrapApp());
    await tester.pumpAndSettle();

    expect(find.text('Términos actualizados'), findsOneWidget);
    expect(find.text('Aceptar y continuar'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
  });

  testWidgets('requires a display name before saving onboarding', (
    tester,
  ) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );

    await tester.enterText(find.byType(TextField).first, '');
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester
        .widget<RdButton>(
          find.widgetWithText(RdButton, 'Guardar y empezar'),
        )
        .onPressed!();
    await tester.pump();

    expect(find.text('Campo requerido.'), findsOneWidget);
    expect(env.userRepo.updateCount, 0);
  });

  testWidgets('whitespace-only display name shows inline field error', (
    tester,
  ) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();
    tester
        .widget<RdButton>(
          find.widgetWithText(RdButton, 'Guardar y empezar'),
        )
        .onPressed!();
    await tester.pump();

    expect(find.text('Campo requerido.'), findsOneWidget);
    expect(env.userRepo.updateCount, 0);
  });

  testWidgets('blocks onboarding save until privacy and terms are accepted', (
    tester,
  ) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );
    await tester.enterText(find.byType(TextField).first, 'Marina');
    await tester.ensureVisible(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    await tester.pump();

    // Save is disabled until the contract checkbox is ticked.
    final disabled = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    expect(disabled.onPressed, isNull);

    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await tester.pump();

    final enabled = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Guardar y empezar'),
    );
    expect(enabled.onPressed, isNotNull);
    expect(env.userRepo.lastAnalyticsEnabled, isNull);
  });

  testWidgets('onboarding has no separate analytics choice', (
    tester,
  ) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );

    expect(find.text('Ayudar a mejorar Readendar'), findsNothing);
  });

  testWidgets('onboarding form reuses Rd form chrome and default scaffold bg', (
    tester,
  ) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull);

    expect(find.byType(RdFormSelectField), findsOneWidget);
    expect(find.textContaining('Idioma'), findsNothing);
    expect(find.textContaining('Zona horaria'), findsOneWidget);
  });

  testWidgets('settings has no analytics opt-out', (
    tester,
  ) async {
    final user = _pendingUser().copyWith(
      onboardingCompletedAt: DateTime(2026, 5, 19),
      termsVersion: '2026-08-01',
      analyticsEnabled: true,
    );
    final env = await _TestEnv.create(user);

    await tester.pumpWidget(env.wrap(const SettingsScreen()));
    await tester.pump();
    expect(find.text('Ayudar a mejorar Readendar'), findsNothing);
    expect(
      find.text('Copia guardada de los términos aceptados'),
      findsNothing,
    );
  });

  testWidgets('settings opens the local profile editor', (tester) async {
    final user = _pendingUser().copyWith(
      onboardingCompletedAt: DateTime(2026, 5, 19),
      termsVersion: '2026-08-01',
      analyticsEnabled: true,
    );
    final env = await _TestEnv.create(user);

    await tester.pumpWidget(env.wrap(const SettingsScreen()));
    await tester.pump();
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditorScreen), findsOneWidget);
    expect(find.byType(RdFormSelectField), findsOneWidget);
  });

  testWidgets('saves onboarding and marks it complete', (tester) async {
    final env = await _TestEnv.create(_pendingUser());

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );

    await tester.enterText(find.byType(TextField).first, 'Marina');
    await _acceptTermsAndSave(tester);

    expect(env.session.state.user?.displayName, 'Marina');
    expect(env.session.state.user?.onboardingCompletedAt, isNotNull);
  });

  testWidgets('preserves unsupported current timezone when saving profile', (
    tester,
  ) async {
    final env = await _TestEnv.create(
      _pendingUser().copyWith(timezone: 'Asia/Tokyo'),
    );

    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );

    await _acceptTermsAndSave(tester);

    expect(env.session.state.user?.timezone, 'Asia/Tokyo');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'onboarding timezone row opens a searchable picker ($platform)',
      (tester) async {
        await _withPlatform(platform, () async {
          final env = await _TestEnv.create(_pendingUser());
          await tester.pumpWidget(
            env.wrap(
              const ProfileEditorScreen(onboarding: true),
              theme: _themeFor(platform),
            ),
          );

          final timezoneField = find.byType(RdFormSelectField).first;
          await tester.ensureVisible(timezoneField);
          await tester.pump();
          await tester.tap(timezoneField);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
          expect(find.byType(TimezonePickerSheet), findsOneWidget);
          expect(find.byType(RdSearchField), findsOneWidget);
          expect(find.text('Elegir zona horaria'), findsOneWidget);
          expect(find.text('Buscar zona horaria'), findsOneWidget);
          expect(
            tester.getRect(find.byType(RdSearchField)).height,
            greaterThan(20),
          );
          expect(find.byType(ListTile), findsWidgets);

          final searchInput = find.descendant(
            of: find.byType(RdSearchField),
            matching: find.byType(EditableText),
          );
          await tester.enterText(searchInput, 'zzzz-not-a-zone');
          await tester.pump();
          expect(find.text('Sin resultados.'), findsOneWidget);

          await tester.enterText(searchInput, 'Tokyo');
          await tester.pump();
          expect(find.widgetWithText(ListTile, 'Asia/Tokyo'), findsOneWidget);
          await tester.tap(find.widgetWithText(ListTile, 'Asia/Tokyo'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(RdSearchField), findsNothing);
          expect(
            find.widgetWithText(RdFormSelectField, 'Asia/Tokyo'),
            findsOneWidget,
          );
        });
      },
    );
  }

  testWidgets(
    'dismissing the timezone picker keeps the current timezone',
    (tester) async {
      await _withPlatform(TargetPlatform.iOS, () async {
        final env = await _TestEnv.create(_pendingUser());
        await tester.pumpWidget(
          env.wrap(
            const ProfileEditorScreen(onboarding: true),
            theme: _themeFor(TargetPlatform.iOS),
          ),
        );

        final timezoneField = find.byType(RdFormSelectField).first;
        await tester.ensureVisible(timezoneField);
        await tester.pump();
        await tester.tap(timezoneField);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(RdSearchField), findsOneWidget);

        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(RdSearchField), findsNothing);
        expect(
          find.widgetWithText(RdFormSelectField, 'Europe/Madrid'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets('onboarding has no language picker', (tester) async {
    final env = await _TestEnv.create(_pendingUser());
    await tester.pumpWidget(
      env.wrap(const ProfileEditorScreen(onboarding: true)),
    );
    await tester.pump();
    expect(find.text('Elegir idioma'), findsNothing);
    expect(find.textContaining('Idioma'), findsNothing);
    expect(find.byType(RdFormSelectField), findsOneWidget);
  });

  testWidgets('profile editor saves name on the local session', (
    tester,
  ) async {
    final env = await _TestEnv.create(
      _pendingUser().copyWith(
        onboardingCompletedAt: DateTime(2026, 5, 19),
        timezone: 'Europe/Madrid',
      ),
    );

    await tester.pumpWidget(
      env.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileEditorScreen(),
                ),
              );
            },
            child: const Text('open-editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileEditorScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Marina');
    await tester.pump();
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      if (env.session.state.user?.displayName == 'Marina') break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(env.session.state.user?.displayName, 'Marina');
  });

  testWidgets('profile import action opens the generic source hub', (
    tester,
  ) async {
    final env = await _TestEnv.create(
      _pendingUser().copyWith(onboardingCompletedAt: DateTime(2026, 5, 19)),
    );

    await tester.pumpWidget(env.wrap(const ProfileScreen()));
    await tester.tap(find.text('Importar datos'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportSourcesScreen), findsOneWidget);
    expect(find.text('Goodreads'), findsOneWidget);
    expect(find.text('Bookmory'), findsOneWidget);
  });

  testWidgets('settings has no language picker', (tester) async {
    final env = await _TestEnv.create(
      _pendingUser().copyWith(onboardingCompletedAt: DateTime(2026, 5, 19)),
    );
    await tester.pumpWidget(env.wrap(const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Idioma'), findsNothing);
  });
}

AppUser _pendingUser() => AppUser(
  id: 'user-1',
  email: 'marina@example.com',
  displayName: 'marina',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: null,
);

ThemeData _themeFor(TargetPlatform platform) {
  final light = buildLightTheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: light.colorScheme,
    platform: platform,
    cupertinoOverrideTheme: platform == TargetPlatform.iOS
        ? light.cupertinoOverrideTheme
        : null,
  );
}

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

class _TestEnv {
  _TestEnv({
    required this.prefs,
    required this.session,
    required this.userRepo,
    required this.uploadRepo,
  });

  final SharedPreferences prefs;
  final _FakeSessionNotifier session;
  final _FakeUserRepository userRepo;
  final _FakeUploadRepository uploadRepo;

  static Future<_TestEnv> create(
    AppUser user, {
    _FakeUserRepository? userRepo,
    Map<String, Object> initialPreferences = const {'locale': 'es'},
  }) async {
    SharedPreferences.setMockInitialValues(initialPreferences);
    final prefs = await SharedPreferences.getInstance();
    final resolvedUserRepo = userRepo ?? _FakeUserRepository();
    final uploadRepo = _FakeUploadRepository();
    final session = _FakeSessionNotifier(user);
    return _TestEnv(
      prefs: prefs,
      session: session,
      userRepo: resolvedUserRepo,
      uploadRepo: uploadRepo,
    );
  }

  // Saving a timezone change triggers a notification resync, which reads these.
  // Stub them so the resync is a quick no-op instead of hitting the network.
  List<Override> get _notificationOverrides => [
    notificationPrefsProvider.overrideWith(
      (ref) async => NotificationPreferences(
        globalEnabled: true,
        defaultReminderMinutesBefore: 1440,
        allDayReminderHour: 9,
      ),
    ),
    notificationRepoProvider.overrideWithValue(_FakeNotificationRepository()),
    upcomingEventsProvider.overrideWith((ref) async => <ReadingEvent>[]),
    booksProvider.overrideWith((ref) async => const <Book>[]),
  ];

  List<Override> get _overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    sessionProvider.overrideWith((ref) => session),
    userRepoProvider.overrideWithValue(userRepo),
    analyticsProvider.overrideWithValue(_SuccessfulAnalytics()),
    uploadRepoProvider.overrideWithValue(uploadRepo),
    annotationRepoProvider.overrideWithValue(FakeQuoteRepository([])),
    readingChapterLatestProvider.overrideWith(
      (ref) => Stream.value(
        const ReadingChapterArchive(
          items: [],
          nextCursor: '',
          hasUnread: false,
          capabilities: ReadingChapterCapabilities(
            privateGeneration: true,
          ),
        ),
      ),
    ),
    importDeepLinkProvider.overrideWith((ref) => _FakeImportLink()),
    widgetDeepLinkProvider.overrideWith((ref) => _FakeWidgetDeepLink()),
    ..._notificationOverrides,
  ];

  Widget wrap(Widget child, {ThemeData? theme}) => ProviderScope(
    overrides: _overrides,
    child: MaterialApp(
      locale: const Locale('es'),
      theme: theme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );

  Widget wrapApp() => ProviderScope(
    overrides: _overrides,
    child: const ReadendarApp(),
  );
}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(AppUser user) : super(_testRef()) {
    state = SessionState(user: user);
  }

  @override
  Future<void> bootstrap() async {}

  @override
  void setUser(AppUser user) {
    state = SessionState(user: user);
  }

  @override
  Future<void> persistLocalUser(AppUser user) async {
    state = SessionState(user: user);
  }

  @override
  Future<Result<void>> logout() async {
    state = const SessionState();
    return const Ok(null);
  }
}

class _FakeUserRepository extends ApiUserRepository {
  _FakeUserRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  int updateCount = 0;
  bool lastCompleteOnboarding = false;
  String? lastTimezone;
  String? lastPreferredLocale;
  String? lastAcceptedTermsVersion;
  bool? lastAnalyticsEnabled;
  Result<AppUser>? nextUpdateResult;
  Result<AppUser>? completeOnboardingFailure;
  Completer<Result<AppUser>>? pendingUpdate;

  @override
  Future<Result<AppUser>> updateMe({
    String? displayName,
    String? preferredLocale,
    String? timezone,
    bool completeOnboarding = false,
    String? acceptedTermsVersion,
    bool? analyticsEnabled,
    String? analyticsNoticeVersion,
    bool? autoCreateStatusEvents,
    bool? alwaysShowSpoilerQuotes,
    BannerStyle? homeBanner,
  }) async {
    updateCount += 1;
    lastCompleteOnboarding = completeOnboarding;
    lastTimezone = timezone;
    lastPreferredLocale = preferredLocale;
    lastAcceptedTermsVersion = acceptedTermsVersion;
    lastAnalyticsEnabled = analyticsEnabled;
    if (pendingUpdate != null) return pendingUpdate!.future;
    if (completeOnboarding && completeOnboardingFailure != null) {
      return completeOnboardingFailure!;
    }
    if (nextUpdateResult != null) return nextUpdateResult!;
    return Ok(
      AppUser(
        id: 'user-1',
        email: 'marina@example.com',
        displayName: displayName ?? 'marina',
        preferredLocale: preferredLocale ?? 'es',
        timezone: timezone ?? 'Europe/Madrid',
        onboardingCompletedAt: completeOnboarding
            ? DateTime(2026, 5, 19)
            : null,
        termsAcceptedAt: DateTime(2026, 7, 23),
        termsVersion: acceptedTermsVersion ?? '2026-08-01',
        analyticsEnabled: analyticsEnabled ?? false,
        analyticsNoticeVersion: analyticsNoticeVersion ?? '',
        autoCreateStatusEvents: autoCreateStatusEvents ?? false,
      ),
    );
  }
}

class _FakeUploadRepository extends ApiUploadRepository {
  _FakeUploadRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );
}

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

class _SuccessfulAnalytics extends AnalyticsService {
  _SuccessfulAnalytics() : super(null);

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {}

  @override
  Future<void> setUserId(String? id) async {}
}

class _FakeImportLink extends ImportDeepLink {
  _FakeImportLink() : super(_testRef());

  @override
  Future<void> start() async {}
}

class _FakeWidgetDeepLink extends WidgetDeepLinkListener {
  _FakeWidgetDeepLink() : super(_testRef());

  @override
  Future<void> start() async {}
}

class _FakeNotificationRepository extends ApiNotificationRepository {
  _FakeNotificationRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  @override
  Future<Result<NotificationPreferences>> get() async => Ok(
    NotificationPreferences(
      globalEnabled: true,
      defaultReminderMinutesBefore: 1440,
      allDayReminderHour: 9,
    ),
  );
}

// Riverpod 3 seals `Ref`, so it can't be faked with `implements` anymore.
// The fakes never touch their ref, so hand them a real one from a throwaway
// container (leaked for the test process lifetime — harmless).
Ref _testRef() => ProviderContainer().read(Provider<Ref>((ref) => ref));
