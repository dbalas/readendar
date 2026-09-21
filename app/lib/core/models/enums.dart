// String constants matching backend enum values. Use these instead of raw
// strings so renames stay in one place + IDE auto-complete works.

abstract class BookStatus {
  static const pending = 'pending';
  static const wanted = 'wanted';
  static const reading = 'reading';
  static const read = 'read';
  static const abandoned = 'abandoned';

  /// Library sections, filters, and status pickers (active reading first).
  static const List<String> all = [reading, pending, wanted, read, abandoned];
}

abstract class EventStatus {
  static const active = 'active';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

abstract class OwnerType {
  static const user = 'user';
}

abstract class FeedbackKind {
  static const bug = 'bug';
  static const idea = 'idea';
  static const missingBook = 'missing_book';
  static const other = 'other';

  static const List<String> all = [bug, idea, missingBook, other];
}

abstract class ImportOutcome {
  static const created = 'created';
  static const failed = 'failed';
}

abstract class BookFormat {
  static const physical = 'physical';
  static const ebook = 'ebook';
  static const audiobook = 'audiobook';
  static const other = 'other';
}

abstract class PublicationDatePrecision {
  static const year = 'year';
  static const month = 'month';
  static const day = 'day';
}

/// Unified annotation categories (notes, theory, questions, quotes).
enum AnnotationCategory {
  note('note'),
  quote('quote'),
  theory('theory'),
  question('question');

  const AnnotationCategory(this.wire);
  final String wire;

  static const int maxPinsPerBook = 3;

  static AnnotationCategory fromWire(String? s) => AnnotationCategory.values
      .firstWhere((c) => c.wire == s, orElse: () => AnnotationCategory.quote);
}
