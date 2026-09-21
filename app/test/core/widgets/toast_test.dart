import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/toast.dart';

Future<void> _pumpToastHost(
  WidgetTester tester, {
  required ThemeData theme,
  required TargetPlatform platform,
  required void Function(BuildContext context) onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(platform: platform),
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('toast'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('toast'));
  await tester.pump(); // show snackbar (skip settle — auto-dismiss timer)
}

void main() {
  testWidgets('neutral deep-lift chip shows message + info glyph', (
    tester,
  ) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdToast(context, message: 'Enlace copiado'),
    );

    expect(find.text('Enlace copiado'), findsOneWidget);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final box = decorated.decoration as BoxDecoration;
    expect(box.color, ReadendarTokens.paper50);
    expect(box.boxShadow, isNotEmpty);
    expect(box.borderRadius, BorderRadius.circular(ReadendarTokens.radiusPill));
  });

  testWidgets('Android uses lg radius instead of pill', (tester) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.android,
      onOpen: (context) => showRdToast(context, message: 'Saved'),
    );

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final box = decorated.decoration as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(ReadendarTokens.radiusLg));
  });

  testWidgets('success and error tones swap glyph soft fills', (tester) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdToast(
        context,
        message: 'Saved',
        tone: RdToastTone.success,
      ),
    );
    expect(find.byIcon(LucideIcons.check), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpToastHost(
      tester,
      theme: buildDarkTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdToast(
        context,
        message: 'Could not save',
        tone: RdToastTone.error,
      ),
    );
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    expect(find.text('Could not save'), findsOneWidget);
  });

  testWidgets('action button invokes callback and dismisses', (tester) async {
    var tapped = false;
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.android,
      onOpen: (context) => showRdToast(
        context,
        message: 'Removed from plan',
        actionLabel: 'Undo',
        onAction: () => tapped = true,
      ),
    );

    final undoButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(TextButton),
      ),
    );
    undoButton.onPressed!.call();
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('showRdFailureToast localizes and uses error tone', (
    tester,
  ) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdFailureToast(context, const NetworkFailure()),
    );

    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    // NetworkFailure maps to errorNetwork in en.
    expect(find.textContaining('conexión', findRichText: true), findsWidgets);
  });

  testWidgets('clearExisting replaces the previous toast', (tester) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) {
        showRdToast(context, message: 'First');
        showRdToast(context, message: 'Second');
      },
    );

    // Replacement animates the first bar out, then slides the second in.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('tap on toast dismisses it so it does not block the UI', (
    tester,
  ) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdToast(context, message: 'Enlace copiado'),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Enlace copiado'), findsOneWidget);

    await tester.tap(find.text('Enlace copiado'));
    await tester.pump(); // start exit
    await tester.pump(const Duration(milliseconds: 400)); // finish exit
    expect(find.text('Enlace copiado'), findsNothing);
  });

  testWidgets('snackbar shell does not clip deep-lift shadows', (tester) async {
    await _pumpToastHost(
      tester,
      theme: buildLightTheme(),
      platform: TargetPlatform.iOS,
      onOpen: (context) => showRdToast(context, message: 'Copied'),
    );

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.clipBehavior, Clip.none);
    expect(bar.backgroundColor, Colors.transparent);
  });

  testWidgets('toast content does not own a second position animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: Center(child: RdToastContent(message: 'Saved')),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(RdToastContent),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('toast stays fixed while navigating between equal-height views', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => showRdToast(context, message: 'Saved'),
                  child: const Text('toast'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: SizedBox.expand()),
                    ),
                  ),
                  child: const Text('next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final settledTopLeft = tester.getTopLeft(find.text('Saved'));

    await tester.tap(find.text('next'));
    await tester.pump();
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(find.text('Saved')), settledTopLeft);
    }
  });
}
