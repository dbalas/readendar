// Filter bottom sheet (spec §10).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/features/filters/filter_search_field.dart';
import 'package:readendar/features/filters/filters_state.dart';

Future<FiltersState?> showFiltersSheet(
  BuildContext context, {
  bool hideStatus = false,
  FiltersState? initialFilters,
  bool booksOnly = false,
  bool calendarOnly = false,
  List<String>? statusOptions,
}) {
  return showRdModalSheet<FiltersState>(
    context: context,
    builder: (_) => _FiltersSheet(
      hideStatus: hideStatus,
      initialFilters: initialFilters,
      booksOnly: booksOnly,
      calendarOnly: calendarOnly,
      statusOptions: statusOptions,
    ),
  );
}

/// Default chrome for list-filter sheets: title + close, scrollable body,
/// sticky Reset/Apply footer. Use this for every new filter sheet.
class FilterSheetScaffold extends StatelessWidget {
  const FilterSheetScaffold({
    required this.title,
    required this.body,
    required this.onApply,
    super.key,
    this.header,
    this.onReset,
    this.onClose,
  });

  final String title;
  final Widget? header;
  final Widget body;
  final VoidCallback onApply;
  final VoidCallback? onReset;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RdIconButton(
                  icon: LucideIcons.x,
                  tooltip: l.actionClose,
                  onPressed: onClose ?? () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (header != null) ...[header!, const SizedBox(height: 12)],
            Expanded(child: SingleChildScrollView(child: body)),
            const SizedBox(height: 20),
            Row(
              children: [
                if (onReset != null)
                  RdButton.plain(onPressed: onReset, label: l.actionReset),
                const Spacer(),
                RdButton.primary(onPressed: onApply, label: l.actionApply),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({
    this.hideStatus = false,
    this.initialFilters,
    this.booksOnly = false,
    this.calendarOnly = false,
    this.statusOptions,
  });

  /// Hides the book-status section. Used by the per-status book lists, which
  /// are already scoped to a single status.
  final bool hideStatus;
  final FiltersState? initialFilters;

  /// Uses the compact library filter set, excluding event-only controls.
  final bool booksOnly;

  /// Uses the calendar filter set, excluding book status, completion, and date
  /// controls.
  final bool calendarOnly;

  final List<String>? statusOptions;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late FiltersState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters ?? ref.read(filtersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.filtersTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RdIconButton(
                  icon: LucideIcons.x,
                  tooltip: l.actionClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.booksOnly) ...[
              FilterSearchField(
                filters: _draft,
                onChanged: (next) => setState(() => _draft = next),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.hideStatus && !widget.calendarOnly) ...[
                      Text(
                        l.filterStatus,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s
                              in widget.statusOptions ?? BookStatus.all)
                            FilterChoiceCard(
                              key: Key('filter-status-$s'),
                              title: bookStatusLabel(l, s),
                              selected: _draft.bookStatuses.contains(s),
                              color: bookStatusColor(s, context.colors),
                              selectedBackground: bookStatusTint(
                                s,
                                context.colors,
                              ),
                              leading: Icon(
                                bookStatusIcon(s),
                                size: 16,
                                color: bookStatusColor(s, context.colors),
                              ),
                              onTap: () {
                                final next = Set<String>.from(
                                  _draft.bookStatuses,
                                );
                                if (next.contains(s)) {
                                  next.remove(s);
                                } else {
                                  next.add(s);
                                }
                                setState(
                                  () => _draft = _draft.copyWith(
                                    bookStatuses: next,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!widget.booksOnly) ...[
                      Text(
                        l.filterEventType,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in EventType.values)
                            FilterChoiceCard(
                              key: Key('filter-event-${t.backendValue}'),
                              title: t.label(l),
                              selected: _draft.eventTypes.contains(
                                t.backendValue,
                              ),
                              color: t.colorOf(context),
                              leading: Icon(
                                t.icon,
                                size: 16,
                                color: t.colorOf(context),
                              ),
                              onTap: () {
                                final next = Set<String>.from(
                                  _draft.eventTypes,
                                );
                                if (next.contains(t.backendValue)) {
                                  next.remove(t.backendValue);
                                } else {
                                  next.add(t.backendValue);
                                }
                                setState(
                                  () => _draft = _draft.copyWith(
                                    eventTypes: next,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!widget.booksOnly && !widget.calendarOnly) ...[
                      const SizedBox(height: 12),
                      Text(
                        l.filterCompletion,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilterChoiceCard(
                            title: l.filterCompletedOnly,
                            selected: _draft.completedOnly,
                            color: context.colors.success,
                            selectedBackground: context.colors.successSoftBg,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                completedOnly: true,
                                uncompletedOnly: false,
                              ),
                            ),
                          ),
                          FilterChoiceCard(
                            title: l.filterUncompletedOnly,
                            selected: _draft.uncompletedOnly,
                            color: context.colors.warning,
                            selectedBackground: context.colors.warningSoftBg,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                uncompletedOnly: true,
                                completedOnly: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.filterDate,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RdButton.secondary(
                              onPressed: () => _pickDate(isFrom: true),
                              label: _draft.from == null
                                  ? l.filterDate
                                  : _fmt(_draft.from!),
                              expand: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RdButton.secondary(
                              onPressed: () => _pickDate(isFrom: false),
                              label: _draft.to == null
                                  ? l.filterDate
                                  : _fmt(_draft.to!),
                              expand: true,
                            ),
                          ),
                        ],
                      ),
                      if (_draft.from != null || _draft.to != null)
                        RdButton.plain(
                          onPressed: () => setState(
                            () => _draft = _draft.copyWith(
                              from: () => null,
                              to: () => null,
                            ),
                          ),
                          label: l.actionReset,
                          compact: true,
                        ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                RdButton.plain(
                  onPressed: () {
                    if (widget.initialFilters != null) {
                      Navigator.pop(context, const FiltersState());
                    } else {
                      ref.read(filtersProvider.notifier).clear();
                      Navigator.pop(context, const FiltersState());
                    }
                  },
                  label: l.actionReset,
                ),
                const Spacer(),
                RdButton.primary(
                  onPressed: () {
                    if (widget.initialFilters != null) {
                      Navigator.pop(context, _draft);
                    } else {
                      ref.read(filtersProvider.notifier).value = _draft;
                      Navigator.pop(context, _draft);
                    }
                  },
                  label: l.actionApply,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final current = isFrom ? _draft.from : _draft.to;
    final picked = await showRdDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _draft = isFrom
          ? _draft.copyWith(from: () => picked)
          : _draft.copyWith(to: () => picked);
    });
  }

  String _fmt(DateTime d) =>
      MaterialLocalizations.of(context).formatShortDate(d);
}

class FilterChoiceCard extends StatelessWidget {
  const FilterChoiceCard({
    required this.title,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
    this.leading,
    this.selectedBackground,
  });

  final String title;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? selectedBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Material(
          color: selected
              ? selectedBackground ?? color.withValues(alpha: .10)
              : c.surface1,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : c.line,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    SizedBox.square(
                      dimension: 20,
                      child: Center(child: leading),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? color : c.fg1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
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
