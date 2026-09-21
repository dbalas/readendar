import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/features/library/personal_book_delete.dart';

/// Personal-library [BookRow] with quick swipe delete.
class OwnedBookRow extends ConsumerWidget {
  const OwnedBookRow({
    required this.book,
    super.key,
    this.onTap,
    this.trailing,
    this.heroCover = false,
    this.heroTag,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Book book;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool heroCover;
  final Object? heroTag;

  /// Outer spacing around the row. Library reorder owns this outside the
  /// drag proxy so floating feedback matches the card only.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Padding(
      padding: margin,
      child: RdListItemActions(
        items: [
          RdMenuItem(
            value: 'delete',
            label: personalBookDeleteLabel(l, book),
            icon: LucideIcons.trash2,
            destructive: true,
          ),
        ],
        onSelected: (_) {
          unawaited(
            deletePersonalBook(context: context, ref: ref, book: book),
          );
        },
        // Card chrome lives on the swipe shell so Delete reveals as a full
        // panel inside the same rounded clip.
        child: BookRow(
          book: book,
          onTap: onTap,
          trailing: trailing,
          heroCover: heroCover,
          heroTag: heroTag,
          margin: EdgeInsets.zero,
          card: false,
        ),
      ),
    );
  }
}
