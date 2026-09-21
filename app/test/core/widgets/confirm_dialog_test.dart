import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';

/// Pumps an "open" button that runs [onOpen] when tapped, wired with the app's
/// localization + theme so the confirm helpers can resolve `actionCancel`.
/// [onOpen] is responsible for awaiting the helper and storing its result.
Future<void> _pumpLauncher(
  WidgetTester tester,
  Future<void> Function(BuildContext) onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
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
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the confirm button resolves true', (tester) async {
    bool? captured;
    await _pumpLauncher(tester, (context) async {
      captured = await showConfirmDialog(
        context: context,
        title: 'Delete book',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
    });

    expect(find.text('Delete book'), findsOneWidget);
    // The dismissive button uses the shared `actionCancel` key by default.
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(captured, isTrue);
  });

  testWidgets('tapping cancel resolves false', (tester) async {
    bool? captured;
    await _pumpLauncher(tester, (context) async {
      captured = await showConfirmDialog(
        context: context,
        message: 'Rotate the token?',
        confirmLabel: 'Rotate',
        destructive: true,
      );
    });

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(captured, isFalse);
  });

  testWidgets('destructive confirm button is wine-tinted', (tester) async {
    await _pumpLauncher(tester, (context) async {
      await showConfirmDialog(
        context: context,
        icon: Icons.delete_outline,
        message: 'Delete?',
        confirmLabel: 'Delete',
        destructive: true,
      );
    });

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
    // The destructive action now uses the theme's semantic error color (so it
    // adapts to dark mode) rather than a hard-coded wine token.
    expect(bg, buildLightTheme().colorScheme.error);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.iconColor, buildLightTheme().colorScheme.error);
  });

  testWidgets('typed confirmation stays separated with keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);

    await _pumpLauncher(tester, (context) async {
      await showTypeToConfirmDialog(
        context: context,
        title: 'Delete library',
        message:
            'Type the name to delete this library and permanently remove '
            'your books, notes, and settings.',
        matchText: 'reader_one',
        confirmLabel: 'Delete library',
        icon: Icons.person_off_outlined,
      );
    });

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.scrollable, isTrue);
    expect(tester.takeException(), isNull);

    final input = tester.getRect(find.byType(TextField));
    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancelar'));
    final deactivate = tester.getRect(
      find.widgetWithText(FilledButton, 'Delete library'),
    );
    expect(input.bottom, lessThanOrEqualTo(cancel.top));
    expect(input.bottom, lessThanOrEqualTo(deactivate.top));
  });

  testWidgets('choice dialog returns the tapped action value', (tester) async {
    String? captured;
    await _pumpLauncher(tester, (context) async {
      captured = await showConfirmChoiceDialog<String>(
        context: context,
        title: 'Leave list',
        message: 'What about your books?',
        includeCancel: false,
        actions: [
          const ConfirmAction(
            label: 'Keep',
            value: 'keep',
            style: ConfirmActionStyle.neutral,
          ),
          const ConfirmAction(
            label: 'Delete',
            value: 'delete',
            style: ConfirmActionStyle.destructive,
          ),
        ],
      );
    });

    // No cancel button was requested.
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(captured, 'delete');
  });

  testWidgets('dialog icon is centered and two actions share a row', (
    tester,
  ) async {
    await _pumpLauncher(tester, (context) async {
      await showConfirmChoiceDialog<String>(
        context: context,
        icon: Icons.description_outlined,
        message: 'Save for later?',
        includeCancel: false,
        actions: const [
          ConfirmAction(label: 'Discard', value: 'discard'),
          ConfirmAction(label: 'Save', value: 'save'),
        ],
      );
    });

    expect(
      tester.getCenter(find.byIcon(Icons.description_outlined)).dx,
      tester.getCenter(find.byType(AlertDialog)).dx,
    );
    expect(
      tester.getCenter(find.text('Discard')).dy,
      tester.getCenter(find.text('Save')).dy,
    );
    final discard = tester.getRect(
      find.widgetWithText(FilledButton, 'Discard'),
    );
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect(save.left - discard.right, lessThanOrEqualTo(16));
  });

  testWidgets('two long actions stack when they do not fit on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLauncher(tester, (context) async {
      await showConfirmChoiceDialog<String>(
        context: context,
        icon: Icons.how_to_vote_outlined,
        message: '¿Guardar para más tarde?',
        includeCancel: false,
        actions: const [
          ConfirmAction(
            label: 'Descartar',
            value: 'discard',
            icon: Icons.delete_outline,
          ),
          ConfirmAction(
            label: 'Continuar',
            value: 'continue',
            icon: Icons.arrow_forward,
          ),
        ],
      );
    });

    final discard = tester.getRect(
      find.widgetWithText(FilledButton, 'Descartar'),
    );
    final continueButton = tester.getRect(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(discard.bottom, lessThan(continueButton.top));
    expect(tester.takeException(), isNull);
  });
}
