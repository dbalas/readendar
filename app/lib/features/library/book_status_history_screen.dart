import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_scaffold.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_field_cards.dart';

class BookStatusHistoryScreen extends ConsumerStatefulWidget {
  const BookStatusHistoryScreen({
    required this.book,
    this.canEdit = false,
    super.key,
  });

  final Book book;
  final bool canEdit;

  @override
  ConsumerState<BookStatusHistoryScreen> createState() =>
      _BookStatusHistoryScreenState();
}

class _BookStatusHistoryScreenState
    extends ConsumerState<BookStatusHistoryScreen> {
  final _scrollController = ScrollController();
  final _items = <BookStatusHistoryEntry>[];
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  String? _nextCursor;
  Object? _error;
  Object? _pageError;
  bool _loading = true;
  bool _loadingMore = false;
  String? _savingEntryId;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) unawaited(_loadMore());
  }

  void _resetAnimatedList() {
    _listKey = GlobalKey<AnimatedListState>();
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _pageError = null;
    });
    final result = await ref
        .read(bookRepoProvider)
        .listStatusHistory(widget.book.id);
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _loading = false;
      if (result.isErr) {
        _error = result.failure;
        return;
      }
      final page = result.value!;
      _items
        ..clear()
        ..addAll(page.items);
      _nextCursor = page.nextCursor;
      _resetAnimatedList();
    });
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loading ||
        _loadingMore ||
        cursor == null ||
        _savingEntryId != null ||
        _pageError != null) {
      return;
    }
    final generation = _requestGeneration;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });

    final result = await ref
        .read(bookRepoProvider)
        .listStatusHistory(widget.book.id, cursor: cursor);
    if (!mounted || generation != _requestGeneration) return;

    if (result.isErr) {
      setState(() {
        _loadingMore = false;
        _pageError = result.failure;
      });
      return;
    }

    final page = result.value!;
    final start = _items.length;
    setState(() {
      _items.addAll(page.items);
      _nextCursor = page.nextCursor;
      _loadingMore = false;
    });
    final listState = _listKey.currentState;
    for (var i = 0; i < page.items.length; i++) {
      listState?.insertItem(start + i, duration: Duration.zero);
    }
  }

  Future<void> _editDate(BookStatusHistoryEntry entry) async {
    if (_savingEntryId != null) return;
    final l = AppL10n.of(context);
    final viewerTimezone = ref.read(
      sessionProvider.select(
        (session) => session.user?.timezone ?? 'Europe/Madrid',
      ),
    );
    final local = inAppTimeZone(entry.changedAt, viewerTimezone);
    final nowLocal = inAppTimeZone(DateTime.now().toUtc(), viewerTimezone);
    final picked = await showRdDatePicker(
      context: context,
      initialDate: DateTime(local.year, local.month, local.day),
      firstDate: DateTime(1970),
      lastDate: DateTime(nowLocal.year, nowLocal.month, nowLocal.day),
      helpText: l.actionEdit,
    );
    if (!mounted || picked == null) return;
    if (picked.year == local.year &&
        picked.month == local.month &&
        picked.day == local.day &&
        entry.dateConfirmed) {
      return;
    }
    final nextChangedAt = replaceCivilDateInAppTimeZone(
      entry.changedAt,
      picked,
      viewerTimezone,
    );
    setState(() => _savingEntryId = entry.id);
    final result = await ref
        .read(bookRepoProvider)
        .updateStatusHistoryChangedAt(
          widget.book.id,
          entry.id,
          nextChangedAt,
        );
    if (!mounted) return;
    if (result.isErr) {
      setState(() => _savingEntryId = null);
      showRdFailureToast(context, result.failure!);
      return;
    }
    _applyLocalUpdate(result.value!);
    setState(() => _savingEntryId = null);
    // History date edits may rewrite book.statusChangedAt + feed payloads.
    ref.read(bookOverlayProvider(widget.book.id).notifier).state = null;
    ref
      ..invalidate(bookProvider(widget.book.id))
      ..invalidate(booksProvider);
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.statusHistoryDateUpdated,
    );
  }

  void _applyLocalUpdate(BookStatusHistoryEntry updated) {
    final oldIndex = _items.indexWhere((e) => e.id == updated.id);
    if (oldIndex < 0) return;

    final without = [..._items]..removeAt(oldIndex);
    var newIndex = without.length;
    for (var i = 0; i < without.length; i++) {
      if (_comesBefore(updated, without[i])) {
        newIndex = i;
        break;
      }
    }

    // Keyset cursor is tied to the previous last row's (changedAt, id). Any
    // local date move can make that cursor skip/duplicate on the next page.
    _nextCursor = null;
    _pageError = null;
    _loadingMore = false;

    if (oldIndex == newIndex) {
      setState(() => _items[oldIndex] = updated);
      return;
    }

    final removed = _items.removeAt(oldIndex);
    _listKey.currentState?.removeItem(
      oldIndex,
      (context, animation) => _animatedTile(
        entry: removed,
        animation: animation,
        viewerTimezone: ref.read(
          sessionProvider.select(
            (session) => session.user?.timezone ?? 'Europe/Madrid',
          ),
        ),
      ),
      duration: const Duration(milliseconds: 280),
    );
    _items.insert(newIndex, updated);
    _listKey.currentState?.insertItem(
      newIndex,
      duration: const Duration(milliseconds: 280),
    );
    setState(() {});
  }

  /// Newest-first, then id descending — matches backend keyset order.
  static bool _comesBefore(
    BookStatusHistoryEntry a,
    BookStatusHistoryEntry b,
  ) {
    if (!a.changedAt.isAtSameMomentAs(b.changedAt)) {
      return a.changedAt.isAfter(b.changedAt);
    }
    return a.id.compareTo(b.id) > 0;
  }

  Widget _animatedTile({
    required BookStatusHistoryEntry entry,
    required Animation<double> animation,
    required String viewerTimezone,
  }) {
    final busy = _savingEntryId != null;
    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _HistoryCard(
            entry: entry,
            viewerTimezone: viewerTimezone,
            canEdit: widget.canEdit,
            saving: busy,
            onEditDate: widget.canEdit && !busy ? () => _editDate(entry) : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final viewerTimezone = ref.watch(
      sessionProvider.select(
        (session) => session.user?.timezone ?? 'Europe/Madrid',
      ),
    );
    return RdScaffold(
      title: Text(l.statusHistoryTitle),
      body: _loading
          ? RdProgress.centered()
          : RdRefresh(
              onRefresh: _loadFirstPage,
              child: _items.isEmpty || _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.62,
                          child: EmptyState(
                            icon: LucideIcons.history,
                            message: l.statusHistoryEmpty,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: AnimatedList(
                            key: _listKey,
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                            initialItemCount: _items.length,
                            itemBuilder: (context, index, animation) {
                              if (index >= _items.length) {
                                return const SizedBox.shrink();
                              }
                              return _animatedTile(
                                entry: _items[index],
                                animation: animation,
                                viewerTimezone: viewerTimezone,
                              );
                            },
                          ),
                        ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: RdProgress()),
                          ),
                      ],
                    ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.viewerTimezone,
    required this.canEdit,
    required this.saving,
    this.onEditDate,
  });

  final BookStatusHistoryEntry entry;
  final String viewerTimezone;
  final bool canEdit;
  final bool saving;
  final VoidCallback? onEditDate;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    final date = inAppTimeZone(entry.changedAt, viewerTimezone);
    final statusLabel = Text(
      bookStatusLabel(l, entry.status),
      style: Theme.of(context).textTheme.titleSmall,
    );
    final dateLabel = Text(
      formatMediumDate(context, date),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: colors.fg3),
    );
    final editControl = canEdit
        ? RdIconButton(
            icon: LucideIcons.pencil,
            tooltip: !entry.dateConfirmed && entry.status == 'read'
                ? l.statusHistoryConfirmDate
                : l.actionEdit,
            size: 18,
            color: colors.fg3,
            onPressed: saving ? null : onEditDate,
          )
        : null;
    return RdCard(
      child: Row(
        children: [
          BookFieldLeadingIcon(
            background: bookStatusTint(entry.status, colors),
            icon: bookStatusIcon(entry.status),
            color: bookStatusColor(entry.status, colors),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: statusLabel),
                    const SizedBox(width: 10),
                    dateLabel,
                  ],
                ),
                if (entry.isBaseline) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.statusHistoryBaseline,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.fg3),
                  ),
                ],
                if (!entry.dateConfirmed) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.statusHistoryDateUnconfirmed,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.warningSoftFg,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (editControl != null) ...[
            const SizedBox(width: 4),
            editControl,
          ],
        ],
      ),
    );
  }
}
