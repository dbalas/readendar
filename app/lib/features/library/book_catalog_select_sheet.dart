import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/search_field.dart';

class BookCatalogSelectOption {
  const BookCatalogSelectOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

/// Searchable single-select sheet for long catalog enumerations (language).
Future<String?> showBookCatalogSelectSheet({
  required BuildContext context,
  required String title,
  required List<BookCatalogSelectOption> options,
  required String selected,
  String? emptyLabel,
  bool searchable = true,
}) {
  final l = AppL10n.of(context);
  return showRdModalSheet<String>(
    context: context,
    builder: (sheetContext) => _BookCatalogSelectSheet(
      title: title,
      searchHint: l.actionSearch,
      options: options,
      selected: selected,
      emptyLabel: emptyLabel,
      searchable: searchable,
    ),
  );
}

class _BookCatalogSelectSheet extends StatefulWidget {
  const _BookCatalogSelectSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selected,
    required this.searchable,
    this.emptyLabel,
  });

  final String title;
  final String searchHint;
  final List<BookCatalogSelectOption> options;
  final String selected;
  final String? emptyLabel;
  final bool searchable;

  @override
  State<_BookCatalogSelectSheet> createState() =>
      _BookCatalogSelectSheetState();
}

class _BookCatalogSelectSheetState extends State<_BookCatalogSelectSheet> {
  final _search = TextEditingController();
  String _query = '';

  bool get _showsSearch =>
      widget.searchable &&
      (widget.options.length > 8 || widget.emptyLabel != null);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
              .where((option) => option.label.toLowerCase().contains(q))
              .toList(growable: false);
    final ios = usesCupertinoChrome(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxHeight =
        (MediaQuery.sizeOf(context).height -
            viewPadding.top -
            viewPadding.bottom) *
        0.72;
    final itemCount =
        filtered.length + (widget.emptyLabel != null && q.isEmpty ? 1 : 0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              ios ? 8 : 4,
              16,
              _showsSearch ? 8 : 10,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (_showsSearch) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RdSearchField(
                controller: _search,
                hintText: widget.searchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp3),
          ],
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                left: ios ? 0 : ReadendarTokens.sp5,
                right: ios ? 0 : ReadendarTokens.sp5,
                bottom: ReadendarTokens.sp4,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (widget.emptyLabel != null && q.isEmpty && index == 0) {
                  return _BookCatalogSelectRow(
                    key: const Key('bookCatalogSelect-empty'),
                    label: widget.emptyLabel!,
                    icon: LucideIcons.circleDashed,
                    selected: widget.selected.isEmpty,
                    onTap: () => Navigator.pop(context, ''),
                  );
                }
                final optionIndex = widget.emptyLabel != null && q.isEmpty
                    ? index - 1
                    : index;
                final option = filtered[optionIndex];
                return _BookCatalogSelectRow(
                  key: Key('bookCatalogSelect-${option.value}'),
                  label: option.label,
                  icon: option.icon,
                  selected: option.value == widget.selected,
                  onTap: () => Navigator.pop(context, option.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCatalogSelectRow extends StatelessWidget {
  const _BookCatalogSelectRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    void pick() {
      unawaited(RdHaptics.selection());
      onTap();
    }

    if (usesCupertinoChrome(context)) {
      final c = context.colors;
      final iconColor = rdSheetItemIconColor(context);
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: pick,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ReadendarTokens.sp5,
                vertical: ReadendarTokens.sp3,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: ReadendarTokens.sp4),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: c.fg1,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: ReadendarTokens.sp4),
                    Icon(LucideIcons.check, size: 18, color: c.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ReadendarTokens.sp5,
      ),
      minVerticalPadding: 0,
      leading: icon == null ? null : Icon(icon, size: 18),
      title: Text(label),
      trailing: selected ? const Icon(LucideIcons.check, size: 18) : null,
      onTap: pick,
    );
  }
}
