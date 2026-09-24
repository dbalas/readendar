import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appDirectory = Directory.current.path.endsWith('/app')
      ? Directory.current
      : Directory('${Directory.current.path}/app');

  String source(String path) =>
      File('${appDirectory.path}/$path').readAsStringSync();

  test('Android keypad controls own their pressed feedback', () {
    for (final drawable in [
      'android/app/src/main/res/drawable/wdg_progress_control_light.xml',
      'android/app/src/main/res/drawable/wdg_progress_control_dark.xml',
      'android/app/src/main/res/drawable/wdg_progress_button_light.xml',
      'android/app/src/main/res/drawable/wdg_progress_button_dark.xml',
    ]) {
      expect(
        source(drawable),
        contains('android:state_pressed="true"'),
        reason: '$drawable must render a local pressed state',
      );
    }
  });

  test('iOS keypad presses animate the key and only transition the value', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final keypad = swift.substring(
      swift.indexOf('private struct ProgressKeypadView: View'),
      swift.indexOf('private struct ProgressInlineControls: View'),
    );

    expect(
      swift,
      contains('private struct ProgressKeyButtonStyle: ButtonStyle'),
    );
    expect(
      RegExp(
        r'\.buttonStyle\(ProgressKeyButtonStyle\(\)\)',
      ).allMatches(keypad).length,
      5,
    );
    expect(
      keypad,
      contains('.contentTransition(.numericText(value: Double(draft)))'),
    );
  });

  test(
    'iOS book switches and keypad edits avoid network-backed timeline reloads',
    () {
      final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
      final intents = [
        ('SelectProgressBookIntent', 'CycleProgressFieldIntent'),
        ('CycleProgressFieldIntent', 'OpenProgressKeypadIntent'),
        ('OpenProgressKeypadIntent', 'ProgressDigitIntent'),
        ('ProgressDigitIntent', 'BackspaceProgressIntent'),
        ('BackspaceProgressIntent', 'CancelProgressKeypadIntent'),
        ('CancelProgressKeypadIntent', 'SaveProgressIntent'),
      ];

      for (final (start, end) in intents) {
        final intent = swift.substring(
          swift.indexOf('struct $start: AppIntent'),
          swift.indexOf('struct $end: AppIntent'),
        );
        expect(intent, contains('preferCachedProgressTimeline()'));
        expect(intent, isNot(contains('WidgetCenter.shared.reloadTimelines')));
      }
    },
  );

  test('iOS saves the server-derived percentage before reporting success', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final save = swift.substring(
      swift.indexOf('struct SaveProgressIntent: AppIntent'),
      swift.indexOf('struct RefreshProgressWidgetIntent: AppIntent'),
    );

    expect(save, contains('let update = await WidgetAPI.updateProgress('));
    expect(save, isNot(contains('Task.detached')));
    expect(
      save,
      contains('WidgetAPI.setCachedProgress(bookID: bookID, update: update)'),
    );
    expect(save, contains('persistProgressDrafts(bookID: bookID, update: update)'));
    expect(save, contains('setProgressMutationFeedback("saved")'));
  });

  test('native keypads show and enforce known page and chapter totals', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final kotlin = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarProgressWidgetProvider.kt',
    );

    expect(
      swift,
      contains('progressValueLabel(draft, book: book, field: field)'),
    );
    expect(swift, contains('private func progressMaximum(_ book: WBook'));
    expect(swift, contains(r'return "\(value)/\(total)"'));
    expect(kotlin, contains('keypadValue(draft, book, selectedMetric)'));
    expect(
      kotlin,
      contains('private fun maxValue(book: Book, metric: Metric)'),
    );
    expect(kotlin, contains(r'"$value/$total"'));
  });

  test('keypad input avoids cover preloads and terminal feedback expires', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final kotlin = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarProgressWidgetProvider.kt',
    );

    expect(swift, contains('static func cachedCovers('));
    expect(
      swift,
      contains('let usesCachedTimeline = shouldUseCachedProgressTimeline()'),
    );
    expect(swift, contains('WidgetAPI.cachedCovers('));
    expect(swift, contains('private func progressMutationState() -> String'));
    expect(swift, contains('progressMutationFeedbackExpiry()'));
    expect(
      kotlin,
      contains('private const val feedbackDurationMillis = 1_500L'),
    );
    expect(kotlin, contains('postDelayed({'));
    expect(
      kotlin,
      contains('mutationState(context, widgetId) == terminalState'),
    );
  });

  test('Android book selection renders from cache without a summary fetch', () {
    final kotlin = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarProgressWidgetProvider.kt',
    );
    final select = kotlin.substring(
      kotlin.indexOf(
        'if (intent.action != ACTION_NEXT && intent.action != ACTION_SELECT)',
      ),
      kotlin.indexOf('override fun onDeleted'),
    );

    expect(select, contains('WidgetStore.cachedSummary(context)'));
    expect(select, isNot(contains('loadSummary')));
    expect(select, isNot(contains('refresh(')));
  });

  test('iOS snapshots are cache-only and drop a finished selected book', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final quotes = source('ios/ReadendarWidget/ReadendarQuotesWidget.swift');

    final eventsSnapshot = swift.substring(
      swift.indexOf('struct Provider: TimelineProvider'),
      swift.indexOf('func getTimeline(in context: Context'),
    );
    expect(eventsSnapshot, contains('WidgetAPI.cachedSummary()'));
    expect(eventsSnapshot, contains('WidgetAPI.cachedCovers(for: s)'));
    expect(eventsSnapshot, isNot(contains('loadSummary')));
    expect(eventsSnapshot, isNot(contains('preloadCovers')));

    final progressStart = swift.indexOf(
      'private struct ProgressProvider: TimelineProvider',
    );
    final progressTimeline = swift.indexOf(
      'func getTimeline(in context: Context',
      progressStart,
    );
    final progressSnapshot = swift.substring(progressStart, progressTimeline);
    expect(progressSnapshot, contains('WidgetAPI.cachedSummary()'));
    expect(progressSnapshot, contains('resolvedProgressBookID'));
    expect(progressSnapshot, contains('WidgetAPI.cachedCovers('));
    expect(progressSnapshot, isNot(contains('loadSummary')));
    expect(progressSnapshot, isNot(contains('preloadCovers')));

    expect(
      swift,
      contains('private func resolvedProgressBookID(_ books: [WBook])'),
    );
    expect(swift, contains('removeShared(key)'));
    expect(swift, contains('cachedOrError()'));
    expect(
      swift,
      contains('if hasCache() { return (cached(), .stale) }'),
    );
    expect(swift, contains('return (.empty, .error)'));
    expect(swift, contains('case stale'));
    expect(swift, contains('private struct Lossy<T: Decodable>'));
    expect(
      swift,
      contains('coverUrl = (try? c.decodeIfPresent(String.self, forKey: .coverUrl)) ?? ""'),
    );
    final loadSummary = swift.substring(
      swift.indexOf('static func loadSummary() async'),
      swift.indexOf('private static func cachedOrError()'),
    );
    expect(loadSummary, contains('return cachedOrError()'));
    expect(
      loadSummary,
      isNot(contains('return (.empty, .error)')),
      reason: 'missing Keychain tokens must keep a same-account summary cache, '
          'matching quotes; logout is what clears wdg_cached_summary',
    );

    final eventsTimeline = swift.substring(
      swift.indexOf('struct Provider: TimelineProvider'),
      swift.indexOf('// MARK: - Views'),
    );
    expect(
      eventsTimeline,
      contains('Timeline(entries: [entry], policy: .after(next))'),
    );
    expect(eventsTimeline, isNot(contains('entries.append')));

    expect(quotes, contains('WidgetAPI.cachedQuotes()'));
    expect(quotes, contains('WidgetAPI.cachedQuoteCovers(candidates)'));
    final quotesSnapshot = quotes.substring(
      quotes.indexOf('func getSnapshot(in context: Context'),
      quotes.indexOf('func getTimeline(in context: Context'),
    );
    expect(quotesSnapshot, isNot(contains('freshPayload')));
    expect(quotesSnapshot, isNot(contains('preloadQuoteCovers')));
  });

  test('progress widgets do not persist a fallback first-book selection', () {
    final swift = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final kotlin = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarProgressWidgetProvider.kt',
    );

    final resolved = swift.substring(
      swift.indexOf('private func resolvedProgressBookID'),
      swift.indexOf('private struct ReadendarProgressEntryView'),
    );
    expect(resolved, contains('removeShared(key)'));
    expect(resolved, contains('return books.first?.id'));
    expect(
      resolved,
      isNot(contains('setShared')),
      reason: 'showing books.first must not pin that id as the user selection',
    );
    expect(swift, contains('setShared(progressSelectionKey(), bookID)'));

    final selectedBook = kotlin.substring(
      kotlin.indexOf('private fun selectedBook('),
      kotlin.indexOf('private fun actualValue('),
    );
    expect(
      selectedBook,
      contains('WidgetStore.remove(context, selectionKey(widgetId))'),
    );
    expect(selectedBook, isNot(contains('WidgetStore.put')));
    expect(
      kotlin,
      contains('if (storedID != null && book.id != storedID)'),
    );
    expect(
      kotlin,
      isNot(
        contains('WidgetStore.put(context, selectionKey(widgetId), book.id)'),
      ),
    );
    expect(
      kotlin,
      isNot(
        contains('WidgetStore.put(context, selectionKey(widgetId), first.id)'),
      ),
    );
    expect(
      kotlin,
      contains('WidgetStore.put(context, selectionKey(widgetId), next.id)'),
    );
  });

  test('Android progress refresh is cache-only: OK when cached, ERROR otherwise', () {
    final kotlin = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarProgressWidgetProvider.kt',
    );
    final api = source(
      'android/app/src/main/kotlin/com/readendar/readendar/'
      'ReadendarWidgetProvider.kt',
    );
    expect(kotlin, contains('DataState.ERROR'));
    expect(kotlin, contains('result.hasUsableData'));
    expect(kotlin, contains('DataState.OK'));
    expect(api, contains('val live: Boolean = false'));
    expect(
      api,
      contains(
        'hadFetchError && s.events.isEmpty() && s.readingBooks.isEmpty()',
      ),
    );
  });
}
