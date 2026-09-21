import 'package:readendar/core/models/enums.dart';

/// First-paint window for in-memory library book sections.
const kBookSectionWindow = 100;

/// One status bucket after grouping. [status] is empty for ungrouped rows
/// (library status hidden; rating still visible).
class BookStatusGroup<T> {
  const BookStatusGroup({
    required this.status,
    required this.items,
    required this.total,
  });

  final String status;
  final List<T> items;
  final int total;
}

/// Groups [items] in [order], then unknown statuses, then ungrouped.
/// When [window] is set, each bucket keeps only that many leading rows;
/// [total] stays the full bucket size for section badges.
List<BookStatusGroup<T>> groupByBookStatus<T>(
  Iterable<T> items, {
  required String? Function(T item) statusOf,
  List<String> order = BookStatus.all,
  int? window,
}) {
  final groups = <String, List<T>>{};
  final ungrouped = <T>[];
  for (final item in items) {
    final status = statusOf(item);
    if (status != null && status.isNotEmpty) {
      groups.putIfAbsent(status, () => []).add(item);
    } else {
      ungrouped.add(item);
    }
  }
  final keys = <String>[
    ...order,
    ...groups.keys.where((status) => !order.contains(status)),
  ];
  final out = <BookStatusGroup<T>>[];
  for (final status in keys) {
    final all = groups[status];
    if (all == null || all.isEmpty) continue;
    out.add(
      BookStatusGroup(
        status: status,
        items: _windowed(all, window),
        total: all.length,
      ),
    );
  }
  if (ungrouped.isNotEmpty) {
    out.add(
      BookStatusGroup(
        status: '',
        items: _windowed(ungrouped, window),
        total: ungrouped.length,
      ),
    );
  }
  return out;
}

List<T> _windowed<T>(List<T> items, int? window) {
  if (window == null || items.length <= window) return items;
  return items.sublist(0, window);
}

/// Whether a status bucket's books (and load-more) should render.
bool isBookStatusSectionExpanded(Set<String> collapsed, String status) =>
    !collapsed.contains(status);

/// Toggles [status] inside [collapsed] (mutates the set in place).
void toggleBookStatusSection(Set<String> collapsed, String status) {
  if (collapsed.contains(status)) {
    collapsed.remove(status);
  } else {
    collapsed.add(status);
  }
}
