import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_hub_screen.dart';

void main() {
  testWidgets(
    'month filter keeps hub chrome and loads only the archive list',
    (tester) async {
      final monthReady = Completer<ReadingChapterArchive>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readingChapterArchiveProvider.overrideWith((ref, kind) async* {
              if (kind == 'month') {
                yield await monthReady.future;
                return;
              }
              yield _archive(
                kind: ReadingChapterKind.month,
                periodKey: '2026-07',
              );
            }),
            readingChapterLatestProvider.overrideWith(
              (ref) => Stream.value(
                _archive(
                  kind: ReadingChapterKind.month,
                  periodKey: '2026-07',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const ReadingChapterHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('readingChapterHubTabs')), findsOneWidget);
      expect(find.text('julio de 2026', skipOffstage: true), findsWidgets);
      expect(find.byType(RdProgress), findsNothing);

      await tester.tap(find.text('Meses'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('readingChapterHubTabs')), findsOneWidget);
      expect(
        find.byKey(const Key('readingChapterArchiveLoading')),
        findsOneWidget,
      );
      expect(find.text('junio de 2026', skipOffstage: true), findsNothing);

      monthReady.complete(
        _archive(kind: ReadingChapterKind.month, periodKey: '2026-06'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('junio de 2026', skipOffstage: true), findsOneWidget);
      expect(
        find.byKey(const Key('readingChapterArchiveLoading')),
        findsNothing,
      );
    },
  );

  testWidgets('hub tabs change with a horizontal swipe', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingChapterArchiveProvider.overrideWith((ref, kind) async* {
            yield _archive(
              kind: kind == 'year'
                  ? ReadingChapterKind.year
                  : ReadingChapterKind.month,
              periodKey: kind == 'year' ? '2025' : '2026-07',
            );
          }),
          readingChapterLatestProvider.overrideWith(
            (ref) => Stream.value(
              _archive(
                kind: ReadingChapterKind.month,
                periodKey: '2026-07',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ReadingChapterHubScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('readingChapterHubPages')), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('readingChapterHubPages')),
      const Offset(-320, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('readingChapterHubTabs')), findsOneWidget);
  });

  testWidgets('unread hero uses the compact NEW chip, not a sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingChapterArchiveProvider.overrideWith(
            (ref, kind) => Stream.value(
              _archive(
                kind: ReadingChapterKind.month,
                periodKey: '2026-07',
                hasUnread: true,
              ),
            ),
          ),
          readingChapterLatestProvider.overrideWith(
            (ref) => Stream.value(
              _archive(
                kind: ReadingChapterKind.month,
                periodKey: '2026-07',
                hasUnread: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ReadingChapterHubScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('readingChapterUnreadBadge')), findsOneWidget);
    expect(find.text('NUEVO'), findsOneWidget);
    expect(find.text('Hay un capítulo nuevo listo'), findsNothing);
  });

  testWidgets('empty archive title varies by filter', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingChapterArchiveProvider.overrideWith(
            (ref, kind) => Stream.value(
              const ReadingChapterArchive(
                items: [],
                nextCursor: '',
                hasUnread: false,
                capabilities: ReadingChapterCapabilities(
                  privateGeneration: true,
                ),
              ),
            ),
          ),
          readingChapterLatestProvider.overrideWith(
            (ref) => Stream.value(
              const ReadingChapterArchive(
                items: [],
                nextCursor: '',
                hasUnread: false,
                capabilities: ReadingChapterCapabilities(
                  privateGeneration: true,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ReadingChapterHubScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Un mes o año terminado con lectura crea tu capítulo',
        skipOffstage: true,
      ),
      findsWidgets,
    );
    expect(
      find.text('Your archive begins after a closed period'),
      findsNothing,
    );
    expect(
      find.textContaining('Readendar will build a chapter'),
      findsNothing,
    );

    await tester.tap(find.text('Meses'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Un mes terminado con lectura crea tu capítulo',
        skipOffstage: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Años'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Un año terminado con lectura crea tu capítulo',
        skipOffstage: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('archive load failure shows ErrorRetry, not the empty copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingChapterArchiveProvider.overrideWith((ref, kind) async* {
            throw const FailureException(NetworkFailure());
          }),
          readingChapterLatestProvider.overrideWith(
            (ref) => Stream.value(
              const ReadingChapterArchive(
                items: [],
                nextCursor: '',
                hasUnread: false,
                capabilities: ReadingChapterCapabilities(
                  privateGeneration: true,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ReadingChapterHubScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(
      find.text(
        'Un mes o año terminado con lectura crea tu capítulo',
        skipOffstage: true,
      ),
      findsNothing,
    );
  });
}

ReadingChapterArchive _archive({
  required ReadingChapterKind kind,
  required String periodKey,
  bool hasUnread = false,
}) => ReadingChapterArchive(
  items: [
    ReadingChapterArchiveItem(
      kind: kind,
      periodKey: periodKey,
      timezone: 'UTC',
      startsAt: DateTime.utc(2026, 6),
      endsAt: DateTime.utc(2026, 7),
      seen: true,
      meaningful: true,
      uniqueWorks: 3,
      coverUrls: const [],
    ),
  ],
  nextCursor: '',
  hasUnread: hasUnread,
  capabilities: const ReadingChapterCapabilities(privateGeneration: true),
);
