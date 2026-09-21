import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/platform_chrome_theme.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/compact_empty_card.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/gradient_button.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';

ThemeData _iosTheme() => withCupertinoSplashSuppressed(
  buildLightTheme().copyWith(platform: TargetPlatform.iOS),
);

ThemeData _androidTheme() => withCupertinoSplashSuppressed(
  buildLightTheme().copyWith(platform: TargetPlatform.android),
);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _app({required ThemeData theme, required Widget home}) => MaterialApp(
  locale: const Locale('es'),
  theme: theme,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: home,
);

void main() {
  test('iOS theme applies pill shapes to Material button themes', () {
    final ios = _iosTheme();
    final android = _androidTheme();

    expect(ios.splashFactory, NoSplash.splashFactory);
    expect(android.splashFactory, isNot(NoSplash.splashFactory));

    final iosShape = ios.filledButtonTheme.style?.shape?.resolve({});
    expect(iosShape, isA<RoundedRectangleBorder>());
    final iosRadius =
        (iosShape! as RoundedRectangleBorder).borderRadius as BorderRadius;
    expect(iosRadius.topLeft.x, ReadendarTokens.radiusPill);

    final androidShape = android.filledButtonTheme.style?.shape?.resolve({});
    // Android keeps light_theme shapes (not overwritten by cupertino chrome).
    if (androidShape is RoundedRectangleBorder) {
      final r = androidShape.borderRadius as BorderRadius;
      expect(r.topLeft.x, isNot(ReadendarTokens.radiusPill));
    }
  });

  testWidgets('RdButton is Cupertino filled on iOS', (tester) async {
    await _withIosPlatform(() async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdButton.primary(
              label: 'Save',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await tester.tap(find.text('Save'));
      expect(tapped, isTrue);
    });
  });

  testWidgets('RdButton is FilledButton on Android', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: RdButton.primary(
            label: 'Save',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(CupertinoButton), findsNothing);
    await tester.tap(find.text('Save'));
    expect(tapped, isTrue);
  });

  testWidgets('RdButton.secondary is outlined on Android', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: const Scaffold(
          body: RdButton.secondary(label: 'Retry', onPressed: null),
        ),
      ),
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('RdButton shows progress when loading', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: RdButton.primary(
            label: 'Saving',
            loading: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.byType(RdProgress), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('ErrorRetry uses RdButton', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: ErrorRetry(error: Exception('boom'), onRetry: () {}),
        ),
      ),
    );
    expect(find.byType(RdButton), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('FormSaveAction uses RdButton.plain', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                FormSaveAction(onPressed: () {}, tooltip: 'Save'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(RdButton), findsOneWidget);
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byIcon(LucideIcons.save), findsOneWidget);
    });
  });

  testWidgets('FormSaveAction disables when onPressed is null', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              FormSaveAction(onPressed: null, tooltip: 'Save'),
            ],
          ),
        ),
      ),
    );
    final button = tester.widget<RdButton>(find.byType(RdButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('CompactEmptyCard CTA is RdButton', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: CompactEmptyCard(
            message: 'Nothing here',
            illustration: const SizedBox(width: 44, height: 44),
            actionLabel: 'Add',
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.byType(RdButton), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('GradientButton is pill on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: GradientButton(label: 'Spin', onPressed: () {}),
          ),
        ),
      );
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GradientButton),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(
        (decoration.borderRadius! as BorderRadius).topLeft.x,
        ReadendarTokens.radiusPill,
      );
    });
  });

  testWidgets('GradientButton keeps Material radius on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: GradientButton(label: 'Spin', onPressed: () {}),
        ),
      ),
    );
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(GradientButton),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      ReadendarTokens.radiusSm,
    );
  });
}
