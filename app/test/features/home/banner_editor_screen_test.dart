import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/banner_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selecting a preset saves it as the home banner', (tester) async {
    final env = _Env(_user());
    await tester.pumpWidget(env.wrap(const BannerEditorScreen()));
    await tester.pumpAndSettle();

    // Tap the 4th swatch (order: periwinkle, teal, sage, wine, ...).
    await tester.tap(find.bySemanticsLabel('Fondo 4'));
    await tester.pump();

    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(env.userRepo.lastHomeBanner, isNull);
    expect(
      env.session.state.user?.homeBanner,
      const BannerStyle.preset('wine'),
    );
  });

  testWidgets('reset stores the default style', (tester) async {
    final env = _Env(_user(banner: const BannerStyle.preset('teal')));
    await tester.pumpWidget(env.wrap(const BannerEditorScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Restablecer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Restablecer'));
    await tester.pump();

    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(env.userRepo.lastHomeBanner, isNull);
    expect(env.session.state.user?.homeBanner?.isDefault, isTrue);
  });

  testWidgets('local data plane persists the banner without the API', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'local'});
    final prefs = await SharedPreferences.getInstance();
    final env = _Env(_user());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) => env.session),
          userRepoProvider.overrideWithValue(env.userRepo),
          uploadRepoProvider.overrideWithValue(env.uploadRepo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const BannerEditorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Fondo 4'));
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(env.userRepo.lastHomeBanner, isNull);
    expect(
      env.session.state.user?.homeBanner,
      const BannerStyle.preset('wine'),
    );
  });
}

AppUser _user({BannerStyle banner = const BannerStyle.defaultStyle()}) =>
    AppUser(
      id: 'user-1',
      email: 'marina@example.com',
      displayName: 'Marina',
      preferredLocale: 'es',
      timezone: 'Europe/Madrid',
      onboardingCompletedAt: DateTime(2026, 5, 19),
      homeBanner: banner,
    );

class _Env {
  _Env(AppUser user)
    : session = _FakeSession(user),
      userRepo = _FakeUserRepository(),
      uploadRepo = _FakeUploadRepository() {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'local'});
  }

  final _FakeSession session;
  final _FakeUserRepository userRepo;
  final _FakeUploadRepository uploadRepo;

  Widget wrap(Widget child) => FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(),
    builder: (context, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(snap.data!),
          sessionProvider.overrideWith((ref) => session),
          userRepoProvider.overrideWithValue(userRepo),
          uploadRepoProvider.overrideWithValue(uploadRepo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: child,
        ),
      );
    },
  );
}

class _FakeSession extends SessionNotifier {
  _FakeSession(AppUser user) : super(_testRef()) {
    state = SessionState(user: user);
  }

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> persistLocalUser(AppUser user) async {
    state = SessionState(user: user);
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

  BannerStyle? lastHomeBanner;

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
    lastHomeBanner = homeBanner;
    return Ok(_user(banner: homeBanner ?? const BannerStyle.defaultStyle()));
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

// Riverpod 3 seals `Ref`, so it can't be faked with `implements` anymore.
// The fakes never touch their ref, so hand them a real one from a throwaway
// container (leaked for the test process lifetime — harmless).
Ref _testRef() => ProviderContainer().read(Provider<Ref>((ref) => ref));
