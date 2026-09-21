import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/notifications/notification_content.dart';

ReadingEvent _event(
  EventType type, {
  int? targetChapter,
  int? targetPage,
  String? bookId = 'b1',
}) => ReadingEvent(
  id: 'e1',
  ownerType: OwnerType.user,
  ownerId: 'u1',
  type: type.backendValue,
  title: 'persisted',
  dateLocal: DateTime.utc(2026, 6, 10),
  status: EventStatus.active,
  bookId: bookId,
  targetChapter: targetChapter,
  targetPage: targetPage,
);

void main() {
  late AppL10n l;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l = await AppL10n.delegate.load(const Locale('es'));
  });

  NotificationContent content(
    ReadingEvent e, {
    String? bookTitle = 'Pedro Páramo',
  }) =>
      notificationContentFor(e, bookTitle: bookTitle, l: l);

  test('milestone title carries the target number', () {
    expect(
      content(_event(EventType.chapterMilestone, targetChapter: 5)).title,
      l.notifTitleReachChapter(5),
    );
    expect(
      content(_event(EventType.pageMilestone, targetPage: 135)).title,
      l.notifTitleReachPage(135),
    );
  });

  test('milestone without a target falls back to the generic label', () {
    expect(
      content(_event(EventType.chapterMilestone)).title,
      l.eventTypeChapterMilestone,
    );
    expect(
      content(_event(EventType.pageMilestone)).title,
      l.eventTypePageMilestone,
    );
  });

  test('informational + action titles use their own verbs, body = book', () {
    for (final type in [
      EventType.start,
      EventType.finish,
      EventType.abandoned,
      EventType.bookReturn,
      EventType.release,
    ]) {
      final c = content(_event(type));
      expect(c.title, isNotEmpty);
      expect(c.title, isNot('persisted')); // computed, not the persisted title
      expect(c.body, 'Pedro Páramo');
    }
  });

  test('deadline appends its target page to the body', () {
    final c = content(_event(EventType.deadline, targetPage: 200));
    expect(c.title, l.notifTitleDeadline);
    expect(c.body, 'Pedro Páramo · ${l.notifBodyDeadlineTarget(200)}');
  });

  test('deadline without a target shows only the book', () {
    expect(content(_event(EventType.deadline)).body, 'Pedro Páramo');
  });

  test('body is null when the book does not resolve', () {
    expect(content(_event(EventType.start), bookTitle: null).body, isNull);
  });

  test('unknown type falls back to the persisted title', () {
    final e = ReadingEvent(
      id: 'e1',
      ownerType: OwnerType.user,
      ownerId: 'u1',
      type: 'something_new',
      title: 'persisted',
      dateLocal: DateTime.utc(2026, 6, 10),
      status: EventStatus.active,
    );
    expect(notificationContentFor(e, l: l).title, 'persisted');
  });
}
