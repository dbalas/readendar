import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/core/widgets/search_field.dart';

/// Searchable picker over the full IANA timezone database.
///
/// Holds a search controller, so it is a [StatefulWidget] to dispose it.
/// Uses a fixed-height column, not [DraggableScrollableSheet]: the modal sheet
/// chrome hugs children in an unbounded Column, which makes a draggable sheet
/// lay out at infinite height (blank screen).
///
/// Pops the selected IANA name via [Navigator.pop].
class TimezonePickerSheet extends StatefulWidget {
  const TimezonePickerSheet({required this.selected, super.key});

  final String selected;

  @override
  State<TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<TimezonePickerSheet> {
  final _search = TextEditingController();
  late final List<String> _all = appTimeZoneNames();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all.where((t) => t.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.profileChooseTimezone,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            RdSearchField(
              controller: _search,
              hintText: l.profileSearchTimezone,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
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
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          return ListTile(
                            title: Text(t),
                            trailing: t == widget.selected
                                ? const Icon(LucideIcons.check)
                                : null,
                            onTap: () => Navigator.pop(context, t),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
