import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/section_header.dart';

void main() {
  testWidgets('renders the shared cut rule below the section title', (
    tester,
  ) async {
    const accent = Color(0xFF7457D9);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            'Synopsis',
            color: accent,
            padding: EdgeInsets.zero,
            action: Icon(Icons.more_horiz),
          ),
        ),
      ),
    );

    expect(find.text('SYNOPSIS'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    final rule = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byKey(const Key('sectionHeaderCutRule')),
            matching: find.byType(SizedBox),
          ),
        )
        .singleWhere((box) => box.width == 38 && box.height == 2);
    expect(rule.width, 38);
    expect(rule.height, 2);
    expect(find.byKey(const Key('sectionHeaderRuleLead')), findsOneWidget);
    expect(find.byKey(const Key('sectionHeaderRuleTail')), findsOneWidget);

    final lead = tester.widget<DecoratedBox>(
      find.byKey(const Key('sectionHeaderRuleLead')),
    );
    final tail = tester.widget<DecoratedBox>(
      find.byKey(const Key('sectionHeaderRuleTail')),
    );
    expect((lead.decoration as BoxDecoration).color, accent);
    expect(
      (tail.decoration as BoxDecoration).color,
      accent.withValues(alpha: 0.42),
    );
  });

  testWidgets('editorial title uses the shared headline and cut rule', (
    tester,
  ) async {
    const foreground = Color(0xFFF8F5EE);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: ReadendarTextStyles.build(
            fg: Colors.black,
            fg2: Colors.black54,
          ),
        ),
        home: const Scaffold(
          body: EditorialTitle(
            'Welcome back',
            color: foreground,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Welcome back'));
    expect(title.style?.fontFamily, ReadendarTokens.fontDisplay);
    expect(title.style?.fontSize, 26);
    expect(title.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('hides the count pill when count is missing or zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SectionHeader('Reading', count: 0),
              SectionHeader('Pending'),
              SectionHeader('Read', count: 142),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sectionHeaderCount')), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.bySemanticsLabel('READ, 142'), findsOneWidget);
  });

  testWidgets('section count pill uses optically centered padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader('Reading', count: 7, padding: EdgeInsets.zero),
        ),
      ),
    );

    final pill = tester.widget<Container>(
      find.byKey(const Key('sectionHeaderCount')),
    );
    expect(
      pill.padding,
      const EdgeInsets.fromLTRB(7, 2, 7, 1),
    );

    final text = tester.widget<Text>(find.text('7'));
    expect(text.style?.height, 1);
  });

  testWidgets('collapsible section header toggles via tap and shows chevron', (
    tester,
  ) async {
    var expanded = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SectionHeader(
              'Reading',
              count: 3,
              expanded: expanded,
              onToggle: () => setState(() => expanded = !expanded),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sectionHeaderChevronUp')), findsOneWidget);
    await tester.tap(find.text('READING'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sectionHeaderChevronDown')), findsOneWidget);
  });
}
