import 'package:flutter/material.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/collation.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/search_field.dart';

/// Multi-select sheet for book catalog categories.
///
/// Fixed height (not [ConstrainedBox] + [Expanded] in a hugging column): the
/// modal chrome sizes to children, so an unbounded flex overflows the sheet.
Future<List<String>?> showBookCategoryPickerSheet({
  required BuildContext context,
  required List<String> selected,
}) {
  return showRdModalSheet<List<String>>(
    context: context,
    builder: (_) => BookCategoryPickerSheet(selected: selected),
  );
}

class BookCategoryPickerSheet extends StatefulWidget {
  const BookCategoryPickerSheet({required this.selected, super.key});

  final List<String> selected;

  @override
  State<BookCategoryPickerSheet> createState() =>
      _BookCategoryPickerSheetState();
}

class _BookCategoryPickerSheetState extends State<BookCategoryPickerSheet> {
  final _search = TextEditingController();
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final q = _query.trim().toLowerCase();
    final codes = bookCategoryCodes.toList(growable: false)
      ..sort(
        (a, b) => compareLocale(
          bookCategoryLabel(l, a),
          bookCategoryLabel(l, b),
        ),
      );
    final filtered = q.isEmpty
        ? codes
        : codes
              .where(
                (code) => bookCategoryLabel(l, code).toLowerCase().contains(q),
              )
              .toList(growable: false);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.metaCategories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            RdSearchField(
              controller: _search,
              hintText: l.actionSearch,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          l.searchNoResults,
                          style: TextStyle(color: context.colors.fg3),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final code = filtered[i];
                          return RdCheckboxListTile(
                            key: Key('bookCategory-$code'),
                            value: _selected.contains(code),
                            title: Text(bookCategoryLabel(l, code)),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(code);
                              } else {
                                _selected.remove(code);
                              }
                            }),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            RdButton(
              expand: true,
              label: l.actionSave,
              onPressed: () => Navigator.of(context).pop(
                _selected.toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
