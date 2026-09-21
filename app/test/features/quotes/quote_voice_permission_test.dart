import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/quotes/voice/quote_voice_permission.dart';

ThemeData _themeFor(TargetPlatform platform) =>
    buildLightTheme().copyWith(platform: platform);

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

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Future<bool> Function(BuildContext) onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      theme: _themeFor(platform),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const title = 'Se necesita acceso al micrófono';
  const body =
      'Readendar necesita acceso al micrófono para dictar citas. '
      'Puedes activarlo en Ajustes.';

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('quote voice permission denied ($platform)', () {
      testWidgets('shows how to enable microphone access after denial', (
        tester,
      ) async {
        await _withPlatform(platform, () async {
          var allowed = true;
          await _pumpLauncher(
            tester,
            platform: platform,
            onOpen: (context) async {
              allowed = await ensureQuoteVoiceAccess(
                context,
                requestMicrophone: () async => PermissionStatus.denied,
                requestSpeech: () async => PermissionStatus.granted,
              );
              return allowed;
            },
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(find.text(title), findsOneWidget);
          expect(find.text(body), findsOneWidget);
          expect(find.text('Abrir ajustes'), findsOneWidget);

          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(allowed, isFalse);
        });
      });

      testWidgets('Open Settings opens device settings when mic is denied', (
        tester,
      ) async {
        await _withPlatform(platform, () async {
          var openedSettings = false;
          await _pumpLauncher(
            tester,
            platform: platform,
            onOpen: (context) async {
              return ensureQuoteVoiceAccess(
                context,
                requestMicrophone: () async =>
                    PermissionStatus.permanentlyDenied,
                requestSpeech: () async => PermissionStatus.granted,
                openSettings: () async {
                  openedSettings = true;
                  return true;
                },
              );
            },
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Abrir ajustes'));
          await tester.pumpAndSettle();

          expect(openedSettings, isTrue);
        });
      });
    });
  }

  testWidgets('iOS speech denial shows the same settings modal', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      var allowed = true;
      await _pumpLauncher(
        tester,
        platform: TargetPlatform.iOS,
        onOpen: (context) async {
          allowed = await ensureQuoteVoiceAccess(
            context,
            requestMicrophone: () async => PermissionStatus.granted,
            requestSpeech: () async => PermissionStatus.denied,
          );
          return allowed;
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(allowed, isFalse);
    });
  });

  testWidgets('granted microphone and speech does not show a modal', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      late bool allowed;
      await _pumpLauncher(
        tester,
        platform: TargetPlatform.iOS,
        onOpen: (context) async {
          allowed = await ensureQuoteVoiceAccess(
            context,
            requestMicrophone: () async => PermissionStatus.granted,
            requestSpeech: () async => PermissionStatus.granted,
          );
          return allowed;
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(allowed, isTrue);
    });
  });
}
