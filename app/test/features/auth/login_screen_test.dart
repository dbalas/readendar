import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/widgets/apple_sign_in_button.dart';
import 'package:readendar/core/widgets/google_sign_in_button.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/auth/apple_auth.dart';
import 'package:readendar/features/auth/google_auth.dart';
import 'package:readendar/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows a localized rate-limit message', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository(
      requestMagicLinkResult: const Err(
        RateLimitedFailure(null, 'rate_limited'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Demasiadas peticiones. Espera un momento.'),
      findsOneWidget,
    );
    expect(find.text('rate_limited'), findsNothing);
  });

  testWidgets('counts down and disables submit when Retry-After is sent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository(
      requestMagicLinkResult: const Err(
        RateLimitedFailure(3, 'rate_limited'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The full message names the wait, and the button shows a compact timer.
    expect(
      find.text(
        'Demasiados intentos de acceso. Inténtalo de nuevo en 3 segundos.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(RdButton, 'Espera 3s'), findsOneWidget);

    // Tapping the disabled button does not fire another request.
    await tester.tap(find.widgetWithText(RdButton, 'Espera 3s'));
    await tester.pump();
    expect(authRepo.requestCount, 1);

    // The countdown ticks down live...
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(RdButton, 'Espera 2s'), findsOneWidget);

    // ...and once it clears, the submit button is usable again.
    await tester.pump(const Duration(seconds: 3));
    expect(find.widgetWithText(RdButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('disables resend code for five seconds', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(authRepo.requestCount, 1);
    expect(find.text('Reenviar en 5s'), findsOneWidget);

    await tester.tap(find.text('Reenviar en 5s'));
    await tester.pump();

    expect(authRepo.requestCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar en 4s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Reenviar código'), findsOneWidget);

    await tester.tap(find.text('Reenviar código'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(authRepo.requestCount, 2);
    expect(find.text('Reenviar en 5s'), findsOneWidget);
  });

  testWidgets('prompts to enter the verification code when Continue is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository(
      requestMagicLinkResult: const Ok(MagicLinkRequestResult(sent: true)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Introduce el código'), findsOneWidget);

    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();

    expect(find.text('Introduce el código.'), findsOneWidget);
    expect(find.text('Campo requerido.'), findsNothing);
  });

  testWidgets('shows required vs invalid email messages distinctly', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();

    expect(find.text('Campo requerido.'), findsOneWidget);
    expect(find.text('Revisa los datos introducidos.'), findsNothing);
    expect(authRepo.requestCount, 0);

    await tester.enterText(find.byType(TextField), 'notanemail');
    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pump();

    expect(find.text('Introduce un correo válido.'), findsOneWidget);
    expect(find.text('Campo requerido.'), findsNothing);
    expect(find.text('Revisa los datos introducidos.'), findsNothing);
    expect(authRepo.requestCount, 0);
  });

  testWidgets('uses default scaffold bg and labeled RdTextField chrome', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull);

    final field = tester.widget<RdTextField>(find.byType(RdTextField));
    expect(field.decoration.label, isA<RdFormFieldLabel>());
    expect(
      (field.decoration.label! as RdFormFieldLabel).text,
      'Correo electrónico',
    );
    expect((field.decoration.label! as RdFormFieldLabel).required, isTrue);
    expect(find.byType(GoogleSignInButton), findsOneWidget);
  });

  testWidgets(
    'Google sign-in loading does not spin the email Continue button',
    (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final completer = Completer<void>();
      addTearDown(() => GoogleAuth.authenticateForTest = null);
      GoogleAuth.authenticateForTest = () async {
        await completer.future;
        return null;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepoProvider.overrideWithValue(_FakeAuthRepository()),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      final continueButton = tester.widget<RdButton>(
        find.widgetWithText(RdButton, 'Continuar'),
      );
      expect(continueButton.loading, isFalse);
      expect(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.byType(RdProgress),
        ),
        findsOneWidget,
      );

      completer.complete();
      await tester.pump();
    },
  );

  testWidgets('shows Apple sign-in only when the embedder targets iOS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    if (kAppleSignInSupportedPlatform) {
      expect(find.byType(AppleSignInButton), findsOneWidget);
      expect(find.text('Continuar con Apple'), findsOneWidget);
    } else {
      expect(find.byType(AppleSignInButton), findsNothing);
    }
  });

  testWidgets('Apple sign-in pops login with success on iOS', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    AppleAuth.authenticateForTest = () async => const AppleAuthCredential(
      identityToken: 'apple-id-token',
      email: 'marina@privaterelay.appleid.com',
      fullName: 'Marina',
    );
    addTearDown(() => AppleAuth.authenticateForTest = null);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = _FakeAuthRepository();
    bool? loggedIn;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(authRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                loggedIn = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('open-login'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-login'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppleSignInButton).at(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(loggedIn, isTrue);
    expect(find.byType(LoginScreen), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    AppleAuth.authenticateForTest = null;
  });

  testWidgets(
    'verifying a code pops the login route so Home can start the download',
    (tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authRepo = _FakeAuthRepository();
      bool? loggedIn;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepoProvider.overrideWithValue(authRepo),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  loggedIn = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('open-login'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'review@readendar.com');
      await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(authRepo.requestCount, 1);
      await tester.enterText(find.byType(TextField).last, 'ABC234XY');
      await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(authRepo.verifyCount, 1);
      expect(loggedIn, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('close returns to Home without signing in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bool? loggedIn;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepoProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                loggedIn = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('open-login'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-login'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loginClose')));
    await tester.pumpAndSettle();

    expect(loggedIn, isFalse);
    expect(find.byType(LoginScreen), findsNothing);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.requestMagicLinkResult,
  });

  final Result<MagicLinkRequestResult>? requestMagicLinkResult;
  int requestCount = 0;
  int verifyCount = 0;

  @override
  Future<Result<MagicLinkRequestResult>> requestMagicLink({
    required String email,
    required String locale,
  }) async {
    requestCount += 1;
    return requestMagicLinkResult ??
        const Ok(MagicLinkRequestResult(sent: true, devCode: 'ABC234XY'));
  }

  @override
  Future<Result<AuthSession>> verifyMagicLink({
    required String token,
    required String locale,
  }) async {
    verifyCount += 1;
    return Ok(
      AuthSession(
        user: AppUser(
          id: 'review-1',
          email: 'review@readendar.com',
          displayName: 'Marina',
          preferredLocale: 'es',
          timezone: 'Europe/Madrid',
          onboardingCompletedAt: DateTime(2026, 5, 19),
          termsVersion: currentTermsVersion,
        ),
        accessToken: 'access',
        refreshToken: 'refresh',
        isNewUser: false,
      ),
    );
  }

  @override
  Future<Result<AuthSession>> signInGoogle({
    required String idToken,
    required String locale,
  }) async => const Err(UnknownFailure('unused'));

  @override
  Future<Result<AuthSession>> signInApple({
    required String idToken,
    required String locale,
    String? name,
  }) async {
    return Ok(
      AuthSession(
        user: AppUser(
          id: 'apple-1',
          email: 'marina@privaterelay.appleid.com',
          displayName: name ?? 'Marina',
          preferredLocale: 'es',
          timezone: 'Europe/Madrid',
          onboardingCompletedAt: DateTime(2026, 5, 19),
          termsVersion: currentTermsVersion,
        ),
        accessToken: 'access',
        refreshToken: 'refresh',
        isNewUser: false,
      ),
    );
  }

  @override
  Future<Result<void>> logout() async => const Ok(null);
}
