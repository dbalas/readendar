import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/features/filters/filters_sheet.dart';

/// App-bar filter button that surfaces a small primary-colored dot over the
/// filter icon when [active] (i.e. at least one filter is applied), so the
/// user knows the list is being filtered.
class FilterIconButton extends StatelessWidget {
  const FilterIconButton({
    required this.active,
    super.key,
    this.hideStatus = false,
    this.booksOnly = false,
    this.calendarOnly = false,
    this.onPressed,
  });

  final bool active;

  /// Forwarded to [showFiltersSheet] for the per-status lists, which are
  /// already scoped to a single status.
  final bool hideStatus;

  /// Uses the compact Library filter set, excluding event-only controls.
  /// Library also folds list search into this control.
  final bool booksOnly;

  /// Uses the calendar filter set, excluding book status, completion, and date
  /// controls.
  final bool calendarOnly;
  final VoidCallback? onPressed;

  static const filterIcon = LucideIcons.filter;

  /// Same as [filterIcon]. Kept for tests that referenced the old name.
  static const searchFilterIcon = filterIcon;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return RdIconButton.custom(
      tooltip: booksOnly ? l.filterSearchHint : l.filtersTitle,
      onPressed:
          onPressed ??
          () => showFiltersSheet(
            context,
            hideStatus: hideStatus,
            booksOnly: booksOnly,
            calendarOnly: calendarOnly,
          ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(filterIcon),
          if (active)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: context.colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
