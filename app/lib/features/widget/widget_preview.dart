// In-app preview of the home-screen widget, shown in the "add widget" sheet so
// the user sees what their widget will render before adding it. It reads the
// same local snapshot native widgets render (via [widgetSummaryProvider]) and
// mirrors the native layout: a "READENDAR" wordmark + a currently-reading
// cover strip on top, then the upcoming events as app-style rows. Reuses
// [EventCardCompact] from Home so the preview matches the real event list.
//
// Keeping this in lockstep with the native Android (WidgetListFactory) and iOS
// (EventRow) renderers is deliberate: one JSON contract, three renderers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/widgets/cover_image.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_models.dart';

/// Max event rows shown in the preview (the iOS widget also shows a
/// family-sized prefix; Android scrolls the rest).
const _kPreviewMaxRows = 3;

/// A device-like framed card that renders the current widget snapshot. Sized to
/// evoke the medium home-screen widget. Handles loading / error / data itself.
class WidgetPreview extends ConsumerWidget {
  const WidgetPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = ref.watch(widgetSummaryProvider);
    return ReadendarWidgetPreviewFrame(
      child: switch (summary) {
        AsyncData(:final value) => _WidgetBody(summary: value),
        AsyncError() => ReadendarWidgetStateMessage(
          icon: LucideIcons.wifiOff,
          text: AppL10n.of(context).widgetPreviewError,
          color: c.danger,
        ),
        _ => const ReadendarWidgetLoadingBody(),
      },
    );
  }
}

/// The rounded "widget tile" shell + a soft home-screen-ish backdrop, so the
/// preview reads as a widget on a wallpaper rather than just another app card.
class ReadendarWidgetPreviewFrame extends StatelessWidget {
  const ReadendarWidgetPreviewFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accentSoftBg, c.accent2SoftBg],
        ),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: -8,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Shared wordmark used by every Readendar widget preview. Native Android and
/// iOS render the same split: READ in accent, ENDAR in muted foreground.
class ReadendarWidgetWordmark extends StatelessWidget {
  const ReadendarWidgetWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        children: [
          TextSpan(
            text: 'READ',
            style: TextStyle(color: c.accent),
          ),
          TextSpan(
            text: 'ENDAR',
            style: TextStyle(color: c.fg3),
          ),
        ],
      ),
    );
  }
}

/// Header (wordmark + reading strip) + the event-row list, mirroring the native
/// widget priority. Falls back to a state message when there are no events.
class _WidgetBody extends StatelessWidget {
  const _WidgetBody({required this.summary});
  final WidgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final events = summary.events.take(_kPreviewMaxRows).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReadendarWidgetHeader(books: summary.readingBooks),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ReadendarWidgetStateMessage(
              icon: LucideIcons.calendarClock,
              text: l.widgetPreviewEmptyEvents,
              color: c.fg3,
            ),
          )
        else
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _EventRow(event: events[i]),
          ],
        if (summary.hasMore || summary.events.length > _kPreviewMaxRows) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              l.widgetSeeMore,
              style: TextStyle(
                color: c.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "READENDAR" wordmark on the left, currently-reading cover strip on the right.
/// Strip only shows if there are 2+ books (single book is noise).
class ReadendarWidgetHeader extends StatelessWidget {
  const ReadendarWidgetHeader({required this.books, super.key});
  final List<WidgetBook> books;

  @override
  Widget build(BuildContext context) {
    final hasStrip = books.length > 1;
    return Row(
      key: const Key('readendarWidgetHeader'),
      children: [
        const ReadendarWidgetWordmark(),
        if (hasStrip) const Spacer(),
        if (hasStrip)
          Row(
            key: const Key('readendarWidgetReadingStrip'),
            children: [
              for (final b in books.take(4))
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _MiniCover(
                    title: b.title,
                    coverUrl: b.coverUrl,
                    width: 22,
                    height: 31,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A tiny cover thumbnail for the reading strip — the artwork, else a periwinkle
/// chip with the title initial (mirrors the native widgets' cover strip, which
/// show covers only, no text).
class _MiniCover extends StatelessWidget {
  const _MiniCover({
    required this.title,
    required this.coverUrl,
    required this.width,
    required this.height,
  });
  final String title;
  final String coverUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: ReadendarTokens.periwinkle600,
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: TextStyle(
          color: ReadendarTokens.paper50,
          fontSize: height * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: coverUrl.isEmpty
          ? fallback
          : SizedBox(
              width: width,
              height: height,
              child: RemoteCoverImage(
                url: coverUrl,
                tier: CoverDisplayTier.thumb,
                fit: BoxFit.cover,
                error: fallback,
              ),
            ),
    );
  }
}

/// One event row — the same [EventCardCompact] the Home screen renders.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final WidgetEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final type = EventType.fromString(event.type) ?? EventType.deadline;
    final hasBook = event.bookTitle?.isNotEmpty == true;
    final label = type.label(l);
    // The event's own progress/milestone (e.g. "Página 143"), when it's not just
    // a repeat of the book title or the type label.
    final milestone =
        event.title?.isNotEmpty == true &&
            event.title != event.bookTitle &&
            event.title != label
        ? event.title
        : null;
    // With a book: line 1 = book title, line 2 = progress (else author). Without
    // a resolvable book: surface the milestone as the row's own title so it's
    // never lost — and never rendered twice.
    final card = EventCardCompact(
      title: hasBook ? label : (milestone ?? label),
      type: type,
      subtitle: _subtitle(context, l),
      bookTitle: hasBook ? event.bookTitle : null,
      bookAuthor: hasBook ? (milestone ?? event.bookAuthor) : null,
      bookCoverUrl: event.bookCoverUrl,
      completed: event.isCompleted,
      // The leading toggle below already marks completion the way the native
      // widgets do; the card's corner badge would be a redundant second mark.
      showCompletedBadge: false,
    );
    // Leading complete toggle, mirroring both native widgets: an empty circle
    // when active, a green check when done. Completable types only. (The preview
    // is a mock, so it's non-interactive.)
    if (type.isInformational) return card;
    return Row(
      children: [
        Icon(
          event.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          size: 20,
          color: event.isCompleted ? c.success : c.fg3,
        ),
        const SizedBox(width: 6),
        Expanded(child: card),
      ],
    );
  }

  String _subtitle(BuildContext context, AppL10n l) {
    final parts = <String>[];
    final date = DateTime.tryParse(event.dateLocal);
    if (date != null) {
      final now = DateTime.now();
      final days = date
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (days == 0) {
        parts.add(l.homeTodayLabel);
      } else if (days == 1) {
        parts.add(l.homeTomorrowLabel);
      } else if (days > 0 && days < 7) {
        parts.add(l.homeInDays(days));
      } else {
        parts.add(formatDayMonth(context, date));
      }
    }
    if (event.timeLocal != null && event.timeLocal!.isNotEmpty) {
      parts.add(event.timeLocal!);
    }
    return parts.join(' · ');
  }
}

/// Centered icon above a message, used for both the empty and error states —
/// mirrors the native widgets' empty/error views (icon on top, not a bare line).
class ReadendarWidgetStateMessage extends StatelessWidget {
  const ReadendarWidgetStateMessage({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer-free lightweight placeholder rows while the summary loads.
class ReadendarWidgetLoadingBody extends StatelessWidget {
  const ReadendarWidgetLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Row(
      key: const Key('widgetPreviewLoading'),
      children: [
        bar(44, 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(64, 10),
              const SizedBox(height: 8),
              bar(double.infinity, 12),
              const SizedBox(height: 8),
              bar(120, 8),
            ],
          ),
        ),
      ],
    );
  }
}
