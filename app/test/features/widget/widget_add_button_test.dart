import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_add_button.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const homeWidgetChannel = MethodChannel('home_widget');
  const pinChannel = MethodChannel('readendar/widget_pin');
  const secretsChannel = MethodChannel('readendar/widget_secrets');
  var pinCalls = 0;

  setUp(() {
    pinCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async {
          switch (call.method) {
            case 'setAppGroupId':
              return true;
            case 'getWidgetData':
              return null;
            case 'getInstalledWidgets':
              return <Object>[];
            default:
              return true;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pinChannel, (call) async {
          if (call.method == 'requestPinWidget') pinCalls++;
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secretsChannel, (call) async {
          if (call.method == 'read') {
            return <String, String?>{'access': null, 'refresh': null};
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(pinChannel, null)
      ..setMockMethodCallHandler(secretsChannel, null);
  });

  testWidgets('signed-out add shows the generic error and does not pin', (
    tester,
  ) async {
    await _pumpAddButton(tester, session: _LoggedOutSession.new);

    await tester.tap(find.byType(WidgetAddButton));
    await tester.pumpAndSettle();

    expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsOneWidget);
    expect(pinCalls, 0);
  });

  testWidgets(
    'Android pins from local preview without a widget session',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpAddButton(
          tester,
          session: _LoggedInSession.new,
          platform: TargetPlatform.android,
        );

        await tester.tap(find.byType(WidgetAddButton));
        // Pin poll uses a periodic Timer; pumpAndSettle would wait forever.
        await tester.pump();
        await tester.pump();

        expect(pinCalls, 1);
        expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'iOS signed-in add opens the how-to sheet instead of the generic error',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pumpAddButton(
          tester,
          session: _LoggedInSession.new,
          platform: TargetPlatform.iOS,
        );

        await tester.tap(find.byType(WidgetAddButton));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Añade el widget de Readendar'), findsOneWidget);
        expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsNothing);
        expect(pinCalls, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

Future<void> _pumpAddButton(
  WidgetTester tester, {
  required SessionNotifier Function(Ref) session,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dir = Directory.systemTemp.createTempSync('wdg-add');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final local = LocalStore.memory(Directory('${dir.path}/covers')..createSync());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(local),
        sessionProvider.overrideWith(session),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme().copyWith(platform: platform),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: WidgetAddButton(
            kind: WidgetKind.progress,
            child: SizedBox(width: 200, height: 120),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _LoggedOutSession extends SessionNotifier {
  _LoggedOutSession(super.ref);
}

class _LoggedInSession extends SessionNotifier {
  _LoggedInSession(super.ref) {
    state = SessionState(
      user: AppUser(
        id: 'u1',
        email: 'reader@example.com',
        displayName: 'Reader',
        preferredLocale: 'es',
        timezone: 'UTC',
        onboardingCompletedAt: DateTime.utc(2026),
      ),
    );
  }
}
