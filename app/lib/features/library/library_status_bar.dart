import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filters_state.dart';

/// Compact library overview: one equal cell per [BookStatus] with the status
/// icon and book count. Tapping filters the library to that status (tap again
/// to clear). Counts always reflect the full library, not the filtered view.
class LibraryStatusBar extends ConsumerWidget {
  const LibraryStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final books = ref.watch(visibleBooksProvider).value ?? const [];
    final selected = ref.watch(
      filtersProvider.select((s) => s.bookStatuses),
    );
    final counts = <String, int>{
      for (final status in BookStatus.all) status: 0,
    };
    for (final book in books) {
      counts.update(book.status, (n) => n + 1, ifAbsent: () => 1);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ReadendarTokens.sp6,
        ReadendarTokens.sp4,
        ReadendarTokens.sp6,
        0,
      ),
      child: Row(
        children: [
          for (final status in BookStatus.all) ...[
            if (status != BookStatus.all.first)
              const SizedBox(width: ReadendarTokens.sp2),
            Expanded(
              child: _StatusCountCell(
                key: Key('library-status-count-$status'),
                status: status,
                count: counts[status] ?? 0,
                label: bookStatusLabel(l, status),
                selected: selected.contains(status),
                onTap: () => _toggleStatus(ref, status),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleStatus(WidgetRef ref, String status) {
    final filters = ref.read(filtersProvider);
    final onlyThis =
        filters.bookStatuses.length == 1 &&
        filters.bookStatuses.contains(status);
    ref.read(filtersProvider.notifier).value = filters.copyWith(
      bookStatuses: onlyThis ? <String>{} : {status},
    );
  }
}

class _StatusCountCell extends StatelessWidget {
  const _StatusCountCell({
    required this.status,
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String status;
  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = bookStatusColor(status, colors);
    final tint = bookStatusTint(status, colors);
    final empty = count == 0 && !selected;
    final radius = BorderRadius.circular(ReadendarTokens.radiusSm);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected || !empty ? tint : colors.surface1,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? accent
                    : empty
                    ? colors.line
                    : accent.withValues(alpha: 0.35),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ReadendarTokens.sp1,
                vertical: ReadendarTokens.sp2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    bookStatusIcon(status),
                    size: 16,
                    color: empty ? colors.fg3 : accent,
                  ),
                  const SizedBox(height: ReadendarTokens.sp1),
                  Text(
                    '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: empty ? colors.fg3 : accent,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
