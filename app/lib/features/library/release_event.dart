import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/auto_status_events.dart';
import 'package:uuid/uuid.dart';

class ExploreCatalogAddResult {
  const ExploreCatalogAddResult(
    this.book, {
    this.releaseEventScheduled = false,
  });

  final Book book;
  final bool releaseEventScheduled;
}

/// Civil calendar day from the stored publication date Y-M-D.
/// Date-only catalog values are local midnights; do not convert through UTC.
DateTime? releaseEventDateLocal(DateTime? publicationDate) {
  if (publicationDate == null) return null;
  return DateTime(
    publicationDate.year,
    publicationDate.month,
    publicationDate.day,
  );
}

String formatExploreReleaseOfferDate(
  DateTime date, {
  String precision = '',
  String locale = 'es',
}) {
  final local = DateTime(date.year, date.month, date.day);
  return switch (precision) {
    PublicationDatePrecision.year => DateFormat.y(locale).format(local),
    PublicationDatePrecision.month => DateFormat.yMMMM(locale).format(local),
    _ => DateFormat.yMMMd(locale).format(local),
  };
}

/// Highlighted opt-in on the add-book form when adding an upcoming release.
class ExploreReleaseOfferBanner extends StatelessWidget {
  const ExploreReleaseOfferBanner({
    required this.dateLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const bannerKey = Key('exploreReleaseOfferBanner');
  static const switchKey = Key('exploreReleaseOfferSwitch');

  final String dateLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colors.accentSoftFg,
      fontWeight: FontWeight.w600,
    );
    return Material(
      key: bannerKey,
      color: colors.accentSoftBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        side: BorderSide(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: () {
          unawaited(RdHaptics.selection());
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.rocket,
                size: 20,
                color: colors.accentSoftFg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.exploreCatalogMatchOfferRelease, style: titleStyle),
                    const SizedBox(height: 4),
                    _ReleaseOfferDateBadge(
                      label: dateLabel,
                      foreground: colors.accentSoftFg,
                      background: colors.accent.withValues(alpha: 0.14),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: switchKey,
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (next) {
                  unawaited(RdHaptics.selection());
                  onChanged(next);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseOfferDateBadge extends StatelessWidget {
  const _ReleaseOfferDateBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Creates a release calendar event on the book publication date (best-effort).
/// Returns whether an event was created. Surfaces failures without rolling back
/// the book create.
Future<bool> maybeCreateReleaseEventForBook({
  required WidgetRef ref,
  required BuildContext context,
  required Book book,
  required DateTime? publicationDate,
  required AppL10n l,
}) async {
  final user = ref.read(sessionProvider).user;
  final day = releaseEventDateLocal(publicationDate);
  if (user == null || day == null) return false;

  final listed = await ref.read(eventRepoProvider).listForBook(book.id);
  if (!context.mounted) return false;
  if (!listed.isOk) {
    showRdFailureToast(context, listed.failure!);
    return false;
  }
  if (hasActiveAutoStatusEventOnDay(
    listed.value!,
    EventType.release,
    day,
  )) {
    return false;
  }

  final created = await ref
      .read(eventRepoProvider)
      .create(
        ownerType: OwnerType.user,
        ownerId: user.id,
        type: EventType.release.backendValue,
        title: EventType.release.label(l),
        dateLocal: day,
        bookId: book.id,
        idempotencyKey: const Uuid().v4(),
      );
  if (!context.mounted) return false;
  if (!created.isOk) {
    showRdFailureToast(context, created.failure!);
    return false;
  }
  ref
    ..invalidate(eventsForBookProvider(book.id))
    ..invalidateCalendarEvents()
    ..invalidate(upcomingEventsProvider);
  return true;
}
