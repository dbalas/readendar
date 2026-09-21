import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/event_icon.dart';

void main() {
  test('EventType.fromString maps every backend type', () {
    expect(EventType.fromString('start'), EventType.start);
    expect(EventType.fromString('finish'), EventType.finish);
    expect(EventType.fromString('abandoned'), EventType.abandoned);
    expect(
      EventType.fromString('chapter_milestone'),
      EventType.chapterMilestone,
    );
    expect(EventType.fromString('page_milestone'), EventType.pageMilestone);
    expect(EventType.fromString('deadline'), EventType.deadline);
    expect(EventType.fromString('book_return'), EventType.bookReturn);
    expect(EventType.fromString('release'), EventType.release);
    expect(EventType.fromString('nope'), isNull);
  });

  test('informational types match spec §6.5', () {
    expect(EventType.start.isInformational, true);
    expect(EventType.finish.isInformational, true);
    expect(EventType.abandoned.isInformational, true);
    expect(EventType.release.isInformational, true);
    expect(EventType.pageMilestone.isInformational, false);
    expect(EventType.deadline.isInformational, false);
  });

  test('release uses the rocket icon and launch color in both themes', () {
    expect(EventType.release.icon, LucideIcons.rocket);
    expect(EventType.release.color, ReadendarTokens.amber600);
    expect(
      EventType.release.colorFor(Brightness.dark),
      ReadendarTokens.amber300,
    );
  });

  test('every type has icon + color', () {
    for (final t in EventType.values) {
      expect(t.icon, isNotNull);
      expect(t.color, isNotNull);
    }
  });
}
