// P-07 — Detalle de libro (spec §8.3).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/progress_display.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/custom_field_icon.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/gradient_button.dart';
import 'package:readendar/core/widgets/nav_box.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/core/widgets/premium_book_atmosphere.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_circular_progress.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_section_tabs.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';
import 'package:readendar/features/calendar/book_events_list_body.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/celebration/celebration_screen.dart';
import 'package:readendar/features/library/auto_status_events.dart';
import 'package:readendar/features/library/book_binding_display.dart';
import 'package:readendar/features/library/book_detail_scope.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/book_format_display.dart';
import 'package:readendar/features/library/book_language_display.dart';
import 'package:readendar/features/library/book_status_history_screen.dart';
import 'package:readendar/features/library/custom_fields_screen.dart';
import 'package:readendar/features/library/personal_book_delete.dart';
import 'package:readendar/features/library/progress_editor.dart';
import 'package:readendar/features/library/rating_review_sheet.dart';
import 'package:readendar/features/plan/presentation/plan_history_screen.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';
import 'package:readendar/features/plan/presentation/replan_launch.dart';
import 'package:readendar/features/quotes/book_annotations_screen.dart';
import 'package:readendar/features/quotes/kindle/kindle_import_screen.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';
import 'package:readendar/features/quotes/share/quote_share_sheet.dart';
import 'package:readendar/features/search/catalog_search_link.dart';
import 'package:readendar/features/search/search_screen.dart';
import 'package:readendar/features/store_review/store_review_prompt.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:uuid/uuid.dart';

/// Shared height for the book-detail action buttons (plan + history) so they
/// line up at a consistent size instead of each falling back to its own default.
const double _kDetailActionHeight = 48;

/// Personal library book detail.
class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({
    required this.bookId,
    super.key,
    this.heroTag,
  });
  final String bookId;

  /// Optional source-list Hero tag. Status lists use a namespaced tag because
  /// the root shell keeps the Library tab mounted while another route opens.
  final Object? heroTag;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ScrollController _detailScroll = ScrollController();

  int _customFieldsRevision = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  String get bookId => widget.bookId;

  void _onTabChanged() {}

  @override
  Widget build(BuildContext context) {
    return _buildOwned(context);
  }

  Widget _buildOwned(BuildContext context) {
    final l = AppL10n.of(context);
    final bookAsync = ref.watch(bookViewProvider(bookId));
    if (ref.watch(removedPersonalBookIdsProvider).contains(bookId) ||
        (bookAsync.hasError && _isMissingOwnedBook(bookAsync.error))) {
      return _PopMissingOwnedBook(bookId: bookId);
    }
    final themeId = context.readendarTheme.id;
    final coverColorsEnabled =
        ReadendarThemes.byId(themeId).isPremium &&
        ref.watch(premiumCoverAtmosphereProvider);
    final book = bookAsync.value;
    final progress = ref.watch(progressProvider(bookId));
    final canPlan =
        book != null && (book.status == 'pending' || book.status == 'reading');

    final visibility = book == null
        ? BookDetailVisibility.forOwnedBook(
            canEdit: false,
            canPlan: false,
          )
        : BookDetailVisibility.forOwnedBook(
            canEdit: true,
            canPlan: canPlan,
          );

    final eventCount =
        ref.watch(eventsForBookProvider(bookId)).value?.length ?? 0;

    final showCreate = book != null && visibility.showCreateActions;

    return RevalidateOnEnter(
      providers: [
        bookProvider(bookId),
        progressProvider(bookId),
        upcomingEventsProvider,
      ],
      child: Scaffold(
        floatingActionButton: showCreate
            ? RdCreateAction.fab(
                context: context,
                tooltip: l.bookCreateActions,
                onPressed: () => _openCreateMenu(context, book),
              )
            : null,
        appBar: AppBar(
          title: Text(l.bookDetailTitle),
          actions: [
            if (showCreate)
              ...RdCreateAction.appBarActions(
                context: context,
                tooltip: l.bookCreateActions,
                onPressed: () => _openCreateMenu(context, book),
              ),
            bookAsync.maybeWhen(
              data: (b) => !visibility.showEditInfo
                  ? const SizedBox.shrink()
                  : RdIconButton(
                      icon: LucideIcons.pencil,
                      tooltip: l.bookEditInfo,
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<Book>(
                          rdPageRoute<Book>(
                            context,
                            builder: (_) =>
                                ManualBookFormScreen(initialBook: b),
                          ),
                        );
                        if (updated != null) {
                          if (!mounted) return;
                          setState(() => _customFieldsRevision++);
                          ref.invalidate(bookProvider(bookId));
                          ref.invalidate(booksProvider);
                        }
                      },
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            // Overflow: manage actions (privacy, re-read, delete). Creates live
            // on the + control.
            if (visibility.showOverflowMenu && book != null)
              _BookOverflowMenu(book),
          ],
        ),
        body: SafeArea(
          top: false,
          child: bookAsync.when(
            skipError: bookAsync.hasValue,
            skipLoadingOnReload: bookAsync.hasValue,
            loading: RdProgress.centered,
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(bookProvider(bookId)),
            ),
            data: (b) => RdRefresh(
              onRefresh: () async {
                ref.invalidate(bookProvider(bookId));
                ref.invalidate(upcomingEventsProvider);
                ref.invalidate(progressProvider(bookId));
                ref.invalidate(eventsForBookProvider(bookId));
              },
              child: NestedScrollView(
                controller: _detailScroll,
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      // Bottom matches inter-block gap (12) so tabs sit as far
                      // from the last card as cards sit from each other.
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PremiumBookAtmosphere(
                            themeId: themeId,
                            coverUrl: b.coverUrl,
                            coverColorsEnabled: coverColorsEnabled,
                            scrollController: _detailScroll,
                            progressFraction:
                                (effectiveProgressPercent(
                                      currentPage: progress.value?.currentPage,
                                      currentPercentage:
                                          progress.value?.currentPercentage,
                                      pageCount: b.pageCount,
                                    ) ??
                                    0) /
                                100,
                            child: _Header(
                              b,
                              canEdit: visibility.canEdit,
                              visibility: visibility,
                              heroTag: widget.heroTag,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (visibility.showStatusProgress)
                            _StatusProgressCard(
                              book: b,
                              editable: visibility.canEdit,
                              progress: progress,
                            ),
                          if (visibility.showPlan) ...[
                            const SizedBox(height: 12),
                            // No card chrome — plan actions float on the page
                            // (card fill reads muddy on dark surfaces).
                            _PlanActionsRow(
                              book: b,
                              progress: progress.value,
                            ),
                          ],
                          if (visibility.showNotesQuotes) ...[
                            const SizedBox(height: 12),
                            _AnnotationsCard(b),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _BookDetailTabHeader(
                      RdSectionTabs(
                        controller: _tabs,
                        tabs: [
                          RdSectionTab(label: l.bookDetailTitle),
                          RdSectionTab(
                            label: l.sectionEvents,
                            count: eventCount > 0 ? eventCount : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabs,
                  children: [
                    _DetailsTab(
                      book: b,
                      customFieldsRevision: _customFieldsRevision,
                      canManageCustomFields: visibility.canEdit,
                      showPageTotalsInMetadata:
                          visibility.showPageTotalsInMetadata,
                    ),
                    BookEventsListBody(bookId: bookId),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateMenu(
    BuildContext context,
    Book book,
  ) async {
    final l = AppL10n.of(context);
    final c = context.colors;
    final items = <RdMenuItem<String>>[
      RdMenuItem(
        value: 'event',
        label: l.actionAddEvent,
        icon: LucideIcons.calendarPlus,
        iconColor: c.accentSoftFg,
      ),
      RdMenuItem(
        value: 'note',
        label: l.annotationAddNote,
        icon: LucideIcons.stickyNote,
        iconColor: AnnotationCategoryStyle.hue(AnnotationCategory.note),
      ),
      RdMenuItem(
        value: 'quote',
        label: l.annotationAddQuote,
        icon: LucideIcons.quote,
        iconColor: AnnotationCategoryStyle.hue(AnnotationCategory.quote),
      ),
      RdMenuItem(
        value: 'theory',
        label: l.annotationAddTheory,
        icon: LucideIcons.lightbulb,
        iconColor: AnnotationCategoryStyle.hue(AnnotationCategory.theory),
      ),
      RdMenuItem(
        value: 'question',
        label: l.annotationAddQuestion,
        icon: LucideIcons.circleHelp,
        iconColor: AnnotationCategoryStyle.hue(AnnotationCategory.question),
      ),
    ];

    Future<void> run(String value) async {
      switch (value) {
        case 'event':
          await Navigator.of(context).push(
            rdPageRoute<void>(
              context,
              builder: (_) => EventFormScreen(defaultBookId: book.id),
            ),
          );
        case 'note':
        case 'quote':
        case 'theory':
        case 'question':
          final created = await openQuoteComposer(
            context,
            book: book,
            category: AnnotationCategory.fromWire(value),
          );
          if (created != null && mounted) {
            showRdToast(
              context,
              tone: RdToastTone.success,
              message: AppL10n.of(context).annotationCreated,
              actionLabel: AppL10n.of(context).actionShare,
              onAction: () {
                if (!mounted) return;
                openQuoteShareSheet(context, quote: created, book: book);
              },
            );
          }
      }
    }

    if (items.isEmpty) return;
    if (items.length == 1) {
      await run(items.first.value);
      return;
    }
    final selected = await showRdMenu<String>(
      context: context,
      items: items,
    );
    if (selected == null || !mounted) return;
    await run(selected);
  }
}

class _BookDetailTabHeader extends SliverPersistentHeaderDelegate {
  const _BookDetailTabHeader(this.child);
  final PreferredSizeWidget child;

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_BookDetailTabHeader oldDelegate) =>
      oldDelegate.child != child;
}

class _DetailsTab extends ConsumerStatefulWidget {
  const _DetailsTab({
    required this.book,
    super.key,
    this.showPageTotalsInMetadata = false,
    this.loadCustomFields = true,
    this.canManageCustomFields = false,
    this.initialCustomFields = const [],
    this.customFieldsRevision = 0,
  });
  final Book book;
  final bool showPageTotalsInMetadata;
  final bool loadCustomFields;
  final bool canManageCustomFields;
  final List<BookCustomField> initialCustomFields;
  final int customFieldsRevision;

  @override
  ConsumerState<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends ConsumerState<_DetailsTab>
    with AutomaticKeepAliveClientMixin {
  Future<Result<List<BookCustomField>>>? _fields;
  List<BookCustomField>? _cachedFields;
  Failure? _cachedFailure;
  Future<Result<List<BookDetailFieldLayoutItem>>>? _layout;
  List<BookDetailFieldLayoutItem>? _cachedLayout;

  @override
  bool get wantKeepAlive => true;

  Future<Result<List<BookCustomField>>>? _resolveFields() =>
      widget.initialCustomFields.isNotEmpty
      ? SynchronousFuture(Ok(widget.initialCustomFields))
      : widget.loadCustomFields
      ? ref.read(customFieldRepoProvider).listForBook(widget.book.id)
      : null;

  Future<Result<List<BookDetailFieldLayoutItem>>>? _resolveLayout() =>
      widget.loadCustomFields
      ? ref.read(customFieldRepoProvider).listLayout()
      : null;

  void _watchFields(Future<Result<List<BookCustomField>>>? fields) {
    _fields = fields;
    fields?.then((result) {
      if (!mounted) return;
      setState(() {
        if (result.isOk) {
          _cachedFields = result.value;
          _cachedFailure = null;
        } else {
          _cachedFailure = result.failure;
        }
      });
    });
  }

  void _watchLayout(Future<Result<List<BookDetailFieldLayoutItem>>>? layout) {
    _layout = layout;
    layout?.then((result) {
      if (!mounted) return;
      if (result.isOk) {
        setState(() => _cachedLayout = result.value);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomFields.isNotEmpty) {
      _cachedFields = widget.initialCustomFields;
    }
    _watchFields(_resolveFields());
    _watchLayout(_resolveLayout());
  }

  @override
  void didUpdateWidget(covariant _DetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.book.id != oldWidget.book.id ||
        widget.loadCustomFields != oldWidget.loadCustomFields ||
        widget.customFieldsRevision != oldWidget.customFieldsRevision ||
        !listEquals(
          widget.initialCustomFields,
          oldWidget.initialCustomFields,
        )) {
      if (widget.initialCustomFields.isNotEmpty) {
        _cachedFields = widget.initialCustomFields;
        _cachedFailure = null;
      }
      _watchFields(_resolveFields());
      _watchLayout(_resolveLayout());
    }
  }

  Future<void> _manage() async {
    await Navigator.of(context).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => const CustomFieldsScreen(),
      ),
    );
    if (!mounted) return;
    _reloadFields();
  }

  void _reloadFields() {
    final repo = ref.read(customFieldRepoProvider);
    final fields = repo.listForBook(widget.book.id);
    final layout = repo.listLayout();
    if (!mounted) return;
    setState(() {
      _watchFields(fields);
      _watchLayout(layout);
    });
  }

  List<Widget> _detailRows({
    required List<BookCustomField> customFields,
    required List<BookDetailFieldLayoutItem>? layout,
  }) {
    final book = widget.book;
    final byFieldId = {
      for (final field in customFields) field.fieldId: field,
    };
    final metadata = _metadataByKey(
      context,
      book,
      showPageTotals: widget.showPageTotalsInMetadata,
    );
    final effectiveLayout =
        layout ??
        [
          for (final field in customFields)
            BookDetailFieldLayoutItem(
              key: field.fieldId,
              kind: BookDetailFieldKind.custom,
              hidden: false,
            ),
          if (book.description.isNotEmpty)
            const BookDetailFieldLayoutItem(
              key: 'synopsis',
              kind: BookDetailFieldKind.system,
              hidden: false,
            ),
          for (final key in bookDetailSystemFieldKeys)
            if (key != 'synopsis' && metadata.containsKey(key))
              BookDetailFieldLayoutItem(
                key: key,
                kind: BookDetailFieldKind.system,
                hidden: false,
              ),
        ];

    final rows = <Widget>[];
    for (final item in effectiveLayout) {
      // Totals are not layout-managed; append after the configured rows.
      if (item.key == 'pages' || item.key == 'chapters') continue;
      if (item.kind == BookDetailFieldKind.custom) {
        final field = byFieldId[item.key];
        if (field == null) continue;
        rows.add(
          _MetaRow(
            icon: customFieldIcon(field.iconKey),
            label: field.name,
            child: Text(
              _customFieldDisplayValue(
                context,
                field.value,
                textMode: field.textMode,
              ),
            ),
          ),
        );
        continue;
      }
      if (item.hidden) continue;
      if (item.key == 'synopsis') {
        if (book.description.isEmpty) continue;
        rows.add(_SynopsisMetaRow(book.description));
        continue;
      }
      final meta = metadata[item.key];
      if (meta == null) continue;
      rows.add(
        _MetaRow(icon: meta.icon, label: meta.label, child: meta.child),
      );
    }
    for (final key in const ['pages', 'chapters']) {
      final meta = metadata[key];
      if (meta == null) continue;
      rows.add(
        _MetaRow(icon: meta.icon, label: meta.label, child: meta.child),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n.of(context);

    Widget body({
      List<BookCustomField> customFields = const [],
      Failure? fieldsFailure,
      List<BookDetailFieldLayoutItem>? layout,
    }) {
      final rows = _detailRows(customFields: customFields, layout: layout);
      final showManage = widget.canManageCustomFields;
      final showCard = rows.isNotEmpty || showManage;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (fieldsFailure != null && widget.canManageCustomFields)
            Padding(
              padding: const EdgeInsets.only(bottom: ReadendarTokens.sp8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localizedFailureMessage(l, fieldsFailure),
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                  RdButton.plain(
                    onPressed: _reloadFields,
                    label: l.actionRetry,
                    compact: true,
                  ),
                ],
              ),
            ),
          if (showCard)
            RdCard(
              key: const Key('bookDetailMetadataCard'),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1 || showManage)
                      Divider(
                        height: 1,
                        indent: _kMetaRowDividerIndent,
                        color: context.colors.line,
                      ),
                  ],
                  if (showManage) _ManageCustomFieldsCta(onTap: _manage),
                ],
              ),
            ),
          if (widget.book.excerpt.isNotEmpty) ...[
            const SizedBox(height: ReadendarTokens.sp8),
            _Excerpt(widget.book.excerpt),
          ],
        ],
      );
    }

    if (_fields == null) {
      return body(
        customFields: _cachedFields ?? const [],
        layout: _cachedLayout,
      );
    }

    return FutureBuilder<Result<List<BookCustomField>>>(
      future: _fields,
      builder: (context, snapshot) {
        final failure = snapshot.data?.failure ?? _cachedFailure;
        if (failure != null &&
            snapshot.data?.value == null &&
            !widget.canManageCustomFields &&
            (_cachedFields == null || _cachedFields!.isEmpty)) {
          return body(layout: _cachedLayout);
        }
        final values =
            snapshot.data?.value ?? _cachedFields ?? const <BookCustomField>[];
        final layoutFuture = _layout;
        if (layoutFuture == null) {
          return body(
            customFields: values,
            fieldsFailure: snapshot.data?.failure,
            layout: _cachedLayout,
          );
        }
        return FutureBuilder<Result<List<BookDetailFieldLayoutItem>>>(
          future: layoutFuture,
          builder: (context, layoutSnapshot) {
            final layout = layoutSnapshot.data?.value ?? _cachedLayout;
            return body(
              customFields: values,
              fieldsFailure: snapshot.data?.failure,
              layout: layout,
            );
          },
        );
      },
    );
  }
}

String _customFieldDisplayValue(
  BuildContext context,
  CustomFieldValue value, {
  String textMode = '',
}) {
  final l = AppL10n.of(context);
  return switch (value.kind) {
    CustomFieldType.text => value.text ?? '',
    CustomFieldType.number => localizeCustomFieldDecimal(
      value.decimal ?? '',
      Localizations.localeOf(context),
    ),
    CustomFieldType.datetime =>
      value.instant == null
          ? ''
          : () {
              final locale = Localizations.localeOf(context).toString();
              final local = value.instant!.toLocal();
              final date = DateFormat.yMMMd(locale).format(local);
              if (!customFieldShowsTime(textMode)) return date;
              return DateFormat.yMMMd(locale).add_jm().format(local);
            }(),
    CustomFieldType.boolean =>
      value.boolean == true ? l.customFieldsYes : l.customFieldsNo,
    CustomFieldType.singleSelect => value.optionLabel,
  };
}

class _ManageCustomFieldsCta extends StatelessWidget {
  const _ManageCustomFieldsCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    return Material(
      key: const Key('bookDetailManageCustomFields'),
      color: c.accentSoftBg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_kMetaRowPadding),
          child: Row(
            children: [
              Container(
                width: _kMetaRowIconSize,
                height: _kMetaRowIconSize,
                decoration: BoxDecoration(
                  color: c.surface1,
                  borderRadius: BorderRadius.circular(
                    ReadendarTokens.radiusSm,
                  ),
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.listPlus,
                  size: _kMetaRowIconGlyphSize,
                  color: c.accentSoftFg,
                ),
              ),
              const SizedBox(width: ReadendarTokens.sp3),
              Expanded(
                child: Text(
                  l.customFieldsManage,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 14, color: c.accentSoftFg),
            ],
          ),
        ),
      ),
    );
  }
}

String localizeCustomFieldDecimal(String raw, Locale locale) {
  final decimalSeparator = NumberFormat.decimalPattern(
    locale.toString(),
  ).symbols.DECIMAL_SEP;
  return decimalSeparator == '.' ? raw : raw.replaceAll('.', decimalSeparator);
}

/// Runs a book mutation optimistically: shows [patched] immediately via the
/// overlay, calls [mutate] (which returns a [Failure] or null), then reconciles
/// — refetch on success (revealing identical confirmed data, no flicker),
/// revert + error snackbar on failure. [afterSuccess] runs only on success
/// while still mounted (e.g. extra invalidations, celebration).
/// [persist] always runs on success via the captured container so a pop
/// before the round-trip still refreshes lists under this route.
Future<void> optimisticBookMutation(
  BuildContext context,
  WidgetRef ref,
  AppL10n l, {
  required String bookId,
  required Book patched,
  required Future<Failure?> Function() mutate,
  void Function()? afterSuccess,
  void Function(ProviderContainer container)? persist,
}) async {
  final overlay = ref.read(bookOverlayProvider(bookId).notifier);
  overlay.state = patched;
  final container = ProviderScope.containerOf(context, listen: false);
  // Clears our overlay ONLY if a later mutation hasn't replaced it — otherwise
  // a fast first round-trip would yank a newer optimistic patch off-screen
  // (rapid re-edits before the first request returns).
  void clearIfMine() {
    if (identical(container.read(bookOverlayProvider(bookId)), patched)) {
      container.read(bookOverlayProvider(bookId).notifier).state = null;
    }
  }

  final failure = await mutate();
  if (failure == null) {
    // Pull fresh confirmed data, then drop the overlay — the refreshed value
    // matches the optimistic one, so the swap is invisible.
    container.invalidate(bookProvider(bookId));
    try {
      await container.read(bookProvider(bookId).future);
    } on Object {
      // Refetch failed (offline); the overlay still cleared below so we fall
      // back to whatever the base provider holds.
    }
    container
      ..invalidate(booksProvider)
      ..invalidate(userStatsProvider)
      ..invalidate(userPageStatsProvider);
    persist?.call(container);
    if (context.mounted) {
      clearIfMine();
      afterSuccess?.call();
    }
  } else if (context.mounted) {
    clearIfMine(); // revert
    showRdFailureToast(context, failure);
  }
}

class _Header extends ConsumerWidget {
  const _Header(
    this.b, {
    required this.canEdit,
    required this.visibility,
    this.heroTag,
  });
  final Book b;
  final bool canEdit;
  final BookDetailVisibility visibility;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final rating = b.rating;
    final editable = visibility.ratingEditable;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flight target for the list rows' heroCover (BookRow).
        Hero(
          tag: heroTag ?? 'book-cover-${b.id}',
          child: Semantics(
            label: l.bookCoverEnlarge,
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('bookDetailCover'),
                onTap: () => showBookCoverPreview(
                  context,
                  title: b.title,
                  author: b.authors.isEmpty ? null : b.authors.first,
                  coverUrl: b.coverUrl,
                  color: context.colors.accent2,
                ),
                borderRadius: BorderRadius.circular(6),
                child: BookCover(
                  title: b.title,
                  author: b.authors.isEmpty ? null : b.authors.first,
                  coverUrl: b.coverUrl,
                  color: context.colors.accent2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.title,
                key: const Key('bookDetailEditorialTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (b.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  b.subtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colors.fg2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (b.authors.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  runSpacing: 2,
                  children: [
                    for (var i = 0; i < b.authors.length; i++) ...[
                      if (i > 0)
                        Text(
                          _authorSeparator,
                          style: TextStyle(color: context.colors.fg2),
                        ),
                      CatalogSearchLink(
                        key: Key('authorSearchLink-$i'),
                        query: b.authors[i],
                        column: 'author',
                      ),
                    ],
                  ],
                ),
              ],
              if (visibility.showRating) ...[
                const SizedBox(height: 4),
                Semantics(
                  label: l.ratingLabel,
                  value: rating == null ? l.ratingUnrated : fmtRating(rating),
                  button: editable,
                  child: InkWell(
                    key: const Key('bookHeaderRating'),
                    onTap: editable ? () => _editRating(context, ref) : null,
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: BookRatingDisplay(
                          rating: rating,
                          review: b.reviewMarkdown,
                          showEditHint: editable,
                          reviewKey: const Key('bookHeaderReviewPreview'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editRating(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l = AppL10n.of(context);
    final value = await showRatingReviewSheet(
      context,
      currentRating: b.rating,
      currentReview: b.reviewMarkdown,
    );
    if (value == null || !context.mounted) return;
    await optimisticBookMutation(
      context,
      ref,
      l,
      bookId: b.id,
      patched: b.copyWith(
        rating: value.rating,
        clearRating: value.rating == null,
        reviewMarkdown: value.review,
      ),
      mutate: () async {
        return (await ref
                .read(bookRepoProvider)
                .updateRatingReview(
                  b.id,
                  rating: value.rating,
                  reviewMarkdown: value.review,
                ))
            .failure;
      },
    );
  }
}

/// Compact cockpit: large ring on the left (matches status+totals height);
/// status chip on the right with page/chapter totals underneath, left-aligned.
class _StatusProgressCard extends ConsumerWidget {
  const _StatusProgressCard({
    required this.book,
    required this.editable,
    this.progress,
  });

  final Book book;
  final bool editable;

  final AsyncValue<Progress>? progress;

  /// Status row (48) + gap (8) + totals line (~18) — ring fills that block.
  static const double _ringSide = 74;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showProgress = progress != null;
    final status = _StatusSelectorRow(
      book: book,
      editable: editable,
      onChangeStatus: editable
          ? () => _showBookStatusSheet(context, ref, book)
          : null,
      onOpenHistory: () => Navigator.of(context).push(
        rdPageRoute<void>(
          context,
          builder: (_) => BookStatusHistoryScreen(
            book: book,
            canEdit: editable,
          ),
        ),
      ),
    );

    if (!showProgress) {
      return RdCard(
        padding: bookFieldCardContentPadding,
        child: status,
      );
    }

    return RdCard(
      padding: bookFieldCardContentPadding,
      child: Row(
        children: [
          SizedBox(
            width: _ringSide,
            height: _ringSide,
            child: _ProgressRing(
              book: book,
              progress: progress!,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                status,
                const SizedBox(height: 8),
                _ProgressTotalsUnderStatus(
                  book: book,
                  progress: progress!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip with history icon packed inside the same surface.
class _StatusSelectorRow extends ConsumerWidget {
  const _StatusSelectorRow({
    required this.book,
    required this.editable,
    required this.onOpenHistory,
    this.onChangeStatus,
  });

  final Book book;
  final bool editable;
  final VoidCallback? onChangeStatus;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final radius = BorderRadius.circular(ReadendarTokens.radiusSm);
    final timezone = ref.watch(
      sessionProvider.select(
        (session) => session.user?.timezone ?? 'Europe/Madrid',
      ),
    );
    final statusChangedAt = book.statusChangedAt;
    final statusDateLabel = statusChangedAt == null
        ? null
        : formatMediumDate(
            context,
            inAppTimeZone(statusChangedAt, timezone),
          );

    return Material(
      color: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _kDetailActionHeight,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onChangeStatus,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      BookFieldLeadingIcon(
                        background: bookStatusTint(book.status, c),
                        icon: bookStatusIcon(book.status),
                        color: bookStatusColor(book.status, c),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookStatusLabel(l, book.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.fg1,
                                height: 1.15,
                              ),
                            ),
                            if (statusDateLabel != null)
                              Text(
                                statusDateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.fg3,
                                  height: 1.1,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (editable)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            LucideIcons.chevronDown,
                            size: 18,
                            color: c.fg3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            RdIconButton.compact(
              tooltip: l.statusHistoryView,
              icon: LucideIcons.history,
              size: 18,
              color: c.fg2,
              style: IconButton.styleFrom(
                foregroundColor: c.fg2,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(40, _kDetailActionHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: _kDetailActionHeight,
              ),
              onPressed: onOpenHistory,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBookStatusSheet(
  BuildContext context,
  WidgetRef ref,
  Book b,
) async {
  final l = AppL10n.of(context);
  final statuses = BookStatus.all;
  final selected = await showOptionSelectorSheet<String>(
    context: context,
    label: l.statusLabel,
    value: b.status,
    items: statuses
        .map(
          (status) => OptionSelectorItem<String>(
            value: status,
            label: bookStatusLabel(l, status),
            icon: bookStatusIcon(status),
            color: bookStatusColor(status, context.colors),
          ),
        )
        .toList(),
  );
  if (selected == null || selected == b.status || !context.mounted) return;
  final wasRead = b.status == BookStatus.read;
  Book? finishedBook;
  await optimisticBookMutation(
    context,
    ref,
    l,
    bookId: b.id,
    patched: b.copyWith(
      status: selected,
      statusChangedAt: DateTime.now().toUtc(),
    ),
    mutate: () async {
      // Rating/review is collected on the celebration screen (or later via
      // the edit sheet) — finish does not open a sheet first.
      final r = selected == BookStatus.read && !wasRead
          ? await ref
                .read(bookRepoProvider)
                .finish(
                  b.id,
                  idempotencyKey: const Uuid().v4(),
                )
          : await ref.read(bookRepoProvider).changeStatus(b.id, selected);
      finishedBook = r.value;
      return r.failure;
    },
    persist: (container) {
      if (selected == BookStatus.read && !wasRead) {
        // FinishPersonal completes progress to total pages (100%) — refresh
        // the ring and celebration metrics.
        container.invalidate(progressProvider(b.id));
      }
    },
    afterSuccess: () {
      notifyPersonalBookSpoilerEligibilityMutation(
        ref,
        before: b,
        after:
            finishedBook ??
            b.copyWith(
              status: selected,
              statusChangedAt: DateTime.now().toUtc(),
            ),
      );
      // A status change moves the book in/out of "reading" — refresh the
      // widget's currently-reading strip.
      unawaited(syncWidget(ref).catchError((Object _) => false));
      if (context.mounted) {
        unawaited(
          maybeAutoCreateStatusEvents(
            ref: ref,
            context: context,
            book: b.copyWith(status: selected),
            previousStatus: b.status,
            newStatus: selected,
            l: l,
          ),
        );
      }
      // Celebrate only when the book newly transitions into "read".
      if (selected == BookStatus.read && !wasRead && context.mounted) {
        final celebrated = finishedBook ?? b.copyWith(status: selected);
        unawaited(
          _openCelebrationThenMaybeReview(context, ref, celebrated),
        );
      }
    },
  );
}

/// Pushes [CelebrationScreen], then (for personal finishes) may soft-ask for a
/// store review once the user leaves — never on the celebration itself.
Future<void> _openCelebrationThenMaybeReview(
  BuildContext context,
  WidgetRef ref,
  Book celebrated,
) async {
  final sessions = await Navigator.of(context).push<int?>(
    rdPageRoute<int?>(
      context,
      builder: (_) => CelebrationScreen(book: celebrated),
    ),
  );
  if (!context.mounted || sessions == null) return;
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (!context.mounted) return;
  await maybeShowStoreReviewPrompt(
    context,
    ref,
    trigger: StoreReviewTrigger.celebration,
    bookSessions: sessions,
  );
}

class _AnnotationsCard extends ConsumerWidget {
  const _AnnotationsCard(this.b);
  final Book b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final count =
        ref.watch(bookAnnotationsProvider(b.id)).value?.length ??
        b.annotationCount;
    return NavBox(
      icon: LucideIcons.notebookPen,
      tintBg: context.colors.warningSoftBg,
      tintFg: context.colors.warningSoftFg,
      title: l.annotationsCardTitle,
      boldTitle: false,
      count: count,
      onTap: () => Navigator.of(context).push(
        rdPageRoute<void>(
          context,
          builder: (_) => BookAnnotationsScreen(bookId: b.id, book: b),
        ),
      ),
    );
  }
}

/// Determinate ring that expands to fill its square parent (status-column height).
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.book, required this.progress});

  final Book book;
  final AsyncValue<Progress> progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.value;
    final percent = effectiveProgressPercent(
      currentPage: value?.currentPage,
      currentPercentage: value?.currentPercentage,
      pageCount: book.pageCount,
    );
    final showPercent =
        value != null &&
        shouldShowProgressPercentLabel(
          currentPage: value.currentPage,
          currentPercentage: value.currentPercentage,
          pageCount: book.pageCount,
        );
    final label = showPercent ? '${percent ?? 0}%' : '—';
    final ringValue = showPercent ? (percent ?? 0) / 100 : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
        onTap: () => _showProgressSheet(context, book, value),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            // Keep stroke proportional so a taller ring does not look skinny.
            final stroke = (side * 0.085).clamp(3.5, 5.5);
            final fontSize = (side * 0.22).clamp(11.0, 16.0);
            return Center(
              child: RdCircularProgress(
                value: ringValue,
                label: label,
                size: side,
                strokeWidth: stroke,
                labelStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: context.colors.successSoftFg,
                  height: 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Page / chapter totals under the status chip, left-aligned with it.
class _ProgressTotalsUnderStatus extends StatelessWidget {
  const _ProgressTotalsUnderStatus({
    required this.book,
    required this.progress,
  });

  final Book book;
  final AsyncValue<Progress> progress;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: c.fg3,
      height: 1.2,
    );

    void openEditor(Progress? p) => _showProgressSheet(context, book, p);

    Widget editButton(Progress? p) {
      return RdIconButton.compact(
        key: const Key('progressEditButton'),
        tooltip: l.actionEdit,
        icon: LucideIcons.pencil,
        size: 14,
        color: c.fg3,
        style: IconButton.styleFrom(
          foregroundColor: c.fg3,
          padding: const EdgeInsets.all(4),
          minimumSize: const Size(28, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => openEditor(p),
      );
    }

    return progress.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Row(
        children: [
          Expanded(child: Text(l.progressNoData, style: style)),
          editButton(null),
        ],
      ),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              e is FailureException && e.failure is NotFoundFailure
                  ? l.progressNoData
                  : localizedErrorMessage(l, e),
              style: style,
            ),
          ),
          editButton(null),
        ],
      ),
      data: (p) {
        final parts = <Widget>[];

        void add(IconData icon, String text) {
          if (parts.isNotEmpty) {
            parts.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: c.fgFaint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
          parts.add(
            Icon(icon, size: 13, color: c.fg3),
          );
          parts.add(const SizedBox(width: 4));
          parts.add(
            Flexible(
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        if (p.currentPage != null) {
          add(
            LucideIcons.bookOpen,
            book.pageCount != null
                ? '${p.currentPage} / ${book.pageCount}'
                : '${p.currentPage}',
          );
        }
        if (p.currentChapter != null) {
          add(
            LucideIcons.bookmark,
            book.chapterCount != null
                ? '${p.currentChapter} / ${book.chapterCount}'
                : '${p.currentChapter}',
          );
        }

        if (parts.isEmpty) {
          return Row(
            children: [
              Expanded(
                child: Text(l.progressNoData, style: style),
              ),
              editButton(p),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
                onTap: () => openEditor(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: parts),
                ),
              ),
            ),
            editButton(p),
          ],
        );
      },
    );
  }
}

void _showProgressSheet(
  BuildContext context,
  Book b,
  Progress? progress,
) {
  unawaited(showProgressEditorSheet(context, book: b, initial: progress));
}

/// App-bar overflow for book-detail manage actions: Kindle import, re-read, delete.
class _BookOverflowMenu extends ConsumerWidget {
  const _BookOverflowMenu(this.b);
  final Book b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final deleteLabel = personalBookDeleteLabel(l, b);
    return RdOverflowMenu<String>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (value) {
        switch (value) {
          case 'kindle':
            unawaited(
              Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => const KindleImportScreen(),
                ),
              ),
            );
          case 'reread':
            unawaited(_rereadBook(context, ref, l, b));
          case 'delete':
            unawaited(_deleteBook(context, ref, l, b));
        }
      },
      items: [
        RdMenuItem(
          value: 'kindle',
          label: l.kindleImportTitle,
          icon: LucideIcons.bookUp,
        ),
        RdMenuItem(
          value: 'reread',
          label: l.actionReread,
          icon: LucideIcons.bookCopy,
        ),
        RdMenuItem(
          value: 'delete',
          label: deleteLabel,
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
  }
}

Future<void> _rereadBook(
  BuildContext context,
  WidgetRef ref,
  AppL10n l,
  Book b,
) async {
  final ok = await showConfirmDialog(
    context: context,
    icon: LucideIcons.bookCopy,
    title: l.rereadConfirmTitle,
    message: l.rereadConfirmBody,
    confirmLabel: l.actionReread,
    confirmIcon: LucideIcons.bookCopy,
  );
  if (!ok || !context.mounted) return;
  final r = await ref.read(bookRepoProvider).reread(b.id);
  if (!context.mounted) return;
  r.fold((nb) {
    ref.invalidate(booksProvider);
    ref.invalidatePersonalStats();
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.rereadSuccess(nb.title),
    );
  }, (f) => showRdFailureToast(context, f));
}

Future<void> _deleteBook(
  BuildContext context,
  WidgetRef ref,
  AppL10n l,
  Book b,
) async {
  await deletePersonalBook(
    context: context,
    ref: ref,
    book: b,
    popOnSuccess: true,
  );
}

/// Locale-aware list price: "24,95 US$" for es/ca/fr/de/it, "$24.95" for en —
/// instead of a raw "24.95 USD" in every language.
String _msrpDisplay(BuildContext context, Book b) {
  final currency = b.msrpCurrency.isEmpty ? 'USD' : b.msrpCurrency;
  return NumberFormat.simpleCurrency(
    locale: Localizations.localeOf(context).toString(),
    name: currency,
  ).format(b.msrp);
}

String _publicationDateDisplay(BuildContext context, Book b) {
  final date = b.publicationDate!;
  final locale = Localizations.localeOf(context).toString();
  return switch (b.publicationDatePrecision) {
    PublicationDatePrecision.year => DateFormat.y(locale).format(date),
    PublicationDatePrecision.month => DateFormat.yMMMM(locale).format(date),
    _ => DateFormat.yMMMMd(locale).format(date),
  };
}

/// Collapsible catalog excerpt/sample, tucked behind a disclosure so it never
/// competes with the synopsis.
class _Excerpt extends StatelessWidget {
  const _Excerpt(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: SectionHeader(
          l.sectionExcerpt,
          padding: EdgeInsets.zero,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: ReadendarTextStyles.editorialBody(
                color: context.colors.fg2,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, ({IconData icon, String label, Widget child})> _metadataByKey(
  BuildContext context,
  Book b, {
  bool showPageTotals = false,
}) {
  final l = AppL10n.of(context);
  final out = <String, ({IconData icon, String label, Widget child})>{};
  if (b.publisher.isNotEmpty) {
    out['publisher'] = (
      icon: LucideIcons.building2,
      label: l.metaPublisher,
      child: Text(b.publisher),
    );
  }
  if (b.publicationDate != null) {
    out['publication_date'] = (
      icon: LucideIcons.calendarDays,
      label: l.metaPublicationDate,
      child: Text(
        _publicationDateDisplay(context, b),
        key: const Key('bookPublicationDateValue'),
      ),
    );
  }
  if (b.edition.isNotEmpty) {
    out['edition'] = (
      icon: LucideIcons.bookCopy,
      label: l.metaEdition,
      child: Text(b.edition),
    );
  }
  if (b.binding.isNotEmpty) {
    out['binding'] = (
      icon: LucideIcons.bookOpen,
      label: l.metaBinding,
      child: Text(bookBindingDisplayName(l, b.binding)),
    );
  }
  if (b.language.isNotEmpty) {
    out['language'] = (
      icon: LucideIcons.globe2,
      label: l.metaLanguage,
      child: Text(bookLanguageDisplayName(l, b.language)),
    );
  }
  if (b.isbnDisplay.isNotEmpty) {
    out['isbn'] = (
      icon: LucideIcons.barcode,
      label: 'ISBN',
      child: Text(b.isbnDisplay),
    );
  }
  if (b.format != null) {
    out['format'] = (
      icon: bookFormatIcon(b.format!),
      label: l.metaFormat,
      child: Text(bookFormatDisplayName(l, b.format!)),
    );
  }
  if (showPageTotals && b.pageCount != null && b.pageCount! > 0) {
    out['pages'] = (
      icon: LucideIcons.fileText,
      label: l.metaPages,
      child: Text('${b.pageCount}'),
    );
  }
  if (showPageTotals && b.chapterCount != null && b.chapterCount! > 0) {
    out['chapters'] = (
      icon: LucideIcons.bookmark,
      label: l.metaChapters,
      child: Text('${b.chapterCount}'),
    );
  }
  if (b.dimensions.isNotEmpty) {
    out['dimensions'] = (
      icon: LucideIcons.ruler,
      label: l.metaDimensions,
      child: Text(b.dimensions),
    );
  }
  if (b.msrp != null) {
    out['msrp'] = (
      icon: LucideIcons.badgeDollarSign,
      label: l.metaMsrp,
      child: Text(_msrpDisplay(context, b)),
    );
  }
  if (b.categoryCodes.isNotEmpty || b.categories.isNotEmpty) {
    out['categories'] = (
      icon: LucideIcons.tags,
      label: l.metaCategories,
      child: Text(
        bookCategoryLabels(
          l,
          b.categoryCodes,
          hasRawCategories: b.categories.isNotEmpty,
        ).join(', '),
      ),
    );
  }
  return out;
}

/// Compact metadata icon tile + divider alignment for detail field rows.
const _kMetaRowIconSize = 24.0;
const _kMetaRowIconGlyphSize = 13.0;
const double _kMetaRowPadding = ReadendarTokens.sp4;
const double _kMetaRowDividerIndent =
    _kMetaRowPadding + _kMetaRowIconSize + ReadendarTokens.sp3;

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.labelLarge?.copyWith(
          color: c.fg2,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ) ??
        TextStyle(
          color: c.fg2,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
    final valueStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: c.fg1,
          height: 1.3,
        ) ??
        TextStyle(color: c.fg1, fontSize: 13, height: 1.3);
    return Padding(
      padding: const EdgeInsets.all(_kMetaRowPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _kMetaRowIconSize,
            height: _kMetaRowIconSize,
            decoration: BoxDecoration(
              color: c.accentSoftBg,
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: _kMetaRowIconGlyphSize,
              color: c.accentSoftFg,
            ),
          ),
          const SizedBox(width: ReadendarTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 1),
                DefaultTextStyle(
                  style: valueStyle,
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient plan launcher + optional soft-tint replan (V2f) + plan history.
/// History is ALWAYS rendered so the planner button does not shift when
/// `bookPlansProvider` resolves.
class _PlanActionsRow extends ConsumerWidget {
  const _PlanActionsRow({
    required this.book,
    this.progress,
  });

  final Book book;
  final Progress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final latestRun = ref.watch(bookPlansProvider(book.id)).value?.firstOrNull;
    final iconShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
    );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _kDetailActionHeight,
            child: GradientButton(
              label: l.planButton,
              icon: LucideIcons.calendarRange,
              onPressed: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => PlanScreen(
                    book: book,
                    progress: progress,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (latestRun != null) ...[
          SizedBox(
            width: _kDetailActionHeight,
            height: _kDetailActionHeight,
            child: IconButton.outlined(
              tooltip: l.planReplanCta,
              icon: const Icon(LucideIcons.calendarSync, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: c.accent,
                backgroundColor: c.accentSoftBg,
                padding: EdgeInsets.zero,
                side: BorderSide(
                  color: Color.alphaBlend(
                    c.accent.withValues(alpha: 0.45),
                    c.line,
                  ),
                ),
                shape: iconShape,
              ),
              onPressed: () => openReplan(
                context,
                ref,
                book: book,
                run: latestRun,
                progress: progress,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: _kDetailActionHeight,
          height: _kDetailActionHeight,
          child: IconButton.outlined(
            tooltip: l.planHistoryViewLink,
            icon: const Icon(LucideIcons.calendarClock, size: 20),
            style: IconButton.styleFrom(
              foregroundColor: c.accent,
              padding: EdgeInsets.zero,
              shape: iconShape,
            ),
            onPressed: () => Navigator.of(context).push(
              rdPageRoute<void>(
                context,
                builder: (_) => PlanHistoryScreen(
                  bookId: book.id,
                  book: book,
                  progress: progress,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Synopsis as a metadata row. Long text stays clamped; "see more" opens a
/// dedicated full-screen view instead of expanding inline.
class _SynopsisMetaRow extends StatelessWidget {
  const _SynopsisMetaRow(this.text);
  final String text;

  static const _collapsedLines = 3;

  void _openFull(BuildContext context) {
    Navigator.of(context).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => _SynopsisScreen(text: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final style = _synopsisTextStyle(context);
    return _MetaRow(
      icon: LucideIcons.alignLeft,
      label: l.sectionSynopsis,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflows = (TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: _collapsedLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth)).didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                key: const Key('bookDetailSynopsisText'),
                style: style,
                maxLines: _collapsedLines,
                overflow: TextOverflow.ellipsis,
              ),
              if (overflows)
                RdButton.plain(
                  onPressed: () => _openFull(context),
                  label: l.actionSeeMore,
                  compact: true,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SynopsisScreen extends StatelessWidget {
  const _SynopsisScreen({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.sectionSynopsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          RdCard(
            key: const Key('bookDetailSynopsisFullCard'),
            child: Text(
              text,
              key: const Key('bookDetailSynopsisFullText'),
              style: _synopsisTextStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _synopsisTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.colors.fg1,
      height: 1.35,
    ) ??
    TextStyle(color: context.colors.fg1, fontSize: 13, height: 1.35);

const _authorSeparator = ', ';

bool _isMissingOwnedBook(Object? error) =>
    error is FailureException && error.failure is NotFoundFailure;

/// Deleted (or otherwise missing) owned book: leave the detail route instead
/// of painting the generic error body.
class _PopMissingOwnedBook extends ConsumerStatefulWidget {
  const _PopMissingOwnedBook({required this.bookId});

  final String bookId;

  @override
  ConsumerState<_PopMissingOwnedBook> createState() =>
      _PopMissingOwnedBookState();
}

class _PopMissingOwnedBookState extends ConsumerState<_PopMissingOwnedBook> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      rememberRemovedPersonalBook(ref, widget.bookId);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
