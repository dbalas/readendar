import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/localization_delegates.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_root_nav_bar.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marketing frames for the root README. Skipped in CI.
///
/// ```bash
/// cd app && flutter test test/docs/readme_frame_capture_test.dart \
///   --dart-define=README_CAPTURE=true
/// ```
const _capture = bool.fromEnvironment('README_CAPTURE');

const _screenSize = Size(390, 844);
const _bezel = 11.0;
const _deviceRadius = 52.0;
const _screenRadius = 42.0;

Future<void> _loadAppFonts() async {
  final raw = await rootBundle.loadString('FontManifest.json');
  final entries = jsonDecode(raw) as List<dynamic>;
  for (final entry in entries) {
    final map = entry as Map<String, dynamic>;
    final family = map['family'] as String;
    final fonts = map['fonts'] as List<dynamic>;
    final loader = FontLoader(family);
    for (final font in fonts) {
      final asset = (font as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

void main() {
  testWidgets('writes framed README screenshots', (tester) async {
    await _loadAppFonts();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final books = _books();
    final events = _events();
    final progress = _progress();

    Future<void> capture({
      required String name,
      required Size canvas,
      required Widget frame,
    }) async {
      tester.view.physicalSize = canvas * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(
        _ReadmeApp(
          prefs: prefs,
          books: books,
          events: events,
          progress: progress,
          child: frame,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('readme-capture')),
      );
      final image = await boundary
          .toImage(pixelRatio: 2)
          .timeout(
            const Duration(seconds: 20),
          );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('../docs/readme/$name.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Widget shell({required int index, required Widget child}) {
      return _DeviceFrame(
        selectedIndex: index,
        child: child,
      );
    }

    await capture(
      name: 'home',
      canvas: const Size(720, 1020),
      frame: ColoredBox(
        color: ReadendarTokens.paperCanvas,
        child: Center(child: shell(index: 0, child: const HomeScreen())),
      ),
    );
  }, skip: !_capture);
}

class _ReadmeApp extends StatelessWidget {
  const _ReadmeApp({
    required this.prefs,
    required this.books,
    required this.events,
    required this.progress,
    required this.child,
  });

  final SharedPreferences prefs;
  final List<Book> books;
  final List<ReadingEvent> events;
  final Map<String, Progress> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith(_Session.new),
        booksProvider.overrideWith((ref) async => books),
        upcomingEventsProvider.overrideWith((ref) async => events),
        calendarEventsProvider.overrideWith((ref, range) async => events),
        for (final book in books)
          progressProvider(book.id).overrideWith(
            (ref) async => progress[book.id] ?? Progress(bookEntryId: book.id),
          ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
        localizationsDelegates: readendarLocalizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, nested) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: true,
              padding: const EdgeInsets.fromLTRB(0, 59, 0, 34),
              viewPadding: const EdgeInsets.fromLTRB(0, 59, 0, 34),
            ),
            child: ReadendarThemeBackground(
              animateEffects: false,
              child: nested ?? const SizedBox.shrink(),
            ),
          );
        },
        home: RepaintBoundary(
          key: const Key('readme-capture'),
          child: child,
        ),
      ),
    );
  }
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final deviceSize = Size(
      _screenSize.width + _bezel * 2,
      _screenSize.height + _bezel * 2,
    );
    return SizedBox(
      width: deviceSize.width,
      height: deviceSize.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ReadendarTokens.ink900,
          borderRadius: BorderRadius.circular(_deviceRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330F1014),
              offset: Offset(0, 28),
              blurRadius: 48,
              spreadRadius: -12,
            ),
            BoxShadow(
              color: Color(0x1A0F1014),
              offset: Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(_bezel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_screenRadius),
            child: SizedBox(
              width: _screenSize.width,
              height: _screenSize.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Shell(
                      selectedIndex: selectedIndex,
                      child: child,
                    ),
                  ),
                  const IgnorePointer(child: _StatusChrome()),
                  const IgnorePointer(child: _DynamicIsland()),
                  const IgnorePointer(child: _HomeIndicator()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final destinations = [
      RdNavDestination(icon: const Icon(LucideIcons.home), label: l.navHome),
      RdNavDestination(icon: const Icon(LucideIcons.book), label: l.navLibrary),
      RdNavDestination(
        icon: const Icon(LucideIcons.calendar),
        label: l.navCalendar,
      ),
      RdNavDestination(icon: const Icon(LucideIcons.user), label: l.navYou),
    ];
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RdRootNavBarMetrics.horizontalPad,
            0,
            RdRootNavBarMetrics.horizontalPad,
            RdRootNavBarMetrics.bottomPad,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xF0FCFCFC),
              borderRadius: RdGlassPanel.pillRadius,
              border: Border.all(color: ReadendarTokens.paper300),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x240F1014),
                  offset: Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: SizedBox(
              height: RdRootNavBarMetrics.barHeight,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _ReadmeNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadmeNavItem extends StatelessWidget {
  const _ReadmeNavItem({
    required this.destination,
    required this.selected,
  });

  final RdNavDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.accent : c.fg3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(color: fg, size: 22),
            child: destination.icon,
          ),
          const SizedBox(height: 5),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              height: 1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChrome extends StatelessWidget {
  const _StatusChrome();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: ReadendarTokens.fontUi,
      fontWeight: FontWeight.w600,
      fontSize: 15,
      height: 1,
      color: ReadendarTokens.ink900,
      decoration: TextDecoration.none,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 16, 22, 0),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            Text('9:41', style: style),
            Spacer(),
            Icon(LucideIcons.signal, size: 14, color: ReadendarTokens.ink900),
            SizedBox(width: 6),
            Icon(LucideIcons.wifi, size: 14, color: ReadendarTokens.ink900),
            SizedBox(width: 6),
            Icon(
              LucideIcons.batteryFull,
              size: 16,
              color: ReadendarTokens.ink900,
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 11),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ReadendarTokens.ink900,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: SizedBox(width: 126, height: 36),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x660F1014),
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          child: SizedBox(width: 128, height: 5),
        ),
      ),
    );
  }
}

class _Session extends SessionNotifier {
  _Session(super.ref) {
    state = SessionState(user: _user);
  }
}

AppUser get _user => AppUser(
  id: 'user-1',
  email: 'ana@readendar.com',
  displayName: 'Ana',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime(2026, 7),
);

List<Book> _books() => [
  Book(
    id: 'cien-anos',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'Cien años de soledad',
    authors: const ['Gabriel García Márquez'],
    status: BookStatus.reading,
    pageCount: 496,
    rating: 4.5,
    annotationCount: 4,
  ),
  Book(
    id: 'rayuela',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'Rayuela',
    authors: const ['Julio Cortázar'],
    status: BookStatus.reading,
    format: BookFormat.ebook,
    pageCount: 736,
    rating: 4,
  ),
  Book(
    id: 'aleph',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'El Aleph',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.reading,
    pageCount: 224,
    rating: 5,
  ),
  Book(
    id: 'paramo',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'Pedro Páramo',
    authors: const ['Juan Rulfo'],
    status: BookStatus.pending,
    pageCount: 144,
  ),
  Book(
    id: 'ficciones',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'Ficciones',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.wanted,
    format: BookFormat.ebook,
    pageCount: 224,
    rating: 5,
  ),
  Book(
    id: 'quijote',
    ownerType: OwnerType.user,
    ownerId: 'user-1',
    title: 'Don Quijote de la Mancha',
    authors: const ['Miguel de Cervantes'],
    status: BookStatus.read,
    pageCount: 1056,
    rating: 4,
  ),
];

Map<String, Progress> _progress() => {
  'cien-anos': Progress(bookEntryId: 'cien-anos', currentPage: 210),
  'rayuela': Progress(bookEntryId: 'rayuela', currentChapter: 34),
  'aleph': Progress(bookEntryId: 'aleph', currentPercentage: 42),
  'quijote': Progress(
    bookEntryId: 'quijote',
    currentPage: 1056,
    currentPercentage: 100,
  ),
};

List<ReadingEvent> _events() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    ReadingEvent(
      id: 'ev-page',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      bookId: 'cien-anos',
      type: EventType.pageMilestone.backendValue,
      title: 'Página 300 de Cien años',
      dateLocal: today,
      timeLocal: '08:30',
      tz: 'Europe/Madrid',
      targetPage: 300,
      status: EventStatus.active,
    ),
    ReadingEvent(
      id: 'ev-chapter',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      bookId: 'rayuela',
      type: EventType.chapterMilestone.backendValue,
      title: 'Capítulo 40 de Rayuela',
      dateLocal: today.add(const Duration(days: 2)),
      timeLocal: '21:00',
      tz: 'Europe/Madrid',
      targetChapter: 40,
      status: EventStatus.active,
    ),
    ReadingEvent(
      id: 'ev-return',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      bookId: 'paramo',
      type: EventType.bookReturn.backendValue,
      title: 'Devolver Pedro Páramo',
      dateLocal: today.add(const Duration(days: 5)),
      timeLocal: '18:00',
      tz: 'Europe/Madrid',
      status: EventStatus.active,
    ),
    ReadingEvent(
      id: 'ev-finish',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      bookId: 'quijote',
      type: EventType.finish.backendValue,
      title: 'Terminé el Quijote',
      dateLocal: today.subtract(const Duration(days: 4)),
      status: EventStatus.completed,
    ),
  ];
}
