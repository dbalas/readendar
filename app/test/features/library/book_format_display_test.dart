import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/library/book_format_display.dart';

void main() {
  test('bookFormatIcon maps each consumption format', () {
    expect(bookFormatIcon(BookFormat.physical), LucideIcons.book);
    expect(bookFormatIcon(BookFormat.ebook), LucideIcons.tabletSmartphone);
    expect(bookFormatIcon(BookFormat.audiobook), LucideIcons.headphones);
    expect(bookFormatIcon(BookFormat.other), LucideIcons.bookDashed);
    expect(bookFormatIcon(''), LucideIcons.bookType);
    expect(bookFormatIcon('mystery'), LucideIcons.bookType);
  });
}
