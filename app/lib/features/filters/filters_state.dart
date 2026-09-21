// Global filter state shared by library + calendar (spec §10).

import 'package:flutter/foundation.dart' show ValueGetter;
import 'package:flutter_riverpod/legacy.dart';

import 'package:readendar/core/models/models.dart';

class FiltersState {
  const FiltersState({
    this.bookStatuses = const {},
    this.eventTypes = const {},
    this.completedOnly = false,
    this.uncompletedOnly = false,
    this.query = '',
    this.from,
    this.to,
  });

  final Set<String> bookStatuses;
  final Set<String> eventTypes;
  final bool completedOnly;
  final bool uncompletedOnly;
  final String query;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      bookStatuses.isEmpty &&
      eventTypes.isEmpty &&
      !completedOnly &&
      !uncompletedOnly &&
      query.isEmpty &&
      from == null &&
      to == null;

  /// `from` and `to` use a ValueGetter wrapper so callers can set them to null
  /// (clearing the date range). A plain `DateTime?` parameter can't
  /// distinguish "not provided" from "provided as null".
  FiltersState copyWith({
    Set<String>? bookStatuses,
    Set<String>? eventTypes,
    bool? completedOnly,
    bool? uncompletedOnly,
    String? query,
    ValueGetter<DateTime?>? from,
    ValueGetter<DateTime?>? to,
  }) => FiltersState(
    bookStatuses: bookStatuses ?? this.bookStatuses,
    eventTypes: eventTypes ?? this.eventTypes,
    completedOnly: completedOnly ?? this.completedOnly,
    uncompletedOnly: uncompletedOnly ?? this.uncompletedOnly,
    query: query ?? this.query,
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
  );
}

class FiltersNotifier extends StateNotifier<FiltersState> {
  FiltersNotifier() : super(const FiltersState());
  FiltersState get value => state;
  set value(FiltersState filters) => state = filters;
  void clear() => state = const FiltersState();
}

final filtersProvider = StateNotifierProvider<FiltersNotifier, FiltersState>(
  (_) => FiltersNotifier(),
);

/// Whether a book passes the active library filters (status and free-text
/// query). Shared by the library list and the per-status book lists so the
/// matching rules stay in one place.
bool bookMatchesFilters(Book b, FiltersState filters) {
  if (filters.bookStatuses.isNotEmpty &&
      !filters.bookStatuses.contains(b.status)) {
    return false;
  }
  final query = filters.query.trim().toLowerCase();
  if (query.isEmpty) return true;
  return b.title.toLowerCase().contains(query) ||
      b.authors.any((a) => a.toLowerCase().contains(query)) ||
      b.description.toLowerCase().contains(query);
}
