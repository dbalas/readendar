import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _book({int? chapterCount, int? pageCount, String status = 'reading'}) =>
    Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Herbert'],
      status: status,
      pageCount: pageCount,
      chapterCount: chapterCount,
    );

AppUser _user() => AppUser(
  id: 'user-1',
  email: 'a@b.co',
  displayName: 'Ada',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester,
  Book book, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: PlanScreen(book: book),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _wizardContinue(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

Future<void> _toAgendaStep(WidgetTester tester) async {
  await _wizardContinue(tester);
}

Future<void> _toOptionsStep(WidgetTester tester) async {
  await _toAgendaStep(tester);
  await _wizardContinue(tester);
}

/// Reach the options step and Continue → calculates Events preview.
Future<void> _calculate(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    if (find.byType(MonthGrid).evaluate().isNotEmpty) return;
    final continueBtn = find.text('Continuar');
    if (continueBtn.evaluate().isEmpty) break;
    await tester.tap(continueBtn);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }
}

Future<void> _backToForm(WidgetTester tester) async {
  await tester.tap(find.text('Atrás'));
  await tester.pumpAndSettle();
}

// The preview defaults to the calendar; switch it to the list to see event rows.
Future<void> _toListView(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Lista'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preview waits until the user calculates', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('Ajustar'), findsNothing);
    expect(find.text('Eventos'), findsNothing);

    await _calculate(tester);
    expect(find.byType(MonthGrid), findsOneWidget);
    await _toListView(tester);
    expect(find.byType(EventCardCompact), findsWidgets);
  });

  testWidgets('calculating opens the events preview on the calendar', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    expect(find.byType(MonthGrid), findsNothing);
    await _calculate(tester);
    expect(find.byType(MonthGrid), findsOneWidget);
  });

  testWidgets('calculating without a total surfaces the needs-fields helper', (
    tester,
  ) async {
    await _pump(tester, _book());
    await _toOptionsStep(tester);
    expect(
      find.text('Completa los campos obligatorios para calcular.'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byType(MonthGrid), findsNothing);
  });

  testWidgets('opening the planner focuses no field', (tester) async {
    await _pump(tester, _book());
    final primary = FocusManager.instance.primaryFocus;
    expect(
      primary?.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNull,
    );
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('preview calendar overlays milestone numbers on covers', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);

    // Default pace for 12 chapters from 0 → milestones at 2, 4, 6, 8, 10, 12…
    expect(find.text('2'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    final grid = tester.widget<MonthGrid>(find.byType(MonthGrid));
    expect(grid.showMilestoneTargets, isTrue);
  });

  testWidgets('preview puts milestones before same-day bookends', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);

    final milestoneDay = tester
        .widgetList<CalendarDayCell>(find.byType(CalendarDayCell))
        .singleWhere(
          (cell) =>
              cell.events.any((event) => event.type == 'start') &&
              cell.events.any(
                (event) => event.type == 'chapter_milestone',
              ),
        );
    expect(milestoneDay.events.first.type, 'chapter_milestone');

    await _toListView(tester);
    final milestoneRow = find.widgetWithText(EventCardCompact, 'Capítulo 2');
    final startRow = find.widgetWithText(EventCardCompact, 'Empezar la lectura');
    expect(milestoneRow, findsOneWidget);
    expect(startRow, findsOneWidget);
    expect(
      tester.getTopLeft(milestoneRow).dy,
      lessThan(tester.getTopLeft(startRow).dy),
    );
  });

  testWidgets(
    'preview puts list toggle in the app bar and hides the pace summary',
    (
      tester,
    ) async {
      await _pump(tester, _book(chapterCount: 12));
      await _calculate(tester);

      expect(find.byTooltip('Lista'), findsOneWidget);
      expect(find.text('Lista'), findsNothing);
      expect(
        find.text('Toca un día para excluirlo o restaurarlo.'),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.mousePointerClick), findsOneWidget);
      // Old summary row was e.g. "2 ch/day · Jul 7 – Jul 13".
      expect(find.textContaining('ch/day ·'), findsNothing);
    },
  );

  testWidgets('create button stays short without the event count', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Create 7 events'), findsNothing);
    expect(find.text('Events (7)'), findsNothing);
  });

  testWidgets('create appears only after calculate', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toOptionsStep(tester);

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Crear'), findsNothing);
    expect(find.byType(MonthGrid), findsNothing);

    await _calculate(tester);
    expect(find.text('Crear'), findsOneWidget);
  });

  testWidgets('mid-wizard cannot jump to events without calculating', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toAgendaStep(tester);
    expect(find.text('Ver eventos'), findsNothing);
    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('recalculate from scratch clears day exclusions', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    await _toListView(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

    await _backToForm(tester);
    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    if (find.byTooltip('Lista').evaluate().isNotEmpty) {
      await _toListView(tester);
    }
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
  });

  testWidgets('agenda totals sit in a compact side-by-side row', (
    tester,
  ) async {
    await _pump(tester, _book(pageCount: 300));
    await _toAgendaStep(tester);

    final total = find.widgetWithText(TextField, 'Total de páginas *');
    final read = find.widgetWithText(TextField, 'Páginas leídas');
    expect(total, findsOneWidget);
    expect(read, findsOneWidget);
    expect(
      tester.getTopLeft(total).dy,
      moreOrLessEquals(tester.getTopLeft(read).dy, epsilon: 1),
    );
    expect(tester.getTopLeft(read).dx, lessThan(tester.getTopLeft(total).dx));
    expect(find.text('0 = desde el principio'), findsNothing);
    expect(find.text('FECHAS Y RITMO'), findsOneWidget);
  });

  testWidgets('pace start and rhythm stack vertically', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toAgendaStep(tester);

    final start = find.text('Inicio *');
    final pace = find.widgetWithText(TextField, 'Ritmo *');
    expect(start, findsOneWidget);
    expect(pace, findsOneWidget);
    expect(tester.getTopLeft(start).dy, lessThan(tester.getTopLeft(pace).dy));
  });

  testWidgets('book section comes before dates & pace', (tester) async {
    await _pump(tester, _book(pageCount: 300, chapterCount: 12));
    await _toAgendaStep(tester);

    final book = find.text('LIBRO');
    final schedule = find.text('FECHAS Y RITMO');
    expect(book, findsOneWidget);
    expect(schedule, findsOneWidget);
    expect(
      tester.getTopLeft(book).dy,
      lessThan(tester.getTopLeft(schedule).dy),
    );
  });

  testWidgets('footer buttons share equal width', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    final cancel = tester.getSize(
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    );
    final cont = tester.getSize(find.widgetWithText(FilledButton, 'Continuar'));
    expect(cancel.width, moreOrLessEquals(cont.width, epsilon: 2));
  });

  testWidgets('saved plan unit preference seeds the next plan', (tester) async {
    SharedPreferences.setMockInitialValues({'plan_unit:user-1': 'chapters'});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await _pump(
      tester,
      _book(pageCount: 300, chapterCount: 12),
      overrides: [
        prefsStorageProvider.overrideWithValue(prefs),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        sessionProvider.overrideWith((ref) {
          final n = SessionNotifier(ref);
          n.setUser(_user());
          return n;
        }),
      ],
    );
    await _toAgendaStep(tester);

    expect(find.widgetWithText(TextField, 'Total de capítulos *'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Total de páginas *'), findsNothing);
  });

  testWidgets('choosing a unit persists preference for the user', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await _pump(
      tester,
      _book(pageCount: 300, chapterCount: 12),
      overrides: [
        prefsStorageProvider.overrideWithValue(prefs),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        sessionProvider.overrideWith((ref) {
          final n = SessionNotifier(ref);
          n.setUser(_user());
          return n;
        }),
      ],
    );
    await _toAgendaStep(tester);

    expect(find.widgetWithText(TextField, 'Total de páginas *'), findsOneWidget);
    await tester.tap(find.text('Capítulos'));
    await tester.pumpAndSettle();
    expect(prefs.getPlanUnit('user-1'), 'chapters');
    expect(find.widgetWithText(TextField, 'Total de capítulos *'), findsOneWidget);
  });

  testWidgets('saved planning mode seeds the next plan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    await prefs.setPlanMode('user-1', 'deadline');

    await _pump(
      tester,
      _book(pageCount: 300),
      overrides: [
        prefsStorageProvider.overrideWithValue(prefs),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        sessionProvider.overrideWith((ref) {
          final n = SessionNotifier(ref);
          n.setUser(_user());
          return n;
        }),
      ],
    );

    await _toAgendaStep(tester);
    expect(find.text('Fecha fin *'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Ritmo *'), findsNothing);
  });

  testWidgets('choosing a planning mode persists preference for the user', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await _pump(
      tester,
      _book(pageCount: 300),
      overrides: [
        prefsStorageProvider.overrideWithValue(prefs),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        sessionProvider.overrideWith((ref) {
          final n = SessionNotifier(ref);
          n.setUser(_user());
          return n;
        }),
      ],
    );

    expect(prefs.getPlanMode('user-1'), isNull);
    await tester.tap(find.text('Meta diaria'));
    await tester.pumpAndSettle();
    expect(prefs.getPlanMode('user-1'), 'pace');

    await tester.tap(find.text('Antes de un evento'));
    await tester.pumpAndSettle();

    expect(prefs.getPlanMode('user-1'), 'before_event');
  });

  testWidgets('pageCount defaults the wizard to pages', (tester) async {
    await _pump(tester, _book(pageCount: 300));
    await _toAgendaStep(tester);
    expect(find.widgetWithText(TextField, 'Total de páginas *'), findsOneWidget);
  });

  testWidgets('goal step offers before-an-event mode', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    expect(find.text('Antes de un evento'), findsOneWidget);
    await tester.tap(find.text('Antes de un evento'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Calcular eventos'), findsNothing);

    await _toAgendaStep(tester);
    expect(find.text('Elegir del calendario'), findsOneWidget);
    expect(find.text('Terminar para el evento *'), findsOneWidget);
  });

  testWidgets('goal step stays progressive when switching mode', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await tester.tap(find.text('Terminar en una fecha'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Calcular eventos'), findsNothing);
    expect(
      find.text('Has cambiado el borrador. Recalcula para actualizar los eventos.'),
      findsNothing,
    );
  });

  testWidgets('the form shows the derived finish date in pace mode', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toOptionsStep(tester);
    expect(find.textContaining('días de lectura'), findsOneWidget);
  });

  testWidgets('the form shows the derived pace in deadline mode', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await tester.tap(find.text('Terminar en una fecha'));
    await tester.pumpAndSettle();
    await _toOptionsStep(tester);
    expect(find.textContaining('Ritmo necesario'), findsOneWidget);
  });

  testWidgets('a demanding pace surfaces a soft warning in the form', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toAgendaStep(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Ritmo *'), '300');
    await tester.pumpAndSettle();
    expect(find.text("Es un ritmo exigente."), findsOneWidget);
  });

  testWidgets(
    'nothing-to-read shows its specific message, not the generic hint',
    (tester) async {
      await _pump(tester, _book(chapterCount: 12));
      await _toAgendaStep(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Capítulos leídos'),
        '999',
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Ya has alcanzado el total: no queda nada por planificar."),
        findsOneWidget,
      );
      expect(
        find.text('Completa los campos obligatorios para calcular.'),
        findsNothing,
      );
      expect(find.byType(MonthGrid), findsNothing);
    },
  );

  testWidgets('a past start date warns but still allows calculating', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _toAgendaStep(tester);
    await tester.tap(find.byIcon(LucideIcons.calendar));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      DateFormat.yMd('es').format(yesterday),
    );
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    expect(find.text('La fecha de inicio es anterior a hoy.'), findsOneWidget);
    await _calculate(tester);
    expect(find.byType(MonthGrid), findsOneWidget);
  });

  testWidgets('unchecking a list event keeps it (disabled) and recomputes', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    await _toListView(tester);
    final before = tester.widgetList(find.byType(EventCardCompact)).length;
    expect(before, greaterThan(0));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.byType(EventCardCompact), findsWidgets);
    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes.any((c) => c.value == false), isTrue);
  });

  testWidgets('advice stays hidden until the draft can estimate', (
    tester,
  ) async {
    await _pump(tester, _book());
    expect(
      find.text('Completa los campos para ver tu estimación.'),
      findsNothing,
    );
    expect(
      find.text('Completa los campos obligatorios para calcular.'),
      findsNothing,
    );
  });

  testWidgets(
    'options step lists bookends and reminders under Events & alerts',
    (
      tester,
    ) async {
      await _pump(tester, _book(chapterCount: 12));
      await _toOptionsStep(tester);
      expect(find.text('EVENTOS Y AVISOS'), findsOneWidget);
      expect(find.text('Añadir evento de inicio'), findsOneWidget);
      expect(find.text('Recordatorios'), findsOneWidget);
      expect(
        find.text('Usa la hora de recordatorio predeterminada de Ajustes.'),
        findsOneWidget,
      );

      final finish = find.text('Añadir evento de fin');
      final reminders = find.text('Recordatorios');
      expect(finish, findsOneWidget);
      expect(
        tester.getTopLeft(finish).dy,
        lessThan(tester.getTopLeft(reminders).dy),
      );
    },
  );

  testWidgets('excluding a day surfaces an icon-only reset in the preview', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    await _toListView(tester);
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
    expect(find.text('Restablecer'), findsNothing);
  });

  testWidgets('paging the calendar month advances the grid', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    final initialMonth = DateFormat.yMMMM('es').format(DateTime.now());
    expect(find.byType(MonthGrid), findsOneWidget);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text(initialMonth), findsNothing);
  });

  testWidgets('dirty draft blocks Create until recalculate', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    expect(find.text('Crear'), findsOneWidget);

    await _backToForm(tester);
    // Preview back lands on options — go back to agenda for Pace.
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Ritmo *'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ritmo *'), '1');
    await tester.pumpAndSettle();

    // Mid-wizard stays progressive — no stale-draft banner.
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Recalcular para aplicar'), findsNothing);
    expect(
      find.text('Has cambiado el borrador. Recalcula para actualizar los eventos.'),
      findsNothing,
    );

    await _wizardContinue(tester);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Crear'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Recalcular para aplicar'), findsNothing);
  });

  testWidgets('mid-wizard dirty edits keep Continue, not Recalculate', (
    tester,
  ) async {
    await _pump(tester, _book(chapterCount: 12));
    await _calculate(tester);
    await _backToForm(tester);
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ritmo *'), '1');
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Recalcular para aplicar'), findsNothing);
  });

  testWidgets('goal step shows Cancel beside Continue', (tester) async {
    await _pump(tester, _book(chapterCount: 12));
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Atrás'), findsNothing);
  });
}
