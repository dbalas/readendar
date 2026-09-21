import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/widget/widget_bridge.dart';

/// One Spotlight / App Search searchable item.
@immutable
class SpotlightItem {
  const SpotlightItem({
    required this.id,
    required this.title,
    required this.url,
    this.subtitle,
    this.keywords = const [],
    this.domain = 'com.readendar',
  });

  final String id;
  final String title;
  final String url;
  final String? subtitle;
  final List<String> keywords;
  final String domain;

  Map<String, Object?> toWire() => {
    'id': id,
    'title': title,
    'url': url,
    if (subtitle != null) 'subtitle': subtitle,
    'keywords': keywords,
    'domain': domain,
  };
}

/// Builds Spotlight items for personal books + quotes.
List<SpotlightItem> buildSpotlightItems({
  required Iterable<Book> books,
  required Iterable<Quote> quotes,
}) {
  final personal = books.where((b) => b.ownerType == OwnerType.user);
  final byId = {for (final b in personal) b.id: b};
  final items = <SpotlightItem>[];
  for (final book in personal) {
    final authors = book.authors.where((a) => a.trim().isNotEmpty).join(', ');
    items.add(
      SpotlightItem(
        id: 'book:${book.id}',
        title: book.title,
        subtitle: authors.isEmpty ? null : authors,
        url: '$kWidgetDeepLinkScheme://book/${book.id}',
        keywords: [
          book.title,
          ...book.authors,
          if (book.isbn13.isNotEmpty) book.isbn13,
        ],
        domain: 'com.readendar.book',
      ),
    );
  }
  for (final quote in quotes) {
    if (quote.category != AnnotationCategory.quote) continue;
    final book = byId[quote.bookId];
    final snippet = quote.text.trim();
    if (snippet.isEmpty) continue;
    final title = snippet.length > 80
        ? '${snippet.substring(0, 77)}…'
        : snippet;
    items.add(
      SpotlightItem(
        id: 'quote:${quote.id}',
        title: title,
        subtitle: book?.title,
        url: '$kWidgetDeepLinkScheme://quote/${quote.id}',
        keywords: [
          snippet,
          if (book != null) ...[
            book.title,
            ...book.authors,
          ],
        ],
        domain: 'com.readendar.quote',
      ),
    );
  }
  return items;
}

/// iOS Core Spotlight bridge. No-op on other platforms.
class SpotlightIndex {
  SpotlightIndex({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('readendar/spotlight');

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<int> indexItems(List<SpotlightItem> items) async {
    if (!isSupported || items.isEmpty) return 0;
    try {
      final n = await _channel.invokeMethod<int>('indexItems', {
        'items': items.map((e) => e.toWire()).toList(),
      });
      return n ?? items.length;
    } catch (e) {
      if (kDebugMode) debugPrint('spotlight indexItems failed: $e');
      return 0;
    }
  }

  Future<bool> deleteAll() async {
    if (!isSupported) return true;
    try {
      await _channel.invokeMethod<void>('deleteAll');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('spotlight deleteAll failed: $e');
      return false;
    }
  }

  Future<void> deleteIds(List<String> ids) async {
    if (!isSupported || ids.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('deleteIds', {'ids': ids});
    } catch (e) {
      if (kDebugMode) debugPrint('spotlight deleteIds failed: $e');
    }
  }

  Future<int> syncLibrary({
    required Iterable<Book> books,
    required Iterable<Quote> quotes,
  }) async {
    if (!isSupported) return 0;
    // Replace the index so deleted books/quotes do not linger in Spotlight.
    if (!await deleteAll()) return 0;
    return indexItems(buildSpotlightItems(books: books, quotes: quotes));
  }
}

/// Process-wide default used by session logout + Gate sync.
SpotlightIndex spotlightIndex = SpotlightIndex();
