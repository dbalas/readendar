import 'package:readendar/core/models/models.dart';

/// Rebuilds library_order after a drag inside one status group.
///
/// [visibleIdsInNewOrder] is the new order of the same-status books that
/// were on screen (the 100-book window, or the search/filter matches).
/// Books of that status that were not on screen keep their mixed-list slots.
/// Other statuses are untouched. Ids from another status, or duplicates,
/// are rejected and the original order is returned.
List<String> spliceStatusReorder({
  required List<Book> allBooks,
  required String status,
  required List<String> visibleIdsInNewOrder,
}) {
  final original = [for (final book in allBooks) book.id];
  final statusIds = {
    for (final book in allBooks)
      if (book.status == status) book.id,
  };
  final visibleSet = visibleIdsInNewOrder.toSet();
  if (visibleSet.length != visibleIdsInNewOrder.length ||
      visibleIdsInNewOrder.any((id) => !statusIds.contains(id))) {
    return original;
  }
  var next = 0;
  return [
    for (final book in allBooks)
      if (book.status == status && visibleSet.contains(book.id))
        visibleIdsInNewOrder[next++]
      else
        book.id,
  ];
}
