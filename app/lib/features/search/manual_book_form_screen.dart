// P-06 — Búsqueda / añadir libro (spec §17).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/custom_field_icon.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/form_section.dart';
import 'package:readendar/core/widgets/image_crop.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_dropdown_field.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';
import 'package:readendar/features/library/auto_status_events.dart';
import 'package:readendar/features/library/book_binding_display.dart';
import 'package:readendar/features/library/book_catalog_select_sheet.dart';
import 'package:readendar/features/library/book_category_picker_sheet.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/book_format_display.dart';
import 'package:readendar/features/library/book_language_display.dart';
import 'package:readendar/features/library/rating_review_sheet.dart';
import 'package:readendar/features/library/release_event.dart';
import 'package:readendar/features/search/cover_picker_screen.dart';
import 'package:readendar/features/search/custom_field_decimal.dart';
import 'package:readendar/features/widget/widget_sync.dart';

class ManualBookFormScreen extends ConsumerStatefulWidget {
  const ManualBookFormScreen({
    super.key,
    this.initialHit,
    this.initialBook,
    this.initialStatus,
    this.initialLocalCoverPath,
    this.initialPublicationDate,
    this.initialPublicationDatePrecision = '',
    this.offerReleaseEvent = false,
    this.analyticsSource = 'manual',
  });
  final SearchHit? initialHit;
  final Book? initialBook;

  /// Preferred status when creating (ignored when editing an existing book).
  final String? initialStatus;

  /// Staged local cover uploaded after create (photo crop or tests).
  final String? initialLocalCoverPath;

  /// Prefill publication metadata (e.g. explore upcoming estreno).
  final DateTime? initialPublicationDate;
  final String initialPublicationDatePrecision;

  /// Show the upcoming-release calendar opt-in on this create form.
  final bool offerReleaseEvent;

  /// Analytics `source` logged on successful create.
  final String analyticsSource;

  @override
  ConsumerState<ManualBookFormScreen> createState() =>
      _ManualBookFormScreenState();
}

class _ManualBookFormScreenState extends ConsumerState<ManualBookFormScreen> {
  final _title = TextEditingController();
  final _authors = TextEditingController();
  final _isbn = TextEditingController();
  final _pages = TextEditingController();
  final _chapters = TextEditingController();
  final _publisher = TextEditingController();
  final _description = TextEditingController();
  final _edition = TextEditingController();
  String _binding = '';
  String _language = '';
  final _dimensions = TextEditingController();
  final _msrp = TextEditingController();
  final _msrpCurrency = TextEditingController();
  // Current reading progress (distinct from the page/chapter *totals* above).
  final _progPage = TextEditingController();
  final _progPct = TextEditingController();
  final _progChapter = TextEditingController();
  final Map<String, TextEditingController> _customText = {};
  final Map<String, Object?> _customChoice = {};
  List<CustomFieldDefinition> _customDefinitions = const [];
  List<BookDetailFieldLayoutItem> _layout = const [];
  late final Future<void> _customFieldsReady;
  Failure? _customFieldsFailure;

  bool _saving = false;
  String _coverUrl = '';
  // Staged crop, uploaded only on Save. Never upload on
  // pick: a cancel / mid-edit replace would orphan the blob forever.
  String? _localCoverPath;
  List<String> _categoryCodes = const [];
  String? _format;
  DateTime? _publicationDate;
  String _publicationDatePrecision = '';
  bool _offerReleaseEvent = true;
  String _status = BookStatus.pending;
  double? _rating;
  String _review = '';
  // Per-section collapse state (all sections share the same expand affordance).
  bool _detailsOpen = true;
  bool _trackingOpen = true;
  bool _metadataOpen = true;
  // Once metadata is persisted (create succeeds), we hold the id so re-saving
  // after a failed personal-field patch updates instead of creating a dupe.
  String? _persistedId;
  // Guards the progress page↔percentage two-way sync against re-entrant updates.
  bool _syncing = false;

  String? _formError;
  String? _titleError;
  String? _authorsError;
  String? _pagesError;
  String? _chaptersError;
  String? _progressError;

  // Baselines captured at load so each personal patch only fires when changed.
  String _initialStatus = BookStatus.pending;
  double? _initialRating;
  String _initialReview = '';
  String _initialProgPage = '';
  String _initialProgPct = '';
  String _initialProgChapter = '';
  String _syncBaseline = '';
  String _progressBaseline = '';
  String _customBaseline = '';

  bool get _isReview => widget.initialHit != null;
  bool get _isEdit => widget.initialBook != null;

  @override
  void initState() {
    super.initState();
    _localCoverPath = widget.initialLocalCoverPath;
    final b = widget.initialBook;
    _customFieldsReady = _loadCustomFields();
    if (b != null) {
      _title.text = b.title;
      _authors.text = b.authors.join(', ');
      _isbn.text = b.isbnDisplay;
      _pages.text = b.pageCount?.toString() ?? '';
      _chapters.text = b.chapterCount?.toString() ?? '';
      _publisher.text = b.publisher;
      _description.text = b.description;
      _edition.text = b.edition;
      _binding = canonicalBookBindingCode(b.binding) ?? b.binding.trim();
      _language = canonicalBookLanguageCode(b.language) ?? b.language.trim();
      _dimensions.text = b.dimensions;
      _msrp.text = b.msrp?.toString() ?? '';
      _msrpCurrency.text = b.msrpCurrency;
      _coverUrl = b.coverUrl;
      _categoryCodes = b.categoryCodes;
      _format = b.format;
      _publicationDate = b.publicationDate;
      _publicationDatePrecision = b.publicationDatePrecision;
      _status = b.status;
      _rating = b.rating;
      _review = b.reviewMarkdown;
      _persistedId = b.id;
      _initialStatus = b.status;
      _initialRating = b.rating;
      _initialReview = b.reviewMarkdown;
      _loadProgress(b.id);
    } else {
      final h = widget.initialHit;
      if (h != null) {
        _title.text = h.title;
        _authors.text = h.authors.join(', ');
        _isbn.text = h.isbn;
        _pages.text = h.pageCount?.toString() ?? '';
        _publisher.text = h.publisher;
        _description.text = h.description;
        _coverUrl = h.coverUrl;
        _language = canonicalBookLanguageCode(h.language) ?? h.language.trim();
        _binding = canonicalBookBindingCode(h.binding) ?? h.binding.trim();
        _edition.text = h.edition;
        _format = h.format;
        if (h.categoryCodes.isNotEmpty) {
          _categoryCodes = h.categoryCodes;
        } else if (h.categories.isNotEmpty) {
          _categoryCodes = h.categories
              .where(bookCategoryCodes.contains)
              .toList(growable: false);
        }
        if (h.publicationDate != null) {
          _publicationDate = h.publicationDate;
          _publicationDatePrecision = h.publicationDatePrecision;
        }
      }
      if (widget.initialPublicationDate != null) {
        _publicationDate = widget.initialPublicationDate;
        _publicationDatePrecision = widget.initialPublicationDatePrecision;
      }
      final seedStatus = widget.initialStatus;
      if (seedStatus != null && BookStatus.all.contains(seedStatus)) {
        _status = seedStatus;
        _initialStatus = seedStatus;
      }
    }
    _syncBaseline = _syncFingerprint();
    _progressBaseline = _progressFingerprint();
    _customBaseline = _customFingerprint();
    for (final controller in _textControllers) {
      controller.addListener(_onEditableChanged);
    }
  }

  List<TextEditingController> get _textControllers => [
    _title,
    _authors,
    _isbn,
    _pages,
    _chapters,
    _publisher,
    _description,
    _edition,
    _dimensions,
    _msrp,
    _msrpCurrency,
    _progPage,
    _progPct,
    _progChapter,
  ];

  void _onEditableChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Create/review always allow Save. Edit stays disabled until a field differs
  /// from the loaded book (reverting a change disables Save again).
  bool get _canSave {
    if (!_isEdit) return true;
    return _localCoverPath != null ||
        _syncFingerprint() != _syncBaseline ||
        _progressDirtyForSave ||
        _customFingerprint() != _customBaseline;
  }

  /// `_save` skips a progress PUT when every current-progress field is empty,
  /// so clearing those fields must not enable Save.
  bool get _progressDirtyForSave {
    if (_progressFingerprint() == _progressBaseline) return false;
    return _progPage.text.trim().isNotEmpty ||
        _progPct.text.trim().isNotEmpty ||
        _progChapter.text.trim().isNotEmpty;
  }

  /// Metadata + personal fields that `_save` actually PATCHes on edit.
  /// Notes live on annotations, not this form.
  String _syncFingerprint() => [
    _title.text.trim(),
    _authors.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\u001f'),
    _isbn.text.trim(),
    _pages.text.trim(),
    _chapters.text.trim(),
    _publisher.text.trim(),
    _description.text.trim(),
    _edition.text.trim(),
    _binding,
    _language,
    _dimensions.text.trim(),
    _msrp.text.trim(),
    _msrpCurrency.text.trim(),
    _coverUrl,
    _categoryCodes.join('\u001f'),
    _format ?? '',
    _publicationDate?.toUtc().toIso8601String() ?? '',
    _publicationDatePrecision,
    _status,
    _rating?.toString() ?? '',
    _review,
  ].join('\u0000');

  String _progressFingerprint() => [
    _progPage.text.trim(),
    _progPct.text.trim(),
    _progChapter.text.trim(),
  ].join('\u0000');

  String _customFingerprint() {
    final textKeys = _customText.keys.toList()..sort();
    final choiceKeys = _customChoice.keys.toList()..sort();
    return [
      for (final key in textKeys) '$key=${_customText[key]?.text.trim() ?? ''}',
      for (final key in choiceKeys) '$key=${_customChoice[key]}',
    ].join('\u0000');
  }

  Future<void> _loadCustomFields() async {
    final repo = ref.read(customFieldRepoProvider);
    final definitionsResult = await repo.listDefinitions();
    final layoutResult = await repo.listLayout();
    final valuesResult = widget.initialBook == null
        ? null
        : await repo.listForBook(widget.initialBook!.id);
    if (!mounted) return;
    if (definitionsResult.value == null) {
      setState(() => _customFieldsFailure = definitionsResult.failure);
      return;
    }
    if (valuesResult?.isErr == true) {
      setState(() => _customFieldsFailure = valuesResult!.failure);
      return;
    }
    final values = {
      for (final value in valuesResult?.value ?? const <BookCustomField>[])
        value.fieldId: value.value,
    };
    for (final definition in definitionsResult.value!) {
      final value = values[definition.id];
      if (definition.type == CustomFieldType.boolean) {
        _customChoice[definition.id] = value?.boolean;
      } else if (definition.type == CustomFieldType.singleSelect) {
        _customChoice[definition.id] = value?.optionId;
      } else {
        _customText[definition.id] = TextEditingController(
          text: switch (definition.type) {
            CustomFieldType.number => value?.decimal ?? '',
            CustomFieldType.datetime =>
              value?.instant?.toLocal().toIso8601String() ?? '',
            _ => value?.text ?? '',
          },
        );
      }
    }
    for (final controller in _customText.values) {
      controller.addListener(_onEditableChanged);
    }
    setState(() {
      _customDefinitions = definitionsResult.value!;
      _layout = layoutResult.value ?? _fallbackLayout(definitionsResult.value!);
      _customBaseline = _customFingerprint();
    });
  }

  List<BookDetailFieldLayoutItem> _fallbackLayout(
    List<CustomFieldDefinition> definitions,
  ) => [
    for (final definition in definitions)
      BookDetailFieldLayoutItem(
        key: definition.id,
        kind: BookDetailFieldKind.custom,
        hidden: false,
      ),
    for (final key in bookDetailSystemFieldKeys)
      BookDetailFieldLayoutItem(
        key: key,
        kind: BookDetailFieldKind.system,
        hidden: false,
      ),
  ];

  List<BookDetailFieldLayoutItem> get _resolvedLayout {
    if (_layout.isNotEmpty) return _layout;
    return _fallbackLayout(_customDefinitions);
  }

  /// Loads the caller's saved progress so the form opens pre-filled (edit only).
  Future<void> _loadProgress(String bookId) async {
    final r = await ref.read(progressRepoProvider).get(bookId);
    if (!mounted) return;
    r.fold((p) {
      // Keep in-flight edits: applying the GET would wipe them and recapture
      // a baseline that makes Save look clean.
      if (_progressFingerprint() != _progressBaseline) return;
      setState(() {
        _progPage.text = p.currentPage?.toString() ?? '';
        _progPct.text = p.currentPercentage?.toString() ?? '';
        _progChapter.text = p.currentChapter?.toString() ?? '';
        _initialProgPage = _progPage.text;
        _initialProgPct = _progPct.text;
        _initialProgChapter = _progChapter.text;
        _progressBaseline = _progressFingerprint();
      });
    }, (_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _authors.dispose();
    _isbn.dispose();
    _pages.dispose();
    _chapters.dispose();
    _publisher.dispose();
    _description.dispose();
    _edition.dispose();
    _dimensions.dispose();
    _msrp.dispose();
    _msrpCurrency.dispose();
    _progPage.dispose();
    _progPct.dispose();
    _progChapter.dispose();
    for (final controller in _customText.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Keep progress page and percentage in sync when a total page count is
  /// present (read live from the totals field). Mirrors the detail sheet.
  void _onProgPageChanged(String value) {
    if (_syncing) return;
    final total = int.tryParse(_pages.text.trim());
    if (total == null || total <= 0) return;
    _syncing = true;
    final page = int.tryParse(value.trim());
    if (page != null && page >= 0) {
      _progPct.text = ((page / total) * 100).round().clamp(0, 100).toString();
    } else {
      _progPct.clear();
    }
    _syncing = false;
    setState(() {});
  }

  void _onProgPctChanged(String value) {
    if (_syncing) return;
    final total = int.tryParse(_pages.text.trim());
    if (total == null || total <= 0) return;
    _syncing = true;
    final pct = int.tryParse(value.trim());
    if (pct != null && pct >= 0 && pct <= 100) {
      _progPage.text = ((pct / 100) * total).round().toString();
    } else {
      _progPage.clear();
    }
    _syncing = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? l.bookEditInfo
              : _isReview
              ? l.actionAddBook
              : l.searchCreateManually,
        ),
        actions: [
          FormSaveAction(
            saving: _saving,
            onPressed: _canSave ? _save : null,
            tooltip: _isReview ? l.actionAddBook : l.actionSave,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.offerReleaseEvent &&
                (_publicationDate ?? widget.initialPublicationDate) !=
                    null) ...[
              ExploreReleaseOfferBanner(
                dateLabel: formatExploreReleaseOfferDate(
                  _publicationDate ?? widget.initialPublicationDate!,
                  precision: _publicationDatePrecision.isNotEmpty
                      ? _publicationDatePrecision
                      : widget.initialPublicationDatePrecision,
                ),
                value: _offerReleaseEvent,
                onChanged: (v) => setState(() => _offerReleaseEvent = v),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickCover,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BookCover(
                      title: _title.text,
                      author: _authors.text.split(',').firstOrNull?.trim(),
                      coverUrl: _coverUrl,
                      localImagePath: _localCoverPath,
                    ),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Material(
                        color: context.colors.accent,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _saving ? null : _pickCover,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              LucideIcons.imagePlus,
                              size: 18,
                              color: context.colors.fgOnAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_localCoverPath != null) ...[
              const SizedBox(height: 8),
              Text(
                l.imagePendingUpload,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.colors.fg2),
              ),
            ],
            const SizedBox(height: 16),
            if (_formError != null) ...[
              RdCard(
                backgroundColor: context.colors.dangerSoftBg,
                child: Text(
                  _formError!,
                  style: TextStyle(color: context.colors.dangerSoftFg),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_customFieldsFailure != null) ...[
              RdCard(
                backgroundColor: context.colors.warningSoftBg,
                child: Text(
                  l.customFieldsUnavailable,
                  style: TextStyle(color: context.colors.warningSoftFg),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FormSection(
              title: l.bookSectionDetails,
              open: _detailsOpen,
              onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
              children: [
                RdTextField(
                  controller: _title,
                  decoration: _fieldDecoration(
                    label: l.metaTitle,
                    hint: l.bookOptionalHint,
                    error: _titleError,
                  ),
                ),
                const SizedBox(height: 12),
                RdTextField(
                  controller: _authors,
                  decoration: _fieldDecoration(
                    label: l.metaAuthors,
                    hint: l.metaAuthorsHint,
                    error: _authorsError,
                  ),
                ),
                const SizedBox(height: 12),
                _statusCard(l),
                const SizedBox(height: 12),
                _ratingCard(l),
              ],
            ),
            const SizedBox(height: 8),
            FormSection(
              title: l.bookSectionTracking,
              open: _trackingOpen,
              onToggle: () => setState(() => _trackingOpen = !_trackingOpen),
              children: [
                _progressFields(l),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RdTextField(
                        controller: _pages,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: _fieldDecoration(
                          label: l.metaPagesTotal,
                          hint: l.bookOptionalHint,
                          error: _pagesError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RdTextField(
                        controller: _chapters,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(
                          label: l.metaChaptersTotal,
                          hint: l.bookOptionalHint,
                          error: _chaptersError,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final detailFields = _layoutOrderedDetailFields(l);
                if (detailFields.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    FormSection(
                      title: l.bookSectionMore,
                      open: _metadataOpen,
                      onToggle: () =>
                          setState(() => _metadataOpen = !_metadataOpen),
                      children: detailFields,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _layoutOrderedDetailFields(AppL10n l) {
    final definitions = {
      for (final definition in _customDefinitions) definition.id: definition,
    };
    final fields = <Widget>[];
    for (final item in _resolvedLayout) {
      if (item.hidden) continue;
      // Page/chapter totals live permanently under Tracking.
      if (item.key == 'pages' || item.key == 'chapters') continue;
      final Widget? field;
      if (item.kind == BookDetailFieldKind.custom) {
        final definition = definitions[item.key];
        if (definition == null) continue;
        field = _customFieldInput(definition, l);
      } else {
        field = _systemFieldInput(item.key, l);
      }
      if (field == null) continue;
      fields.add(field);
    }
    if (fields.isEmpty) return fields;
    return [
      for (var i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        fields[i],
      ],
    ];
  }

  Widget? _systemFieldInput(String key, AppL10n l) => switch (key) {
    'synopsis' => RdTextField(
      controller: _description,
      maxLines: 4,
      decoration: _fieldDecoration(
        label: l.metaSynopsis,
        hint: l.bookOptionalHint,
      ),
    ),
    'publisher' => RdTextField(
      controller: _publisher,
      decoration: _fieldDecoration(
        label: l.metaPublisher,
        hint: l.bookOptionalHint,
      ),
    ),
    'publication_date' => RdFormSelectField(
      label: l.metaPublicationDate,
      hint: l.bookOptionalHint,
      valueText: _publicationDateDisplay(),
      trailing: _publicationDate == null
          ? const Icon(LucideIcons.calendarDays)
          : RdIconButton(
              tooltip: l.actionClear,
              onPressed: () => setState(() {
                _publicationDate = null;
                _publicationDatePrecision = '';
              }),
              icon: LucideIcons.x,
            ),
      onTap: _pickPublicationDate,
    ),
    'edition' => RdTextField(
      controller: _edition,
      decoration: _fieldDecoration(
        label: l.metaEdition,
        hint: l.bookOptionalHint,
      ),
    ),
    'binding' => RdDropdownField<String>(
      key: const Key('bookBindingSelector'),
      value: _binding,
      label: l.metaBinding,
      items: [
        RdDropdownItem(
          value: '',
          label: l.bookOptionalHint,
          icon: LucideIcons.circleDashed,
        ),
        for (final code in bookBindingCodes)
          RdDropdownItem(
            value: code,
            label: bookBindingDisplayName(l, code),
            icon: LucideIcons.bookOpen,
          ),
        if (_binding.isNotEmpty && canonicalBookBindingCode(_binding) == null)
          RdDropdownItem(
            value: _binding,
            label: _binding,
            icon: LucideIcons.bookOpen,
          ),
      ],
      onChanged: (value) => setState(() => _binding = value ?? ''),
    ),
    'format' => RdDropdownField<String>(
      value: _format ?? '',
      label: l.metaFormat,
      items: [
        RdDropdownItem(
          value: '',
          label: l.bookOptionalHint,
          icon: LucideIcons.circleDashed,
        ),
        RdDropdownItem(
          value: BookFormat.physical,
          label: bookFormatDisplayName(l, BookFormat.physical),
          icon: bookFormatIcon(BookFormat.physical),
        ),
        RdDropdownItem(
          value: BookFormat.ebook,
          label: bookFormatDisplayName(l, BookFormat.ebook),
          icon: bookFormatIcon(BookFormat.ebook),
        ),
        RdDropdownItem(
          value: BookFormat.audiobook,
          label: bookFormatDisplayName(l, BookFormat.audiobook),
          icon: bookFormatIcon(BookFormat.audiobook),
        ),
        RdDropdownItem(
          value: BookFormat.other,
          label: bookFormatDisplayName(l, BookFormat.other),
          icon: bookFormatIcon(BookFormat.other),
        ),
      ],
      onChanged: (value) => setState(
        () => _format = (value == null || value.isEmpty) ? null : value,
      ),
    ),
    'language' => RdFormSelectField(
      key: const Key('bookLanguageSelector'),
      label: l.metaLanguage,
      hint: l.bookOptionalHint,
      valueText: _language.isEmpty ? '' : bookLanguageDisplayName(l, _language),
      leading: Icon(
        LucideIcons.globe2,
        size: 18,
        color: context.colors.accentSoftFg,
      ),
      trailing: Icon(
        LucideIcons.chevronDown,
        size: 16,
        color: context.colors.fg3,
      ),
      onTap: _pickLanguage,
    ),
    'isbn' => RdTextField(
      controller: _isbn,
      decoration: _fieldDecoration(
        label: l.metaIsbn,
        hint: l.bookOptionalHint,
      ),
    ),
    'dimensions' => RdTextField(
      controller: _dimensions,
      decoration: _fieldDecoration(
        label: l.metaDimensions,
        hint: l.bookOptionalHint,
      ),
    ),
    'msrp' => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: RdTextField(
            controller: _msrp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecoration(
              label: l.metaMsrp,
              hint: l.bookOptionalHint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RdTextField(
            controller: _msrpCurrency,
            textCapitalization: TextCapitalization.characters,
            decoration: _fieldDecoration(
              label: l.metaMsrpCurrency,
              hint: 'USD',
            ),
          ),
        ),
      ],
    ),
    'categories' => RdFormSelectField(
      label: l.metaCategories,
      hint: l.bookOptionalHint,
      valueText: bookCategoryLabels(l, _categoryCodes).join(', '),
      trailing: const Icon(LucideIcons.tags),
      onTap: _pickCategories,
    ),
    _ => null,
  };

  String _publicationDateDisplay() {
    final date = _publicationDate;
    if (date == null) return '';
    final locale = Localizations.localeOf(context).toString();
    final local = date.toLocal();
    return switch (_publicationDatePrecision) {
      PublicationDatePrecision.year => DateFormat.y(locale).format(local),
      PublicationDatePrecision.month => DateFormat.yMMMM(locale).format(local),
      _ => DateFormat.yMMMd(locale).format(local),
    };
  }

  Future<void> _pickPublicationDate() async {
    final initial = _publicationDate?.toLocal() ?? DateTime.now();
    final date = await showRdDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1400),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _publicationDate = DateTime.utc(date.year, date.month, date.day);
      _publicationDatePrecision = PublicationDatePrecision.day;
    });
  }

  Future<void> _pickLanguage() async {
    final l = AppL10n.of(context);
    final codes = bookLanguageCodesSorted(l);
    final selected = await showBookCatalogSelectSheet(
      context: context,
      title: l.metaLanguage,
      selected: _language,
      emptyLabel: l.bookOptionalHint,
      options: [
        for (final code in codes)
          BookCatalogSelectOption(
            value: code,
            label: bookLanguageDisplayName(l, code),
            icon: LucideIcons.globe2,
          ),
        if (_language.isNotEmpty &&
            canonicalBookLanguageCode(_language) == null)
          BookCatalogSelectOption(
            value: _language,
            label: _language,
            icon: LucideIcons.globe2,
          ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _language = selected);
  }

  Future<void> _pickCategories() async {
    final result = await showBookCategoryPickerSheet(
      context: context,
      selected: _categoryCodes,
    );
    if (result == null || !mounted) return;
    setState(() => _categoryCodes = result);
  }

  Widget _customFieldInput(CustomFieldDefinition definition, AppL10n l) {
    if (definition.type == CustomFieldType.boolean) {
      final selected = switch (_customChoice[definition.id] as bool?) {
        true => 'yes',
        false => 'no',
        null => 'unset',
      };
      return RdDropdownField<String>(
        value: selected,
        label: definition.name,
        items: [
          RdDropdownItem(value: 'unset', label: l.bookOptionalHint),
          RdDropdownItem(value: 'yes', label: l.customFieldsYes),
          RdDropdownItem(value: 'no', label: l.customFieldsNo),
        ],
        onChanged: (value) => setState(
          () => _customChoice[definition.id] = switch (value) {
            'yes' => true,
            'no' => false,
            _ => null,
          },
        ),
      );
    }
    if (definition.type == CustomFieldType.singleSelect) {
      return RdDropdownField<String>(
        value: (_customChoice[definition.id] as String?) ?? '',
        label: definition.name,
        items: [
          RdDropdownItem(value: '', label: l.bookOptionalHint),
          ...definition.options.map(
            (option) => RdDropdownItem(
              value: option.id,
              label: option.label,
            ),
          ),
        ],
        onChanged: (value) => setState(
          () => _customChoice[definition.id] = value?.isEmpty == true
              ? null
              : value,
        ),
      );
    }
    if (definition.type == CustomFieldType.datetime) {
      final parsed = DateTime.tryParse(_customText[definition.id]?.text ?? '');
      final showTime = customFieldShowsTime(definition.textMode);
      return RdFormSelectField(
        label: definition.name,
        hint: l.bookOptionalHint,
        valueText: parsed == null
            ? ''
            : () {
                final locale = Localizations.localeOf(context).toString();
                final local = parsed.toLocal();
                if (!showTime) {
                  return DateFormat.yMMMd(locale).format(local);
                }
                return DateFormat.yMMMd(locale).add_jm().format(local);
              }(),
        trailing: parsed == null
            ? const Icon(LucideIcons.calendarClock)
            : RdIconButton(
                tooltip: l.actionClear,
                onPressed: () => setState(
                  () => _customText[definition.id]!.clear(),
                ),
                icon: LucideIcons.x,
              ),
        onTap: () => _pickCustomDateTime(
          definition.id,
          parsed,
          showTime: showTime,
        ),
      );
    }
    return RdTextField(
      controller: _customText[definition.id],
      maxLines: definition.textMode == 'multiline' ? 4 : 1,
      keyboardType: definition.type == CustomFieldType.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : definition.type == CustomFieldType.datetime
          ? TextInputType.datetime
          : TextInputType.text,
      decoration: _fieldDecoration(
        label: definition.name,
        hint: l.bookOptionalHint,
      ),
    );
  }

  Future<void> _pickCustomDateTime(
    String fieldId,
    DateTime? current, {
    bool showTime = true,
  }) async {
    final now = DateTime.now();
    final initial = current?.toLocal() ?? now;
    final date = await showRdDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    var hour = 0;
    var minute = 0;
    if (showTime) {
      final time = await showRdTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
      hour = time.hour;
      minute = time.minute;
    }
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    setState(() => _customText[fieldId]!.text = value.toIso8601String());
  }

  List<CustomFieldChange> _customFieldChanges() =>
      _customDefinitions.map((definition) {
        CustomFieldValue? value;
        if (definition.type == CustomFieldType.boolean) {
          final choice = _customChoice[definition.id] as bool?;
          if (choice != null) {
            value = CustomFieldValue(kind: definition.type, boolean: choice);
          }
        } else if (definition.type == CustomFieldType.singleSelect) {
          final option = _customChoice[definition.id] as String?;
          if (option != null) {
            value = CustomFieldValue(kind: definition.type, optionId: option);
          }
        } else {
          final raw = _customText[definition.id]?.text.trim() ?? '';
          if (raw.isNotEmpty) {
            value = switch (definition.type) {
              CustomFieldType.number => CustomFieldValue(
                kind: definition.type,
                decimal: normalizeCustomFieldDecimal(
                  raw,
                  Localizations.localeOf(context),
                ),
              ),
              CustomFieldType.datetime => CustomFieldValue(
                kind: definition.type,
                instant: DateTime.tryParse(raw),
              ),
              _ => CustomFieldValue(kind: definition.type, text: raw),
            };
          }
        }
        return CustomFieldChange(definition.id, value);
      }).toList();

  /// Status field card — identical to the book-detail status card; tapping opens
  /// the same option-selector sheet but writes to local form state.
  Widget _statusCard(AppL10n l) => BookFieldCard(
    leading: BookFieldLeadingIcon(
      background: bookStatusTint(_status, context.colors),
      icon: bookStatusIcon(_status),
      color: bookStatusColor(_status, context.colors),
    ),
    title: l.statusLabel,
    subtitle: Text(bookStatusLabel(l, _status)),
    onTap: () async {
      final next = await showOptionSelectorSheet<String>(
        context: context,
        label: l.statusLabel,
        value: _status,
        items: BookStatus.all
            .map(
              (s) => OptionSelectorItem<String>(
                value: s,
                label: bookStatusLabel(l, s),
                icon: bookStatusIcon(s),
                color: bookStatusColor(s, context.colors),
              ),
            )
            .toList(),
      );
      if (next != null) setState(() => _status = next);
    },
  );

  /// Rating field card — same stars/number/review row as book detail; tapping
  /// opens the shared rating+review sheet and writes to local form state.
  Widget _ratingCard(AppL10n l) {
    return BookFieldCard(
      leading: BookFieldLeadingIcon(
        background: context.colors.warningSoftBg,
        icon: Icons.star_rounded,
        color: context.colors.warningSoftFg,
        iconSize: 20,
      ),
      title: l.reviewTitle,
      subtitle: BookRatingDisplay(
        rating: _rating,
        review: _review,
        showEditHint: true,
      ),
      onTap: () async {
        final res = await showRatingReviewSheet(
          context,
          currentRating: _rating,
          currentReview: _review,
        );
        if (res == null || !res.save) return;
        setState(() {
          _rating = res.rating;
          _review = res.review;
        });
      },
    );
  }

  /// Current-progress sub-block (page / % with two-way sync, chapter, bar).
  Widget _progressFields(AppL10n l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(l.progressCurrentLabel),
        const SizedBox(height: 10),
        if (_progressPercent != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: _progressPercent! / 100,
              backgroundColor: context.colors.accentSoftBg,
              color: context.colors.accent,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RdTextField(
                controller: _progPage,
                keyboardType: TextInputType.number,
                onChanged: _onProgPageChanged,
                decoration: _fieldDecoration(
                  label: l.progressCurrentPageLabel,
                  hint: l.bookOptionalHint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RdTextField(
                controller: _progPct,
                keyboardType: TextInputType.number,
                onChanged: _onProgPctChanged,
                decoration: _fieldDecoration(
                  label: l.progressPercentageLabel,
                  hint: l.bookOptionalHint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RdTextField(
          controller: _progChapter,
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration(
            label: l.progressChapterLabel,
            hint: l.bookOptionalHint,
          ),
        ),
        if (_progressError != null) ...[
          const SizedBox(height: 8),
          Text(_progressError!, style: TextStyle(color: context.colors.danger)),
        ],
      ],
    );
  }

  /// Live progress percent for the inline bar: explicit percentage if entered,
  /// otherwise derived from current page ÷ total pages.
  int? get _progressPercent {
    final pct = int.tryParse(_progPct.text.trim());
    if (pct != null) return pct.clamp(0, 100);
    final page = int.tryParse(_progPage.text.trim());
    final total = int.tryParse(_pages.text.trim());
    if (page == null || total == null || total <= 0) return null;
    return ((page / total) * 100).round().clamp(0, 100);
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    String? error,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    floatingLabelBehavior: FloatingLabelBehavior.always,
  );

  Future<void> _pickCover() async {
    final l = AppL10n.of(context);
    // Search + upload on create and edit. Upload only stages a local crop:
    // object storage is touched on Save once a book id exists.
    final upload = await showRdMenu<bool>(
      context: context,
      items: [
        RdMenuItem(
          value: false,
          label: l.coverSearchOption,
          icon: LucideIcons.search,
        ),
        RdMenuItem(
          value: true,
          label: l.coverUploadOption,
          icon: LucideIcons.imagePlus,
        ),
      ],
    );
    if (upload == null || !mounted) return;
    if (upload) {
      await _stageLocalCover();
      return;
    }
    final hit = await Navigator.of(context).push<SearchHit>(
      rdPageRoute<SearchHit>(
        context,
        builder: (_) => CoverPickerScreen(
          query: _title.text.trim(),
          author: _authors.text.split(',').firstOrNull?.trim() ?? '',
        ),
      ),
    );
    if (hit == null || hit.coverUrl.isEmpty || !mounted) return;
    setState(() {
      _localCoverPath = null;
      _coverUrl = hit.coverUrl;
    });
  }

  /// Crops a camera/gallery photo and keeps it local until Save.
  Future<void> _stageLocalCover() async {
    final path = await pickAndCropImage(context, aspectRatio: cropBookCover);
    if (path == null || !mounted) return;
    setState(() => _localCoverPath = path);
  }

  /// Copies [_localCoverPath] into the book cover sidecar (or the leftover
  /// upload adapter in tests without a local store). On success clears the
  /// staged path and sets [_coverUrl].
  Future<String?> _uploadStagedCover(String bookId) async {
    final path = _localCoverPath;
    if (path == null) return _coverUrl;
    final l = AppL10n.of(context);
    final uploaded = await ref
        .read(uploadRepoProvider)
        .uploadBookCover(bookId, path);
    if (!mounted) return null;
    final url = uploaded.value;
    if (url == null) {
      setState(() {
        _saving = false;
        _formError = localizedFailureMessage(l, uploaded.failure!);
      });
      return null;
    }
    _coverUrl = url;
    _localCoverPath = null;
    return url;
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    await _customFieldsReady;
    if (!mounted) return;
    final title = _title.text.trim();
    final authors = _authors.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final pagesText = _pages.text.trim();
    final chaptersText = _chapters.text.trim();
    final pageCount = pagesText.isEmpty ? null : int.tryParse(pagesText);
    final chapterCount = chaptersText.isEmpty
        ? null
        : int.tryParse(chaptersText);
    final isbn = _isbn.text.trim();
    final publisher = _publisher.text.trim();
    final description = _description.text.trim();
    final language = canonicalBookLanguageStorage(_language) ?? '';
    final edition = _edition.text.trim();
    final binding = canonicalBookBindingStorage(_binding) ?? '';
    final dimensions = _dimensions.text.trim();
    final msrpCurrency = _msrpCurrency.text.trim().toUpperCase();
    final msrpText = _msrp.text.trim();
    final msrp = msrpText.isEmpty ? null : double.tryParse(msrpText);

    final progPageText = _progPage.text.trim();
    final progPctText = _progPct.text.trim();
    final progChapterText = _progChapter.text.trim();
    final progPage = progPageText.isEmpty ? null : int.tryParse(progPageText);
    final progPct = progPctText.isEmpty ? null : int.tryParse(progPctText);
    final progChapter = progChapterText.isEmpty
        ? null
        : int.tryParse(progChapterText);

    setState(() {
      _formError = null;
      _titleError = title.isEmpty ? l.bookTitleRequired : null;
      _authorsError = authors.isEmpty ? l.bookAuthorsRequired : null;
      _pagesError =
          pagesText.isNotEmpty && (pageCount == null || pageCount <= 0)
          ? l.bookPagesInvalid
          : null;
      _chaptersError =
          chaptersText.isNotEmpty && (chapterCount == null || chapterCount <= 0)
          ? l.eventTargetChapterInvalid
          : null;
      _progressError = _validateProgress(
        l,
        progPage: progPage,
        progPageText: progPageText,
        progPct: progPct,
        progPctText: progPctText,
        progChapter: progChapter,
        progChapterText: progChapterText,
      );
    });
    if (_titleError != null ||
        _authorsError != null ||
        _pagesError != null ||
        _chaptersError != null ||
        _progressError != null) {
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(bookRepoProvider);

    // 1) Metadata. Create first when needed (upload requires a book id). For
    // edit, upload any staged cover *before* the full PATCH so we never send a
    // cover-only body (backend Update is a full replace and would wipe fields).
    final existingId = _persistedId;
    final justCreated = existingId == null;
    late final Book book;
    if (justCreated) {
      final metaRes = await repo.create(
        title: title,
        authors: authors,
        coverUrl: _coverUrl,
        isbn: isbn,
        pageCount: pageCount,
        chapterCount: chapterCount,
        publisher: publisher.isEmpty ? null : publisher,
        description: description.isEmpty ? null : description,
        language: language.isEmpty ? null : language,
        categories: _categoryCodes.isEmpty ? null : _categoryCodes,
        format: _format,
        edition: edition.isEmpty ? null : edition,
        binding: binding.isEmpty ? null : binding,
        dimensions: dimensions.isEmpty ? null : dimensions,
        msrp: msrp,
        msrpCurrency: msrpCurrency.isEmpty ? null : msrpCurrency,
        publicationDate: _publicationDate,
        publicationDatePrecision: _publicationDatePrecision.isEmpty
            ? null
            : _publicationDatePrecision,
        initialStatus: _status,
        customFieldChanges: _customFieldChanges(),
      );
      if (!mounted) return;
      final created = metaRes.value;
      if (created == null) {
        setState(() {
          _saving = false;
          _formError = localizedFailureMessage(l, metaRes.failure!);
        });
        return;
      }
      _persistedId = created.id;
      unawaited(
        ref
            .read(analyticsProvider)
            .logBookAdded(source: widget.analyticsSource),
      );

      // Staged custom cover: upload, then full update with the new URL.
      if (_localCoverPath != null) {
        if (await _uploadStagedCover(created.id) == null) return;
        final coverRes = await repo.update(
          created.id,
          title: created.title,
          authors: created.authors,
          coverUrl: _coverUrl,
          isbn: created.isbn13.isNotEmpty ? created.isbn13 : created.isbn10,
          pageCount: created.pageCount,
          chapterCount: created.chapterCount,
          publisher: created.publisher,
          description: created.description,
          language: created.language,
          categories: created.categoryCodes,
          format: created.format,
          edition: created.edition,
          binding: created.binding,
          dimensions: created.dimensions,
          msrp: created.msrp,
          msrpCurrency: created.msrpCurrency,
          publicationDate: created.publicationDate,
          publicationDatePrecision: created.publicationDatePrecision,
          customFieldChanges: _customFieldChanges(),
        );
        if (!mounted) return;
        if (coverRes.failure != null) {
          setState(() {
            _saving = false;
            _formError = localizedFailureMessage(l, coverRes.failure!);
          });
          return;
        }
        book = coverRes.value ?? created;
      } else {
        book = created;
      }
    } else {
      if (_localCoverPath != null) {
        if (await _uploadStagedCover(existingId) == null) return;
      }
      final metaRes = await repo.update(
        existingId,
        title: title,
        authors: authors,
        coverUrl: _coverUrl,
        isbn: isbn,
        pageCount: pageCount,
        chapterCount: chapterCount,
        publisher: publisher,
        description: description,
        language: language,
        categories: _categoryCodes,
        format: _format,
        edition: edition,
        binding: binding,
        dimensions: dimensions,
        msrp: msrp,
        msrpCurrency: msrpCurrency,
        publicationDate: _publicationDate,
        publicationDatePrecision: _publicationDatePrecision,
        customFieldChanges: _customFieldChanges(),
      );
      if (!mounted) return;
      final updated = metaRes.value;
      if (updated == null) {
        setState(() {
          _saving = false;
          _formError = localizedFailureMessage(l, metaRes.failure!);
        });
        return;
      }
      book = updated;
    }

    // 2) Personal fields + (on create) chapter totals. Each patch fires only
    // when its value changed; the first failure aborts and is surfaced.
    Failure? err;
    // Set when a status/progress mutation ran — those change what the
    // home-screen widget shows, so the snapshot is re-pushed below.
    var widgetDirty = justCreated && _status == BookStatus.reading;
    if (justCreated && chapterCount != null) {
      err ??= (await repo.updateTotals(
        book.id,
        chapterCount: chapterCount,
      )).failure;
    }
    if (err == null) {
      if (!justCreated && _status != _initialStatus) {
        err ??= (await repo.changeStatus(book.id, _status)).failure;
        widgetDirty = true;
      }
      if (err == null &&
          (_rating != _initialRating || _review != _initialReview)) {
        err ??= (await repo.updateRatingReview(
          book.id,
          rating: _rating,
          reviewMarkdown: _review,
        )).failure;
      }
      final progressChanged =
          progPageText != _initialProgPage ||
          progPctText != _initialProgPct ||
          progChapterText != _initialProgChapter;
      if (err == null &&
          progressChanged &&
          (progPage != null || progPct != null || progChapter != null)) {
        err ??=
            (await ref
                    .read(progressRepoProvider)
                    .update(
                      book.id,
                      page: progPage,
                      percentage: progPct,
                      chapter: progChapter,
                    ))
                .failure;
        widgetDirty = true;
      }
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _formError = localizedFailureMessage(l, err!);
      });
      return;
    }
    ref
      ..invalidate(booksProvider)
      ..invalidate(bookProvider(book.id))
      ..invalidate(progressProvider(book.id))
      ..invalidatePersonalStats();
    final savedBook = book.status != _status
        ? book.copyWith(status: _status)
        : book;
    notifyPersonalBookSpoilerEligibilityMutation(
      ref,
      before: widget.initialBook,
      after: savedBook,
    );
    if (widgetDirty) {
      // Best-effort: reflect the status/progress change on the home widget.
      unawaited(syncWidget(ref).catchError((Object _) => false));
    }
    if (justCreated
        ? (_status == BookStatus.reading || _status == BookStatus.read)
        : _status != _initialStatus) {
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: context,
        book: savedBook,
        previousStatus: justCreated ? null : _initialStatus,
        newStatus: _status,
        l: l,
      );
      if (!mounted) return;
    }
    var releaseScheduled = false;
    if (justCreated && widget.offerReleaseEvent && _offerReleaseEvent) {
      releaseScheduled = await maybeCreateReleaseEventForBook(
        ref: ref,
        context: context,
        book: savedBook,
        publicationDate:
            savedBook.publicationDate ?? widget.initialPublicationDate,
        l: l,
      );
      if (!mounted) return;
    }
    if (widget.offerReleaseEvent) {
      Navigator.of(context).pop(
        ExploreCatalogAddResult(
          savedBook,
          releaseEventScheduled: releaseScheduled,
        ),
      );
      return;
    }
    Navigator.of(context).pop(savedBook);
  }

  /// Validates the three progress fields. Returns the first error message or
  /// null. Page must be > 0, percentage in 0–100, chapter > 0.
  String? _validateProgress(
    AppL10n l, {
    required int? progPage,
    required String progPageText,
    required int? progPct,
    required String progPctText,
    required int? progChapter,
    required String progChapterText,
  }) {
    if (progPageText.isNotEmpty && (progPage == null || progPage <= 0)) {
      return l.bookPagesInvalid;
    }
    if (progPctText.isNotEmpty &&
        (progPct == null || progPct < 0 || progPct > 100)) {
      return l.progressPercentageInvalid;
    }
    if (progChapterText.isNotEmpty &&
        (progChapter == null || progChapter <= 0)) {
      return l.eventTargetChapterInvalid;
    }
    return null;
  }
}

/// The sub-section label shown above the progress block — a touch bolder than a
/// field label so it reads as a deliberate sub-heading, not an orphaned word.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.fg2,
      ),
    );
  }
}
