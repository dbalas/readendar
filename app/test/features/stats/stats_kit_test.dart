import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/stats/stats_kit.dart';

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Future<void> _pumpRow(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SectionList(
          children: [
            SectionRow(
              icon: LucideIcons.flame,
              title: 'Actividad',
              preview: const StatPreview('292 pages', StatTone.good),
              onTap: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final entry in [
    ('light', buildLightTheme(), ReadendarColors.light),
    ('dark', buildDarkTheme(), ReadendarColors.dark),
  ]) {
    final label = entry.$1;
    final theme = entry.$2;
    final colors = entry.$3;

    testWidgets('SectionRow chevron stays readable in $label mode', (
      tester,
    ) async {
      await _pumpRow(tester, theme);

      final chevron = tester.widget<Icon>(
        find.byIcon(LucideIcons.chevronRight),
      );
      expect(chevron.color, colors.fg3);
      expect(chevron.color, isNot(theme.colorScheme.outlineVariant));
      // UI icons that convey a control need at least WCAG 3:1 vs the card.
      expect(_contrast(chevron.color!, colors.surface1), greaterThanOrEqualTo(3));
    });
  }
}
