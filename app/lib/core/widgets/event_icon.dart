import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_badge.dart' show BadgedCover;

/// Event types — must match backend `event.Type`.
enum EventType {
  start,
  finish,
  abandoned,
  chapterMilestone,
  pageMilestone,
  deadline,
  bookReturn,
  release;

  static EventType? fromString(String? s) => switch (s) {
    'start' => start,
    'finish' => finish,
    'abandoned' => abandoned,
    'chapter_milestone' => chapterMilestone,
    'page_milestone' => pageMilestone,
    'deadline' => deadline,
    'book_return' => bookReturn,
    'release' => release,
    _ => null,
  };

  IconData get icon => switch (this) {
    EventType.start => LucideIcons.play,
    EventType.finish => LucideIcons.checkCircle,
    EventType.abandoned => LucideIcons.x,
    EventType.chapterMilestone => LucideIcons.bookmark,
    EventType.pageMilestone => LucideIcons.fileText,
    EventType.deadline => LucideIcons.alertCircle,
    EventType.bookReturn => LucideIcons.bookUp,
    EventType.release => LucideIcons.rocket,
  };

  /// The light-theme hue, tuned for the white reading surface. Kept as the
  /// default so "sticker" badges painted on a white chip (e.g. [BadgedCover])
  /// keep their darker, high-contrast icon. For an icon sitting directly on the
  /// app surface, prefer [colorFor] so it brightens on the deep-ink dark bg.
  Color get color => switch (this) {
    EventType.start => ReadendarTokens.periwinkle600,
    EventType.finish => ReadendarTokens.sage600,
    EventType.abandoned => ReadendarTokens.wine600,
    EventType.chapterMilestone => ReadendarTokens.teal500,
    EventType.pageMilestone => ReadendarTokens.periwinkle500,
    EventType.deadline => ReadendarTokens.amber600,
    EventType.bookReturn => ReadendarTokens.sage700,
    EventType.release => ReadendarTokens.amber600,
  };

  /// Brightness-aware hue: the dark variant brightens to the lighter brand
  /// shades so the icon keeps ≥3:1 contrast on the deep-ink background (the
  /// `*600/*700` light hues go muddy there).
  Color colorFor(Brightness brightness) =>
      brightness == Brightness.light ? color : _darkColor;

  /// Convenience over [colorFor] that reads the brightness from [context] —
  /// mirrors the `context.colors.*` ergonomics for the common build-method case.
  Color colorOf(BuildContext context) => colorFor(Theme.of(context).brightness);

  Color get _darkColor => switch (this) {
    EventType.start => ReadendarTokens.periwinkle300,
    EventType.finish => ReadendarTokens.sage300,
    EventType.abandoned => ReadendarTokens.wine300,
    EventType.chapterMilestone => ReadendarTokens.teal300,
    EventType.pageMilestone => ReadendarTokens.periwinkle300,
    EventType.deadline => ReadendarTokens.amber400,
    EventType.bookReturn => ReadendarTokens.sage300,
    EventType.release => ReadendarTokens.amber300,
  };

  bool get isInformational =>
      this == EventType.start ||
      this == EventType.finish ||
      this == EventType.abandoned ||
      this == EventType.release;

  /// Backend enum value — inverse of [EventType.fromString].
  String get backendValue => switch (this) {
    EventType.start => 'start',
    EventType.finish => 'finish',
    EventType.abandoned => 'abandoned',
    EventType.chapterMilestone => 'chapter_milestone',
    EventType.pageMilestone => 'page_milestone',
    EventType.deadline => 'deadline',
    EventType.bookReturn => 'book_return',
    EventType.release => 'release',
  };

  /// Localized label shared by event form + detail sheet.
  String label(AppL10n l) => switch (this) {
    EventType.start => l.eventTypeStart,
    EventType.finish => l.eventTypeFinish,
    EventType.abandoned => l.eventTypeAbandoned,
    EventType.chapterMilestone => l.eventTypeChapterMilestone,
    EventType.pageMilestone => l.eventTypePageMilestone,
    EventType.deadline => l.eventTypeDeadline,
    EventType.bookReturn => l.eventTypeBookReturn,
    EventType.release => l.eventTypeRelease,
  };
}

class EventIcon extends StatelessWidget {
  const EventIcon({required this.type, super.key, this.size = 16});
  final EventType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(type.icon, size: size, color: type.colorOf(context));
  }
}
