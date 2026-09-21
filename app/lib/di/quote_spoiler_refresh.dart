import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/isbn.dart';

final quoteSpoilerEligibilityRefreshEpochProvider = StateProvider<int>(
  (_) => 0,
);

String _readCanonicalKey(Book? book) {
  if (book == null || book.status != BookStatus.read) {
    return '';
  }
  return isbnComparisonKey(book.isbnDisplay);
}

/// Whether one personal-library mutation changes quote spoiler eligibility.
@visibleForTesting
bool changesQuoteSpoilerEligibility({Book? before, Book? after}) =>
    _readCanonicalKey(before) != _readCanonicalKey(after);

void notifyPersonalBookSpoilerEligibilityMutation(
  WidgetRef ref, {
  Book? before,
  Book? after,
}) {
  if (changesQuoteSpoilerEligibility(before: before, after: after)) {
    notifyQuoteSpoilerEligibilityChanged(ref);
  }
}

void notifyQuoteSpoilerEligibilityChanged(WidgetRef ref) {
  ref.read(quoteSpoilerEligibilityRefreshEpochProvider.notifier).state++;
}
