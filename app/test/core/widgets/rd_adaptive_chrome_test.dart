import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/count_badge.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_dropdown_field.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/core/widgets/rd_nav_sheet.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_root_nav_bar.dart';
import 'package:readendar/core/widgets/rd_section_tabs.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/core/widgets/rd_slider.dart';

void _noopInt(int _) {}
void _noopString(String _) {}
void _noopBool(bool? _) {}

ThemeData _iosTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: buildLightTheme().colorScheme,
  platform: TargetPlatform.iOS,
  cupertinoOverrideTheme: buildLightTheme().cupertinoOverrideTheme,
);

ThemeData _androidTheme() => buildLightTheme().copyWith(
  platform: TargetPlatform.android,
);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _app({
  required ThemeData theme,
  required Widget home,
}) => MaterialApp(
  locale: const Locale('es'),
  theme: theme,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: home,
);

void main() {
  testWidgets('RdRootNavBar is floating glass pill on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            extendBody: true,
            bottomNavigationBar: RdRootNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                RdNavDestination(icon: Icon(LucideIcons.home), label: 'Home'),
                RdNavDestination(icon: Icon(LucideIcons.book), label: 'Lib'),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(RdRootNavBar.iosBarKey), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      final bar = tester.widget<SizedBox>(
        find.descendant(
          of: find.byKey(RdRootNavBar.iosBarKey),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == RdRootNavBarMetrics.barHeight,
          ),
        ),
      );
      expect(bar.height, RdRootNavBarMetrics.barHeight);

      final iconLabelGaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byKey(RdRootNavBar.iosBarKey),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.height == 5 && w.child == null,
              ),
            ),
          )
          .toList();
      expect(iconLabelGaps, hasLength(2));
    });
  });

  testWidgets(
    'RdRootNavBar is floating glass with full-item stadium on Android',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: _androidTheme(),
          home: Scaffold(
            extendBody: true,
            bottomNavigationBar: RdRootNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                RdNavDestination(icon: Icon(LucideIcons.home), label: 'Home'),
                RdNavDestination(icon: Icon(LucideIcons.book), label: 'Lib'),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(RdRootNavBar.androidBarKey), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(RdRootNavBar.iosBarKey), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(RdGlassPanel), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      final panel = tester.widget<RdGlassPanel>(find.byType(RdGlassPanel));
      expect(panel.borderRadius, RdGlassPanel.pillRadius);
      expect(panel.boxShadow, isNotNull);

      // Selected/hover fill uses StadiumBorder covering icon + label.
      final selectedShell = tester
          .widgetList<Material>(find.byType(Material))
          .where(
            (m) => m.shape is StadiumBorder && m.color != Colors.transparent,
          );
      expect(selectedShell, isNotEmpty);

      final bar = tester.widget<SizedBox>(
        find.descendant(
          of: find.byKey(RdRootNavBar.androidBarKey),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == RdRootNavBar.materialBarHeight,
          ),
        ),
      );
      expect(bar.height, RdRootNavBar.materialBarHeight);

      final iconLabelGaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byKey(RdRootNavBar.androidBarKey),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.height == 3 && w.child == null,
              ),
            ),
          )
          .toList();
      expect(iconLabelGaps, hasLength(2));
    },
  );

  testWidgets('RdSectionTabs is unified pill track on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            appBar: AppBar(
              bottom: RdSectionTabs(
                index: 0,
                onChanged: (_) {},
                tabs: const [
                  RdSectionTab(label: 'Form'),
                  RdSectionTab(label: 'Preview'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(RdSectionTabs.trackKey), findsOneWidget);
      expect(find.byKey(RdSectionTabs.activePillKey), findsOneWidget);
      expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    });
  });

  testWidgets('RdSectionTabs is unified pill track on Android', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          appBar: AppBar(
            bottom: RdSectionTabs(
              index: 0,
              onChanged: (_) {},
              tabs: const [
                RdSectionTab(label: 'Form'),
                RdSectionTab(label: 'Preview'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(RdSectionTabs.trackKey), findsOneWidget);
    expect(find.byKey(RdSectionTabs.activePillKey), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('RdSectionTabs active pill uses solid accent without border', (
    tester,
  ) async {
    Future<void> expectSolidAccentPill({
      required Brightness brightness,
      required Color accent,
      required Color onAccent,
    }) async {
      final themed = brightness == Brightness.dark
          ? buildDarkTheme().copyWith(platform: TargetPlatform.android)
          : _androidTheme();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            platform: TargetPlatform.android,
          ),
          darkTheme: themed,
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Theme(
            // Force the slot we care about — ThemeMode alone is enough for
            // dark, but light must use [_androidTheme] (not ThemeData.light).
            data: themed,
            child: Scaffold(
              appBar: AppBar(
                bottom: RdSectionTabs(
                  index: 0,
                  onChanged: (_) {},
                  tabs: const [
                    RdSectionTab(label: 'Form'),
                    RdSectionTab(label: 'Preview'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final pill = tester.widget<DecoratedBox>(
        find.byKey(RdSectionTabs.activePillKey),
      );
      final decoration = pill.decoration as BoxDecoration;
      expect(decoration.color, accent);
      expect(decoration.color!.a, 1.0);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
      final activeLabel = tester.widget<Text>(find.text('Form'));
      expect(activeLabel.style?.color, onAccent);
    }

    await expectSolidAccentPill(
      brightness: Brightness.light,
      accent: ReadendarColors.light.accent,
      onAccent: ReadendarColors.light.fgOnAccent,
    );
    await expectSolidAccentPill(
      brightness: Brightness.dark,
      accent: ReadendarColors.dark.accent,
      onAccent: ReadendarColors.dark.fgOnAccent,
    );
  });

  testWidgets('RdSectionTabs tap moves active pill', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              bottom: RdSectionTabs(
                index: index,
                onChanged: (i) => setState(() => index = i),
                tabs: const [
                  RdSectionTab(label: 'Form'),
                  RdSectionTab(label: 'Preview'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(index, 1);
  });

  test('RdSectionTabs preferredSize matches section tab height', () {
    const tabs = RdSectionTabs(
      index: 0,
      onChanged: _noopInt,
      tabs: [
        RdSectionTab(label: 'A'),
        RdSectionTab(label: 'B'),
      ],
    );
    expect(tabs.preferredSize.height, kRdSectionTabBarHeight);
  });

  testWidgets('RdSectionTab count badge renders beside the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          appBar: AppBar(
            bottom: RdSectionTabs(
              index: 0,
              onChanged: (_) {},
              tabs: const [
                RdSectionTab(label: 'Detalle'),
                RdSectionTab(label: 'Eventos', count: 3),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(CountBadge), findsOneWidget);
  });

  testWidgets('RdSegmentedControl is Cupertino on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdSegmentedControl<String>(
              selected: 'a',
              onChanged: (_) {},
              segments: const [
                RdSegment(value: 'a', label: 'A'),
                RdSegment(value: 'b', label: 'B'),
              ],
            ),
          ),
        ),
      );
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<String>), findsNothing);
    });
  });

  testWidgets('RdSegmentedControl uses tonal pill chrome on Android', (
    tester,
  ) async {
    var selected = 'a';
    await tester.pumpWidget(
      _app(
        theme: buildLightTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: RdSegmentedControl<String>(
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
              segments: const [
                RdSegment(value: 'a', label: 'Reading', icon: Icons.book),
                RdSegment(value: 'b', label: 'Wanted', icon: Icons.bookmark),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.byKey(RdSegmentedControl.trackKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(RdSegmentedControl.trackKey)).height,
      44,
    );
    expect(find.byKey(const ValueKey('rd-segmented-active-a')), findsOneWidget);
    final active = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('rd-segmented-active-a')),
    );
    expect(
      (active.decoration! as BoxDecoration).color,
      ReadendarColors.light.accent,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.book)).color,
      ReadendarColors.light.fgOnAccent,
    );
    expect(find.byType(InkWell), findsNWidgets(2));

    await tester.tap(find.text('Wanted'));
    await tester.pumpAndSettle();

    expect(selected, 'b');
    expect(find.byKey(const ValueKey('rd-segmented-active-b')), findsOneWidget);
  });

  testWidgets(
    'RdSegmentedControl keeps three icon segments inside tight width',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: RdSegmentedControl<String>(
                selected: 'bug',
                onChanged: _noopString,
                segments: [
                  RdSegment(value: 'bug', label: 'Bug', icon: Icons.bug_report),
                  RdSegment(
                    value: 'idea',
                    label: 'Idea',
                    icon: Icons.lightbulb,
                  ),
                  RdSegment(
                    value: 'other',
                    label: 'Other',
                    icon: Icons.message,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(RdSegmentedControl.trackKey)).right,
        lessThanOrEqualTo(304),
      );
    },
  );

  testWidgets('RdOverflowMenu opens glass modal sheet on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      String? picked;
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                RdOverflowMenu<String>(
                  items: const [
                    RdMenuItem(value: 'edit', label: 'Edit'),
                    RdMenuItem(
                      value: 'delete',
                      label: 'Delete',
                      destructive: true,
                    ),
                  ],
                  onSelected: (v) => picked = v,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.byType(RdGlassPanel), findsWidgets);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(picked, 'edit');
    });
  });

  testWidgets(
    'long iOS menu title stays below the status bar',
    (tester) async {
      await _withIosPlatform(() async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            theme: _iosTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRdMenu<int>(
                    context: context,
                    title: 'Quote of the day time',
                    items: [
                      for (var h = 0; h < 24; h++)
                        RdMenuItem(
                          value: h,
                          label: '${h.toString().padLeft(2, '0')}:00',
                        ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final header = find.text('Quote of the day time');
        expect(header, findsOneWidget);
        expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(59));
        expect(find.text('Cancel'), findsNothing);
      });
    },
  );

  testWidgets(
    'RdOverflowMenu glass sheet host has no themed outline on iOS',
    (tester) async {
      await _withIosPlatform(() async {
        await tester.pumpWidget(
          _app(
            theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  RdOverflowMenu<String>(
                    items: const [
                      RdMenuItem(
                        value: 'unmute',
                        label: 'Unmute',
                        icon: LucideIcons.volume2,
                      ),
                      RdMenuItem(
                        value: 'block',
                        label: 'Block',
                        icon: LucideIcons.userRoundX,
                        destructive: true,
                      ),
                    ],
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        final themed =
            Theme.of(
                  tester.element(find.byType(BottomSheet)),
                ).bottomSheetTheme.shape!
                as RoundedRectangleBorder;
        expect(themed.side.style, isNot(BorderStyle.none));

        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(sheet.backgroundColor, Colors.transparent);
        expect(sheet.elevation, 0);
        final hostShape = sheet.shape! as RoundedRectangleBorder;
        expect(hostShape.side, BorderSide.none);
        expect(find.byType(RdGlassPanel), findsWidgets);
        expect(find.byIcon(LucideIcons.volume2), findsOneWidget);
        expect(find.byIcon(LucideIcons.userRoundX), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.volume2)).color,
          tester.element(find.byIcon(LucideIcons.volume2)).colors.accent,
        );
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.userRoundX)).color,
          tester.element(find.byIcon(LucideIcons.userRoundX)).colors.danger,
        );
        final blockStyle = tester.widget<Text>(find.text('Block')).style;
        expect(
          blockStyle?.color,
          tester.element(find.text('Block')).colors.danger,
        );
      });
    },
  );

  testWidgets('RdOverflowMenu uses PopupMenuButton on Android', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              RdOverflowMenu<String>(
                items: const [RdMenuItem(value: 'edit', label: 'Edit')],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('showRdMenu icons default to accent and keep overrides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRdMenu<String>(
                context: context,
                items: const [
                  RdMenuItem(
                    value: 'scan',
                    label: 'Scan',
                    icon: LucideIcons.scanBarcode,
                  ),
                  RdMenuItem(
                    value: 'photo',
                    label: 'Photo',
                    icon: LucideIcons.images,
                    iconColor: Color(0xFF0F766E),
                  ),
                  RdMenuItem(
                    value: 'delete',
                    label: 'Delete',
                    icon: LucideIcons.trash2,
                    destructive: true,
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.scanBarcode)).color,
      tester.element(find.byIcon(LucideIcons.scanBarcode)).colors.accent,
    );
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.images)).color,
      const Color(0xFF0F766E),
    );
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.trash2)).color,
      tester.element(find.byIcon(LucideIcons.trash2)).colors.danger,
    );
  });

  testWidgets('RdOverflowMenu marks the selected item on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              RdOverflowMenu<String>(
                items: const [
                  RdMenuItem(
                    value: 'relevant',
                    label: 'Relevant',
                    icon: LucideIcons.sparkles,
                  ),
                  RdMenuItem(
                    value: 'recent',
                    label: 'Recent',
                    icon: LucideIcons.clock,
                    selected: true,
                  ),
                ],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
    expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    final recent = tester.getCenter(find.text('Recent'));
    final check = tester.getCenter(find.byIcon(LucideIcons.check));
    expect((check.dy - recent.dy).abs(), lessThan(16));
  });

  testWidgets('RdSlider is Cupertino on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdSlider(value: 0.4, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byType(CupertinoSlider), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  testWidgets('RdCheckboxListTile uses Material checkbox on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: RdCheckboxListTile(
            title: const Text('Agree'),
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets(
    'RdCheckboxListTile on iOS builds inside CupertinoAlertDialog',
    (tester) async {
      await _withIosPlatform(() async {
        await tester.pumpWidget(
          _app(
            theme: _iosTheme(),
            home: const CupertinoAlertDialog(
              content: RdCheckboxListTile(
                title: Text('Agree'),
                value: false,
                onChanged: _noopBool,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CupertinoCheckbox), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });
    },
  );

  testWidgets(
    'RdCheckbox uses CupertinoCheckbox on iOS with disabled semantics',
    (
      tester,
    ) async {
      await _withIosPlatform(() async {
        await tester.pumpWidget(
          _app(
            theme: _iosTheme(),
            home: const Scaffold(
              body: RdCheckbox(value: true, onChanged: null),
            ),
          ),
        );
        expect(find.byType(CupertinoCheckbox), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        final checkbox = tester.widget<CupertinoCheckbox>(
          find.byType(CupertinoCheckbox),
        );
        expect(checkbox.onChanged, isNull);
        expect(checkbox.value, isTrue);
        final visual = tester.getSize(find.byKey(RdCheckbox.iosVisualKey));
        expect(visual.width, RdCheckbox.iosVisualSize);
        expect(visual.height, RdCheckbox.iosVisualSize);
      });
    },
  );

  testWidgets(
    'RdCheckboxListTile puts the control on the trailing edge on iOS',
    (
      tester,
    ) async {
      await _withIosPlatform(() async {
        await tester.pumpWidget(
          _app(
            theme: _iosTheme(),
            home: Scaffold(
              body: RdCheckboxListTile(
                title: const Text('Agree'),
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        final checkbox = tester.getTopLeft(find.byType(CupertinoCheckbox));
        final title = tester.getTopLeft(find.text('Agree'));
        expect(checkbox.dx, greaterThan(title.dx));
      });
    },
  );

  testWidgets('RdRefresh uses adaptive indicator on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdRefresh(
              onRefresh: () async {},
              child: ListView(children: const [Text('row')]),
            ),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  testWidgets('showRdNavSheet presents glass modal sheet on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showRdNavSheet(
                    context: context,
                    title: 'Lista',
                    sections: [
                      RdNavSheetSection(
                        items: [
                          RdNavSheetItem(
                            label: 'Settings',
                            icon: LucideIcons.settings,
                            onTap: () => tapped = true,
                          ),
                          RdNavSheetItem(
                            label: 'Delete',
                            icon: LucideIcons.trash2,
                            destructive: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(RdGlassPanel), findsWidgets);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byIcon(LucideIcons.settings), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.settings)).color,
        tester.element(find.byIcon(LucideIcons.settings)).colors.accent,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.trash2)).color,
        tester.element(find.byIcon(LucideIcons.trash2)).colors.danger,
      );
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        tester.element(find.text('Delete')).colors.danger,
      );
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.elevation, 0);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  testWidgets('RdDropdownField opens glass menu on iOS', (tester) async {
    await _withIosPlatform(() async {
      String? value = 'a';
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RdDropdownField<String>(
                label: 'Pick',
                value: value,
                items: const [
                  RdDropdownItem(value: 'a', label: 'Alpha'),
                  RdDropdownItem(value: 'b', label: 'Beta'),
                ],
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byKey(RdFormSelectField.iosFieldKey), findsOneWidget);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(RdGlassPanel), findsWidgets);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(value, 'b');
    });
  });

  testWidgets('RdDropdownField opens Material bottom sheet on Android', (
    tester,
  ) async {
    String? value = 'a';
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RdDropdownField<String>(
              label: 'Pick',
              value: value,
              items: const [
                RdDropdownItem(value: 'a', label: 'Alpha'),
                RdDropdownItem(value: 'b', label: 'Beta'),
              ],
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(RdFormSelectField), findsOneWidget);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(value, 'b');
  });

  testWidgets('RdTextField uses Cupertino soft-fill shell on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: RdTextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(RdTextField.iosFieldKey), findsOneWidget);
      expect(find.byKey(RdFormFieldShell.iosShellKey), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  testWidgets('RdTextField uses Material TextField on Android', (tester) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: RdTextField(
              decoration: InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(RdTextField.iosFieldKey), findsNothing);
    expect(find.byType(CupertinoTextField), findsNothing);
  });

  testWidgets(
    'multiline RdTextField pins empty Material label to the top of the field',
    (tester) async {
      await tester.pumpWidget(
        _app(
          theme: _androidTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: RdTextField(
                maxLines: 4,
                decoration: InputDecoration(labelText: 'Bio (optional)'),
              ),
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.alignLabelWithHint, isTrue);
      expect(field.textAlignVertical, TextAlignVertical.top);

      final fieldRect = tester.getRect(find.byType(TextField));
      final labelRect = tester.getRect(find.text('Bio (optional)'));
      expect(fieldRect.height, greaterThan(80));
      expect(labelRect.top, greaterThan(fieldRect.top));
      expect(labelRect.center.dy, lessThan(fieldRect.center.dy - 8));
      expect(
        labelRect.top - fieldRect.top,
        lessThan(fieldRect.height * 0.35),
      );
    },
  );

  testWidgets(
    'single-line RdTextField keeps empty Material label vertically centered',
    (tester) async {
      await tester.pumpWidget(
        _app(
          theme: _androidTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: RdTextField(
                decoration: InputDecoration(labelText: 'Handle'),
              ),
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.alignLabelWithHint, isNot(true));
      expect(field.textAlignVertical, isNot(TextAlignVertical.top));

      final fieldRect = tester.getRect(find.byType(TextField));
      final labelRect = tester.getRect(find.text('Handle'));
      expect(
        (labelRect.center.dy - fieldRect.center.dy).abs(),
        lessThan(8),
      );
    },
  );

  testWidgets(
    'multiline RdTextField iOS placeholder sits in the top of the field',
    (tester) async {
      await _withIosPlatform(() async {
        await tester.pumpWidget(
          _app(
            theme: _iosTheme(),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: RdTextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Bio (optional)',
                    hintText: 'A few words about you',
                  ),
                ),
              ),
            ),
          ),
        );

        final fieldRect = tester.getRect(find.byType(CupertinoTextField));
        final placeholderRect = tester.getRect(
          find.text('A few words about you'),
        );
        expect(fieldRect.height, greaterThan(80));
        expect(placeholderRect.top, greaterThan(fieldRect.top));
        expect(placeholderRect.center.dy, lessThan(fieldRect.center.dy - 8));
        expect(
          placeholderRect.top - fieldRect.top,
          lessThan(fieldRect.height * 0.35),
        );
      });
    },
  );

  testWidgets('RdTextField shows full Material error text without ellipsis', (
    tester,
  ) async {
    const error = 'Ese identificador ya está en uso. Prueba con otro.';
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 260,
              child: RdTextField(
                decoration: const InputDecoration(
                  labelText: 'Identificador',
                  errorText: error,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(error), findsOneWidget);
    final caption = tester.widget<Text>(
      find.descendant(
        of: find.byType(RdFormFieldCaption),
        matching: find.text(error),
      ),
    );
    expect(caption.maxLines, isNull);
    expect(caption.overflow, isNot(TextOverflow.ellipsis));
    expect(
      find.descendant(
        of: find.byType(InputDecorator),
        matching: find.textContaining('identificador'),
      ),
      findsNothing,
    );
  });

  testWidgets('RdTextField forwards autofillHints on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: const Scaffold(
            body: RdTextField(
              autofillHints: [AutofillHints.email],
              decoration: InputDecoration(hintText: 'email'),
            ),
          ),
        ),
      );
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.autofillHints, contains(AutofillHints.email));
    });
  });

  testWidgets('RdTextField shows maxLength counter on iOS', (tester) async {
    await _withIosPlatform(() async {
      final controller = TextEditingController(text: 'hey');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdTextField(
              controller: controller,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ),
        ),
      );
      expect(find.text('3/10'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'hello!');
      await tester.pump();
      expect(find.text('6/10'), findsOneWidget);
    });
  });

  testWidgets('RdTextField respects canRequestFocus on iOS', (tester) async {
    await _withIosPlatform(() async {
      final focus = FocusNode();
      final controller = TextEditingController(text: '@locked');
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdTextField(
              controller: controller,
              focusNode: focus,
              canRequestFocus: false,
              readOnly: true,
              decoration: const InputDecoration(hintText: 'locked'),
            ),
          ),
        ),
      );
      // CupertinoTextField stomps FocusNode.canRequestFocus from [enabled],
      // so locked fields render SelectableText instead.
      expect(find.byType(CupertinoTextField), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('@locked'), findsOneWidget);
      await tester.tap(find.byType(SelectableText));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });
  });

  testWidgets('RdFormSelectField Material uses floating outlined label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const RdTextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              RdFormSelectField(
                label: 'Timezone',
                valueText: 'Europe/Madrid',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final theme = buildLightTheme();
    final selectDeco = tester
        .widget<InputDecorator>(
          find.descendant(
            of: find.byType(RdFormSelectField),
            matching: find.byType(InputDecorator),
          ),
        )
        .decoration;
    expect(selectDeco.labelText, 'Timezone');
    expect(selectDeco.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(
      selectDeco.floatingLabelStyle?.color,
      theme.inputDecorationTheme.floatingLabelStyle?.color,
    );
    expect(
      selectDeco.labelStyle?.color,
      theme.inputDecorationTheme.labelStyle?.color,
    );
    // No Widget label — that path would bake Cupertino-sized fg3 text.
    expect(selectDeco.label, isNull);
    expect(find.text('Timezone'), findsOneWidget);
    expect(find.text('Europe/Madrid'), findsOneWidget);
  });

  testWidgets('RdFormSelectField uses soft-fill shell on iOS', (tester) async {
    await _withIosPlatform(() async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdFormSelectField(
              label: 'Timezone',
              valueText: 'Europe/Madrid',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.byKey(RdFormSelectField.iosFieldKey), findsOneWidget);
      await tester.tap(find.text('Europe/Madrid'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  testWidgets('RdFormSelectField matches RdTextField height on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  RdTextField(
                    decoration: InputDecoration(hintText: 'typed'),
                  ),
                  SizedBox(height: 8),
                  RdFormSelectField(
                    valueText: 'picked',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final textH = tester
          .getSize(find.byKey(RdFormFieldShell.iosShellKey).first)
          .height;
      final selectH = tester
          .getSize(find.byKey(RdFormSelectField.iosFieldKey))
          .height;
      expect(selectH, closeTo(textH, 1.0));
    });
  });

  testWidgets('RdDropdownField marks current value selected in sheet', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: Scaffold(
            body: RdDropdownField<String>(
              label: 'Pick',
              value: 'a',
              items: const [
                RdDropdownItem(value: 'a', label: 'Alpha'),
                RdDropdownItem(value: 'b', label: 'Beta'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      // Check sits on the Alpha row — Beta has no check.
      final checkCenter = tester.getCenter(find.byIcon(LucideIcons.check));
      final alphaCenter = tester.getCenter(find.text('Alpha').last);
      expect((checkCenter.dy - alphaCenter.dy).abs(), lessThan(24));
    });
  });
}
