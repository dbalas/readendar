import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';

/// Localized label for a consumption [BookFormat] wire value.
///
/// Unknown values stay visible verbatim so a future enum addition does not
/// blank the detail row.
String bookFormatDisplayName(AppL10n l, String value) {
  final trimmed = value.trim();
  return switch (trimmed) {
    BookFormat.physical => l.bookFormatPhysical,
    BookFormat.ebook => l.bookFormatEbook,
    BookFormat.audiobook => l.bookFormatAudiobook,
    BookFormat.other => l.bookFormatOther,
    _ => trimmed,
  };
}

/// Related Lucide icon for a consumption [BookFormat] wire value.
///
/// Unknown or empty values use the generic format glyph so the field chrome
/// stays identifiable.
IconData bookFormatIcon(String value) => switch (value.trim()) {
  BookFormat.physical => LucideIcons.book,
  BookFormat.ebook => LucideIcons.tabletSmartphone,
  BookFormat.audiobook => LucideIcons.headphones,
  BookFormat.other => LucideIcons.bookDashed,
  _ => LucideIcons.bookType,
};
