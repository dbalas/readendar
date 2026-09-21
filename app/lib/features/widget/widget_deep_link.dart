// Parsing + routing for the widget's per-element deep links. The native widget
// attaches readendar://book/{id} and readendar://event/{id} URLs to its
// tappable rows. Two delivery paths land here:
//   - the OS treats the widget tap like any other app-scheme launch, so it
//     also arrives on the existing `app_links` stream;
//   - the `home_widget` plugin additionally exposes a dedicated
//     `HomeWidget.widgetClicked` event stream (+ `initiallyLaunchedFromHomeWidget`
//     for cold start) that some launcher/OS combinations use instead of a
//     regular scheme launch.
// WidgetDeepLinkHandler listens to both and pushes the same destination either
// way: the book detail screen for a book link, the event's detail sheet (via
// the calendar tab, mirroring NotificationTapHandler) for an event link.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:home_widget/home_widget.dart';

import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/app_deep_link_hub.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/library/quick_progress_screen.dart';
import 'package:readendar/features/quotes/book_annotations_screen.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';
import 'package:readendar/features/share_ingest/share_quote_handoff.dart';
import 'package:readendar/features/widget/quotes_widget_config_screen.dart';
import 'package:readendar/features/widget/widget_bridge.dart'
    show kWidgetAppGroupId, kWidgetDeepLinkScheme;
import 'package:readendar/features/widget/widget_models.dart';

enum WidgetLinkKind {
  book,
  event,
  calendar,
  progress,
  library,
  quote,
  quoteNew,
  quotesConfig,
  shareQuote,
}

@immutable
class WidgetDeepLink {
  const WidgetDeepLink(this.kind, this.id, {this.config, this.widgetId});
  final WidgetLinkKind kind;
  final String id;

  /// [WidgetLinkKind.quotesConfig] only: the tapped instance's current config to pre-fill the
  /// editor, and its Android appWidgetId (null on iOS, where a save can't
  /// target a specific WidgetKit instance).
  final QuotesWidgetConfig? config;
  final int? widgetId;

  @override
  bool operator ==(Object other) =>
      other is WidgetDeepLink &&
      other.kind == kind &&
      other.id == id &&
      other.widgetId == widgetId;

  @override
  int get hashCode => Object.hash(kind, id, widgetId);
}

/// Parses a widget deep link, or null if [uri] isn't one. Accepts
/// `readendar://book/{id}`, `readendar://event/{id}` (host = kind, first path
/// segment = id), `readendar://calendar` (no id — the "see more" footer),
/// `readendar://progress` (App Shortcut / Control Center — no book id),
/// `readendar://quote/{id}` (a quotes-widget tap), `readendar://quote/new`
/// (the quotes widget's "+" button and the OS app shortcut — straight into
/// the composer), and `readendar://share/quote` (Share Extension / Android
/// send text handoff — body lives in App Group). Returns null for the wrong
/// scheme, an unknown host, or a missing/blank id when one is required.
WidgetDeepLink? parseWidgetDeepLink(Uri uri) {
  if (uri.scheme != kWidgetDeepLinkScheme) return null;
  // The quotes-widget tap (Android): edit THIS instance's config. Carries the
  // appWidgetId + current config as query params (readendar://widget-quotes-config?wid=..).
  if (uri.host == 'widget-quotes-config') {
    final q = uri.queryParameters;
    return WidgetDeepLink(
      WidgetLinkKind.quotesConfig,
      '',
      widgetId: int.tryParse(q['wid'] ?? ''),
      config: QuotesWidgetConfig(
        mode: QuotesWidgetMode.fromWire(q['mode']),
        quoteId: (q['quoteId']?.isNotEmpty ?? false) ? q['quoteId'] : null,
        bookId: (q['bookId']?.isNotEmpty ?? false) ? q['bookId'] : null,
        cadence: QuotesWidgetCadence.fromWire(q['cadence']),
        style: QuoteWidgetStyle.fromWire(q['style']),
        showNote: q['showNote'] == 'true',
      ),
    );
  }
  if (uri.host == 'share') {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.first == 'quote') {
      return const WidgetDeepLink(WidgetLinkKind.shareQuote, '');
    }
    return null;
  }
  final kind = switch (uri.host) {
    'book' => WidgetLinkKind.book,
    'event' => WidgetLinkKind.event,
    'calendar' => WidgetLinkKind.calendar,
    'progress' => WidgetLinkKind.progress,
    'library' => WidgetLinkKind.library,
    'quote' => WidgetLinkKind.quote,
    'annotation' => WidgetLinkKind.quote,
    _ => null,
  };
  if (kind == null) return null;
  if (kind == WidgetLinkKind.calendar ||
      kind == WidgetLinkKind.library ||
      kind == WidgetLinkKind.progress) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // progress may carry an optional book id (`readendar://progress/book-7`).
    if (kind == WidgetLinkKind.progress && segments.isNotEmpty) {
      return WidgetDeepLink(kind, segments.first);
    }
    return WidgetDeepLink(kind, '');
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  if (kind == WidgetLinkKind.quote && segments.first == 'new') {
    return const WidgetDeepLink(WidgetLinkKind.quoteNew, '');
  }
  return WidgetDeepLink(kind, segments.first);
}

/// Captured widget deep link awaiting a signed-in, mounted shell. Set by
/// [WidgetDeepLinkHandler]'s stream listeners, consumed + cleared by the same
/// handler — mirrors `pendingNotificationTapProvider`.
final pendingWidgetDeepLinkProvider = StateProvider<WidgetDeepLink?>(
  (_) => null,
);

/// Exposes the deep-link consumer as a Riverpod provider so it can grab a real
/// [Ref] and outlive any single widget. `_Gate` calls `attach` plus
/// `startPlatformExtras` once at boot.
final widgetDeepLinkProvider = Provider<WidgetDeepLinkListener>(
  WidgetDeepLinkListener.new,
);

/// Listens for widget taps on both delivery paths (see file header) and stashes
/// the parsed target into [pendingWidgetDeepLinkProvider]. Actually opening the
/// target requires a mounted shell + session, so that's [WidgetDeepLinkHandler].
class WidgetDeepLinkListener {
  WidgetDeepLinkListener(this._ref);
  final Ref _ref;
  bool _attached = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  /// Registers scheme/Universal-Link handling on the shared [AppDeepLinkHub].
  void attach() {
    if (_attached) return;
    _attached = true;
    _ref.read(appDeepLinkHubProvider).register(handle);
  }

  /// HomeWidget App Group + widgetClicked stream (not covered by AppLinks).
  Future<void> startPlatformExtras() async {
    // iOS home_widget refuses initiallyLaunchedFromHomeWidget / widgetClicked
    // until the App Group id is registered (same requirement as write/sync).
    try {
      await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    } catch (e) {
      if (kDebugMode) debugPrint('widget setAppGroupId failed: $e');
    }

    // Share Extension / Android SEND may stage text without a successful open
    // URL — drain App Group on cold start so the composer still opens.
    await _drainPendingShare();

    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) handle(launchUri);
    } catch (e) {
      if (kDebugMode) debugPrint('widget initial-launch check failed: $e');
    }
    _widgetClickSub ??= HomeWidget.widgetClicked.listen(
      (uri) {
        if (uri != null) handle(uri);
      },
      onError: (Object e, StackTrace _) {
        if (kDebugMode) {
          debugPrint('widget deep-link (widgetClicked) error: $e');
        }
      },
    );
  }

  Future<void> stop() async {
    await _widgetClickSub?.cancel();
    _widgetClickSub = null;
  }

  /// Public so Gate can drain staged Share Extension / ACTION_SEND text on
  /// resume when the extension wrote App Group but failed to open the host.
  Future<void> drainPendingShareIfAny() => _drainPendingShare();

  void handle(Uri uri) {
    final link = parseWidgetDeepLink(uri);
    if (link == null) return;
    _ref.read(pendingWidgetDeepLinkProvider.notifier).state = link;
  }

  Future<void> _drainPendingShare() async {
    // A live share URI already picked the kind. Do not also fire the other.
    if (_ref.read(pendingWidgetDeepLinkProvider) != null) return;
    final text = await takePendingShareQuoteText();
    if (text == null || text.isEmpty) return;
    // Re-stage so the handler's shareQuote branch can take it once (single
    // consumer). Drain only signals the pending deep link.
    await stagePendingShareQuoteText(text);
    _ref.read(pendingWidgetDeepLinkProvider.notifier).state =
        const WidgetDeepLink(WidgetLinkKind.shareQuote, '');
  }
}

/// Wraps the signed-in shell and opens whatever [pendingWidgetDeepLinkProvider]
/// captured: a book link pushes `BookDetailScreen`; an event link mirrors
/// `NotificationTapHandler` — switch to the Calendar tab, focus the event's
/// month, then show its detail sheet.
class WidgetDeepLinkHandler extends ConsumerStatefulWidget {
  const WidgetDeepLinkHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WidgetDeepLinkHandler> createState() =>
      _WidgetDeepLinkHandlerState();
}

class _WidgetDeepLinkHandlerState extends ConsumerState<WidgetDeepLinkHandler> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WidgetDeepLink?>(pendingWidgetDeepLinkProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.ensureVisualUpdate();
        WidgetsBinding.instance.addPostFrameCallback((_) => _open());
      }
    });
    // A deep link can land before bootstrap restores the session; re-attempt
    // once a user exists so the pending target is not stranded.
    ref.listen(sessionProvider, (_, next) {
      if (next.user != null &&
          ref.read(pendingWidgetDeepLinkProvider) != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open());
      }
    });
    return widget.child;
  }

  Future<void> _open() async {
    if (_busy || !mounted) return;
    if (ref.read(pendingWidgetDeepLinkProvider) == null) return;
    // Wait for a session — a widget tap can launch the app cold, before
    // bootstrap restores the user; the session listener re-fires once one
    // exists.
    if (ref.read(sessionProvider).user == null) return;
    _busy = true;
    try {
      await _openLatest();
    } finally {
      _busy = false;
    }
    // A tap that landed while we were opening bailed on the `_busy` guard, so
    // its target is still pending — drain it now so the LATEST tap wins.
    // Without this, tapping event B while A was still resolving stranded B and
    // left the previous event A on screen.
    if (mounted && ref.read(pendingWidgetDeepLinkProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  Future<void> _openLatest() async {
    final link = ref.read(pendingWidgetDeepLinkProvider);
    if (link == null) return;
    // Clear up-front so a deleted/expired target (or a re-fired listener) can't
    // loop on the same id.
    ref.read(pendingWidgetDeepLinkProvider.notifier).state = null;

    if (link.kind == WidgetLinkKind.calendar) {
      ref.read(tabIndexProvider.notifier).state = 2; // Calendar tab.
      return;
    }

    if (link.kind == WidgetLinkKind.library) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      openLibrosTab(ref);
      return;
    }

    if (link.kind == WidgetLinkKind.progress) {
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          rdPageRoute<void>(
            context,
            builder: (_) => QuickProgressScreen(initialBookId: link.id),
          ),
        ),
      );
      return;
    }

    if (link.kind == WidgetLinkKind.quoteNew) {
      // Straight into the composer (quotes-widget "+" / OS app shortcut).
      // Fire-and-forget: awaiting the composer's whole lifetime here would hold
      // the handler's _busy guard until the sheet closes, so a later widget tap
      // would be stuck (the book/quote branches also push without awaiting).
      Navigator.of(context).popUntil((route) => route.isFirst);
      unawaited(openQuoteComposer(context));
      return;
    }

    if (link.kind == WidgetLinkKind.shareQuote) {
      final text = await takePendingShareQuoteText();
      if (text == null || text.isEmpty) return;
      if (!mounted) {
        // Put it back — logout/shell swap raced the await; resume drain or the
        // next open can still consume it.
        await stagePendingShareQuoteText(text);
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
      unawaited(openQuoteComposer(context, initialText: text));
      return;
    }

    if (link.kind == WidgetLinkKind.quotesConfig) {
      // Tapped the quotes widget → edit THIS instance's options (Android).
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          rdPageRoute<void>(
            context,
            builder: (_) => QuotesWidgetConfigScreen(
              editWidgetId: link.widgetId,
              initialConfig: link.config,
            ),
          ),
        ),
      );
      return;
    }

    if (link.kind == WidgetLinkKind.quote) {
      Annotation? annotation;
      try {
        annotation = (await ref.read(quoteRepoProvider).get(link.id)).value;
      } catch (_) {
        annotation = null;
      }
      if (!mounted || annotation == null) return;
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          rdPageRoute<void>(
            context,
            builder: (_) => BookAnnotationsScreen(
              bookId: annotation!.bookId,
              highlightAnnotationId: annotation.id,
            ),
          ),
        ),
      );
      return;
    }

    if (link.kind == WidgetLinkKind.book) {
      // Replace any detail (sheet or pushed screen) left open by a previous
      // widget tap — since taps now reuse the running instance (onNewIntent),
      // pushing without this would stack the new target on top of the old one.
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          rdPageRoute<void>(
            context,
            builder: (_) => BookDetailScreen(bookId: link.id),
          ),
        ),
      );
      return;
    }

    ReadingEvent? event;
    try {
      event = await ref.read(eventProvider(link.id).future);
    } catch (_) {
      // Event no longer exists (deleted/completed) — fall through and just
      // land the user on the calendar.
      event = null;
    }
    // Resolve the event's book up-front so the sheet opens WITH the book +
    // its derived actions. A widget tap can launch the app cold, racing ahead
    // of the personal-library load the sheet reads from — without this the
    // first open showed no book until a second tap warmed the cache.
    Book? book;
    if (event?.bookId != null) {
      try {
        book = await ref.read(bookProvider(event!.bookId!).future);
      } catch (_) {
        book = null;
      }
    }
    if (!mounted) return;
    // A newer widget tap arrived while we were fetching — abandon this now-stale
    // target so we never flash a previous event; `_open`'s drain opens the
    // newer one.
    if (ref.read(pendingWidgetDeepLinkProvider) != null) return;

    ref.read(tabIndexProvider.notifier).state = 2; // Calendar tab.
    // Dismiss any detail (sheet or pushed screen) opened by a previous widget
    // tap before showing this one — otherwise onNewIntent stacks the new event
    // sheet on top of the stale one, which is what was "staying" open.
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (event == null) return;
    ref.read(calendarFocusProvider.notifier).state = event.dateLocal;
    showEventDetailSheet(context, event, book: book);
  }
}
