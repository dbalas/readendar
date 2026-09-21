import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_sync.dart';

/// Shared progress mutation: PUT then invalidate stats / widgets.
/// Callers own success/error toasts so scan can toast after navigating.
Future<Result<Progress>> commitBookProgress({
  required WidgetRef ref,
  required String bookId,
  int? page,
  int? percentage,
  int? chapter,
}) async {
  final result = await ref
      .read(progressRepoProvider)
      .update(bookId, page: page, percentage: percentage, chapter: chapter);
  return result.fold((progress) {
    ref
      ..invalidate(progressProvider(bookId))
      ..invalidatePersonalStats();
    unawaited(syncWidget(ref).catchError((Object _) => false));
    return Ok(progress);
  }, Err<Progress>.new);
}
