import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:share_plus/share_plus.dart';

/// The plain-text bibliographic form: `«text» — Author, Title, p. X`. The
/// page clause is omitted for unanchored quotes; a missing book degrades to
/// just the quoted text. When [includeNote] and the quote has a private note,
/// the note is appended on its own line.
String formatQuoteShareText(
  AppL10n l,
  Quote quote,
  Book? book, {
  bool includeNote = false,
}) {
  final parts = <String>[
    if (book != null && book.authors.isNotEmpty) book.authors.join(', '),
    if (book != null && book.title.isNotEmpty) book.title,
    if (quote.page != null) l.quotePageAbbrev(quote.page!),
  ];
  final attribution = parts.join(', ');
  final quoted = '«${quote.text}»';
  final base = attribution.isEmpty ? quoted : '$quoted — $attribution';
  if (includeNote && quote.note.trim().isNotEmpty) {
    return '$base\n\n${quote.note.trim()}';
  }
  return base;
}

/// Captures the RepaintBoundary under [boundaryKey] at 3× (360×450 logical →
/// 1080×1350 px) and hands the PNG to the system share sheet.
Future<void> shareQuoteCardImage(GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) return;
  final dir = await getTemporaryDirectory();
  // Unique per share: two shares in quick succession must not race on one
  // fixed path (a second write could truncate the first share's file mid-read).
  final file = File(
    '${dir.path}/readendar-quote-${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data.buffer.asUint8List());
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
  );
}
