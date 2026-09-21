import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/library/book_share_handoff.dart';
import 'package:share_plus/share_plus.dart';

/// Canonical ISBN-13 for sharing, or null when the book is manual.
String? bookShareIsbnRef({required String isbn13, required String isbn10}) {
  final i13 = isbn13.trim();
  if (RegExp(r'^[0-9]{13}$').hasMatch(i13)) return i13;
  return normalizeScannedIsbn(isbn10.trim().isNotEmpty ? isbn10 : isbn13);
}

/// Public catalog URL for a library book. Manual titles have no stable link.
String? bookSharePublicUrl({
  required String isbn13,
  required String isbn10,
  String? shareRef,
}) {
  final isbn = bookShareIsbnRef(isbn13: isbn13, isbn10: isbn10);
  if (isbn != null) return '$openLibraryIsbnUrl/$isbn';
  final existing = shareRef?.trim() ?? '';
  if (existing.isNotEmpty && isBookShareRef(existing)) {
    return '$openLibraryIsbnUrl/$existing';
  }
  return null;
}

/// Resolves the share URL for a library book, or toasts when none exists.
Future<String?> resolveBookShareUrl(
  BuildContext context, {
  required String isbn13,
  required String isbn10,
  String? shareRef,
}) async {
  final url = bookSharePublicUrl(
    isbn13: isbn13,
    isbn10: isbn10,
    shareRef: shareRef,
  );
  if (url != null) return url;
  showRdToast(context, message: AppL10n.of(context).bookShareUnavailable);
  return null;
}

/// Shares [title] via the OS sheet.
Future<void> shareBookDetail(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  required String title,
  required String isbn13,
  required String isbn10,
  String? shareRef,
}) async {
  final url = await resolveBookShareUrl(
    context,
    isbn13: isbn13,
    isbn10: isbn10,
    shareRef: shareRef,
  );
  if (url == null || !context.mounted) return;
  final l = AppL10n.of(context);
  await SharePlus.instance.share(
    ShareParams(text: l.bookShareMessage(title, url)),
  );
}
