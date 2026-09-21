import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/features/filters/filters_state.dart';

class FilterSearchField extends ConsumerStatefulWidget {
  const FilterSearchField({super.key, this.filters, this.onChanged});

  /// Optional local state for embedded library surfaces such as pickers.
  /// When omitted, the field keeps using the app-wide [filtersProvider].
  final FiltersState? filters;
  final ValueChanged<FiltersState>? onChanged;

  @override
  ConsumerState<FilterSearchField> createState() => _FilterSearchFieldState();
}

class _FilterSearchFieldState extends ConsumerState<FilterSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.filters?.query ?? ref.read(filtersProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final String query;
    if (widget.filters case final local?) {
      query = local.query;
    } else {
      query = ref.watch(filtersProvider.select((s) => s.query));
    }
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    return RdSearchField(
      controller: _controller,
      hintText: l.filterSearchHint,
      onChanged: _setQuery,
      onClear: () => _setQuery(''),
    );
  }

  void _setQuery(String value) {
    final FiltersState filters;
    if (widget.filters case final local?) {
      filters = local;
    } else {
      filters = ref.read(filtersProvider);
    }
    final next = filters.copyWith(query: value);
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      onChanged(next);
    } else {
      ref.read(filtersProvider.notifier).value = next;
    }
  }
}
