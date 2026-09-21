import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

String bookStatusLabel(AppL10n l, String status) => switch (status) {
  BookStatus.reading => l.statusReading,
  BookStatus.pending => l.statusPending,
  BookStatus.wanted => l.statusWanted,
  BookStatus.read => l.statusRead,
  BookStatus.abandoned => l.statusAbandoned,
  _ => status,
};

// Status colors map onto the semantic soft palette so the pill (text + tint)
// adapts to dark mode from a single source. The "color" is always used as the
// foreground sitting on the matching "tint" background, so it resolves to the
// high-contrast `*SoftFg`. Pass `context.colors` at the call site.
Color bookStatusColor(String status, ReadendarColors c) => switch (status) {
  BookStatus.reading => c.accentSoftFg,
  BookStatus.pending => c.warningSoftFg,
  BookStatus.wanted => c.accent2SoftFg,
  BookStatus.read => c.successSoftFg,
  BookStatus.abandoned => c.dangerSoftFg,
  _ => c.fg2,
};

Color bookStatusTint(String status, ReadendarColors c) => switch (status) {
  BookStatus.reading => c.accentSoftBg,
  BookStatus.pending => c.warningSoftBg,
  BookStatus.wanted => c.accent2SoftBg,
  BookStatus.read => c.successSoftBg,
  BookStatus.abandoned => c.dangerSoftBg,
  _ => c.surface2,
};

IconData bookStatusIcon(String status) => switch (status) {
  BookStatus.reading => LucideIcons.bookOpen,
  BookStatus.pending => LucideIcons.clock3,
  BookStatus.wanted => LucideIcons.heart,
  BookStatus.read => LucideIcons.check,
  BookStatus.abandoned => LucideIcons.x,
  _ => LucideIcons.circle,
};

/// Shared status badge used across library surfaces.
class BookStatusPill extends StatelessWidget {
  const BookStatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bookStatusTint(status, c),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
      child: Text(
        bookStatusLabel(AppL10n.of(context), status),
        style: TextStyle(
          fontSize: 10.5,
          color: bookStatusColor(status, c),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
