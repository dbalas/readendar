import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/features/search/catalog_book_mapping.dart';

/// Shared catalog row used by search.
class SearchHitRow extends ConsumerWidget {
  const SearchHitRow({
    required this.hit,
    super.key,
    this.owned,
    this.onTap,
    this.cover,
    this.selected = false,
    this.statusAction,
    this.margin = EdgeInsets.zero,
  });

  final SearchHit hit;
  final Book? owned;
  final VoidCallback? onTap;
  final Widget? cover;
  final bool selected;
  final Widget? statusAction;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return BookRow(
      book: bookFromSearchHit(hit, owned: owned),
      onTap: onTap,
      showStatus: owned != null,
      showIsbn: true,
      cover: cover,
      coverUrl: hit.coverUrl.trim().isEmpty ? null : hit.coverUrl.trim(),
      backgroundColor: selected ? colors.accentSoftBg : null,
      borderColor: selected ? colors.accent : null,
      statusKey: Key('searchHitOwnedStatus-${hit.dedupeKey}'),
      statusAction: statusAction,
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: colors.fgFaint,
      ),
      margin: margin,
    );
  }
}
