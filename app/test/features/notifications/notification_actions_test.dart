import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/notifications/notification_actions.dart';

ReadingEvent _event({
  required String type,
  String? bookId = 'book-1',
  String? planId,
  String ownerType = 'user',
}) => ReadingEvent(
  id: 'e1',
  ownerType: ownerType,
  ownerId: 'u1',
  bookId: bookId,
  type: type,
  title: 't',
  dateLocal: DateTime.utc(2026, 7),
  status: EventStatus.active,
  planId: planId,
);

void main() {
  group('categoryForEvent', () {
    test('informational events (start/finish/abandoned/release) → informational', () {
      for (final t in ['start', 'finish', 'abandoned', 'release']) {
        expect(categoryForEvent(_event(type: t)), NotifCategory.informational);
      }
    });

    test('plan milestone (completable + planId) → milestonePlan', () {
      expect(
        categoryForEvent(_event(type: 'chapter_milestone', planId: 'p1')),
        NotifCategory.milestonePlan,
      );
    });

    test('completable with a book, no plan → completable', () {
      expect(
        categoryForEvent(_event(type: 'deadline')),
        NotifCategory.completable,
      );
    });

    test('completable without a book → completableNoBook', () {
      expect(
        categoryForEvent(
          _event(type: 'deadline', bookId: null),
        ),
        NotifCategory.completableNoBook,
      );
    });

    test('planId wins even without a resolvable book edge', () {
      // A milestone always has a book, but planId is checked before book.
      expect(
        categoryForEvent(_event(type: 'page_milestone', planId: 'p1')),
        NotifCategory.milestonePlan,
      );
    });
  });

  group('intentForAction', () {
    test('a plain body tap (null) opens the event', () {
      expect(intentForAction(null), NotifIntent.open);
    });
    test('stale replan/progress ids open the event', () {
      expect(intentForAction('replan'), NotifIntent.open);
      expect(intentForAction('progress'), NotifIntent.open);
    });
    test('background actions do not open the app', () {
      expect(intentForAction(kActionComplete), isNull);
      expect(intentForAction(kActionSnooze1h), isNull);
      expect(intentForAction(kActionSnoozeTonight), isNull);
    });
  });

  test('NotifCategory.byId round-trips', () {
    for (final c in NotifCategory.values) {
      expect(NotifCategory.byId(c.id), c);
    }
    expect(NotifCategory.byId('nope'), isNull);
  });

  group('actionsForCategory (button sets + foreground flags)', () {
    // lookupAppL10n builds the localizations synchronously, no widget needed.
    final l = lookupAppL10n(const Locale('es'));

    List<String> ids(NotifCategory c) =>
        [for (final a in actionsForCategory(c, l)) a.id];

    test('plan milestone → Complete · Snooze 1h', () {
      expect(ids(NotifCategory.milestonePlan), [
        kActionComplete,
        kActionSnooze1h,
      ]);
    });

    test('completable → Complete · Snooze 1h', () {
      expect(ids(NotifCategory.completable), [
        kActionComplete,
        kActionSnooze1h,
      ]);
    });

    test('completable no book → Complete · Snooze 1h', () {
      expect(ids(NotifCategory.completableNoBook), [
        kActionComplete,
        kActionSnooze1h,
      ]);
    });

    test('informational → Snooze 1h · Snooze tonight', () {
      expect(ids(NotifCategory.informational), [
        kActionSnooze1h,
        kActionSnoozeTonight,
      ]);
    });

    test('no action opens the app (foreground: false)', () {
      final foreground = {
        for (final c in NotifCategory.values)
          for (final a in actionsForCategory(c, l))
            if (a.foreground) a.id,
      };
      expect(foreground, isEmpty);
    });
  });
}
