import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/annotation_markdown.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_edge_fading_scroll.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/ocr/ocr_capture.dart';
import 'package:readendar/features/quotes/ocr/ocr_line_selection_screen.dart';
import 'package:readendar/features/quotes/quote_book_picker.dart';
import 'package:readendar/features/quotes/voice/quote_voice_permission.dart';
import 'package:readendar/features/quotes/voice/voice_dictation_controller.dart';

/// Opens the annotation editor as a full-screen view (markdown body, no book
/// picker). When [book] is omitted on create, the user picks a book first.
Future<Quote?> openQuoteComposer(
  BuildContext context, {
  Book? book,
  Quote? existing,
  String? initialText,
  AnnotationCategory category = AnnotationCategory.quote,
}) async {
  Book? resolved = book;
  if (existing == null && resolved == null) {
    resolved = await pickQuoteBook(context);
    if (resolved == null || !context.mounted) return null;
  }
  return Navigator.of(context).push<Quote>(
    rdPageRoute(
      context,
      fullscreenDialog: true,
      builder: (_) => QuoteComposerSheet(
        book: resolved,
        existing: existing,
        initialText: initialText,
        category: existing?.category ?? category,
      ),
    ),
  );
}

class QuoteComposerSheet extends ConsumerStatefulWidget {
  const QuoteComposerSheet({
    super.key,
    this.book,
    this.existing,
    this.initialText,
    this.category = AnnotationCategory.quote,
    @visibleForTesting this.voiceController,
    @visibleForTesting this.ensureVoicePermission,
  });

  final Book? book;
  final Quote? existing;
  final AnnotationCategory category;

  /// Pre-fills the quote body (Share Extension / Android send ingest). Ignored
  /// when [existing] is set (edit mode owns the text).
  final String? initialText;

  @visibleForTesting
  final VoiceDictationController? voiceController;

  /// Defaults to [ensureQuoteVoiceAccess]. Injected in tests.
  @visibleForTesting
  final Future<bool> Function(BuildContext context)? ensureVoicePermission;

  @override
  ConsumerState<QuoteComposerSheet> createState() => QuoteComposerSheetState();
}

class QuoteComposerSheetState extends ConsumerState<QuoteComposerSheet> {
  late final QuillController _quill = _controllerFromMarkdown(
    widget.existing?.body ?? widget.initialText ?? '',
  );
  final _pageController = TextEditingController();
  final _chapterController = TextEditingController();
  final _noteController = TextEditingController();
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();
  late final VoiceDictationController _voice =
      (widget.voiceController ?? VoiceDictationController())
        ..addListener(_onVoiceChanged);
  bool _pinned = false;
  bool _favorite = false;
  bool _saving = false;
  bool _voiceNoticeShown = false;
  bool _voiceInitializing = false;
  late AnnotationCategory _category = widget.category;
  bool get _isEdit => widget.existing != null;
  bool get _editorFocused => _editorFocus.hasFocus;

  /// Hide bottom chrome only while the main editor owns the keyboard. Dismissing
  /// the keyboard (e.g. Android back) can leave the editor focused; tying
  /// visibility to [viewInsets] keeps the private note reachable.
  bool _hidesBottomChrome(BuildContext context) =>
      annotationComposerHidesBottomChrome(
        editorFocused: _editorFocused,
        keyboardInsetBottom: MediaQuery.viewInsetsOf(context).bottom,
      );

  String get _bodyMarkdown => annotationMarkdownFromDocument(_quill.document);

  @override
  void initState() {
    super.initState();
    _quill.addListener(_onQuillChanged);
    _editorFocus.addListener(_onEditorFocusChanged);
    final e = widget.existing;
    if (e != null) {
      if (e.page != null) _pageController.text = '${e.page}';
      if (e.chapter != null) _chapterController.text = '${e.chapter}';
      _noteController.text = e.note;
      _pinned = e.pinned;
      _favorite = e.favorite;
      _category = e.category;
    }
  }

  void _onQuillChanged() {
    if (mounted) setState(() {});
  }

  void _onEditorFocusChanged() {
    if (mounted) setState(() {});
  }

  void _clearEditorFocus() {
    _editorFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    _quill
      ..removeListener(_onQuillChanged)
      ..dispose();
    _pageController.dispose();
    _chapterController.dispose();
    _noteController.dispose();
    _editorFocus
      ..removeListener(_onEditorFocusChanged)
      ..dispose();
    _editorScroll.dispose();
    _voice
      ..removeListener(_onVoiceChanged)
      ..dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleDictation() async {
    final l = AppL10n.of(context);
    if (_voice.listening) {
      await _voice.stop();
      return;
    }
    if (_voiceInitializing) return;
    if (_voice.unavailable) {
      showRdToast(context, message: l.quoteVoiceUnavailable);
      return;
    }
    final allowed =
        await (widget.ensureVoicePermission ?? ensureQuoteVoiceAccess)(context);
    if (!allowed || !mounted) return;
    setState(() => _voiceInitializing = true);
    final available = await _voice.init(l.localeName);
    if (!mounted) return;
    setState(() => _voiceInitializing = false);
    if (!available) {
      // Permanent no-on-device STT vs retryable timeout/permission denial.
      showRdToast(
        context,
        message: _voice.unavailable
            ? l.quoteVoiceUnavailable
            : l.quoteVoiceTryAgain,
      );
      return;
    }
    if (_voice.localeFallback && !_voiceNoticeShown) {
      _voiceNoticeShown = true;
      showRdToast(context, message: l.quoteVoiceLocaleFallback);
    }
    await _voice.start(onFinal: insertCapturedText);
  }

  int? _intOf(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return (v == null || v < 1) ? null : v;
  }

  Future<void> _save() async {
    final book = widget.book;
    final text = _bodyMarkdown;
    final existing = widget.existing;
    if ((existing == null && book == null) || text.isEmpty || _saving) return;
    if (annotationBodyExceedsLimit(text)) {
      showRdToast(
        context,
        message: AppL10n.of(
          context,
        ).annotationBodyTooLong(kAnnotationMaxBodyLen),
      );
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(quotesControllerProvider.notifier);
    final note = _noteController.text.trim();
    final r = existing == null
        ? await controller.create(
            bookId: book!.id,
            body: text,
            category: _category,
            page: _intOf(_pageController),
            chapter: _intOf(_chapterController),
            pinned: _pinned,
            favorite: _favorite,
            commentary: _category == AnnotationCategory.quote ? note : '',
            spoiler: false,
          )
        : await controller.updateQuote(
            existing.copyWith(
              body: text,
              category: _category,
              page: () => _intOf(_pageController),
              chapter: () => _intOf(_chapterController),
              pinned: _pinned,
              favorite: _favorite,
              commentary: _category == AnnotationCategory.quote ? note : '',
              spoiler: false,
            ),
          );
    if (!mounted) return;
    await r.fold(
      (q) async {
        if (existing == null) {
          unawaited(ref.read(analyticsProvider).logQuoteSaved());
        }
        if (!mounted) return;
        Navigator.of(context).pop(q);
      },
      (f) async {
        setState(() => _saving = false);
        showRdFailureToast(context, f);
      },
    );
  }

  Future<void> _changeCategory() async {
    _clearEditorFocus();
    final l = AppL10n.of(context);
    final selected = await showRdModalSheet<AnnotationCategory>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.annotationFilterCategories,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in AnnotationCategory.values)
                    AnnotationCategoryChip(
                      category: cat,
                      selected: _category == cat,
                      onSelected: (_) => Navigator.pop(ctx, cat),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    _clearEditorFocus();
    if (selected == null) return;
    setState(() => _category = selected);
  }

  Future<void> _openConfig() async {
    _clearEditorFocus();
    final l = AppL10n.of(context);
    final book =
        widget.book ??
        (widget.existing != null
            ? ref
                  .read(booksProvider)
                  .value
                  ?.where((b) => b.id == widget.existing!.bookId)
                  .firstOrNull
            : null);
    if (!mounted) return;
    await showRdModalSheet<void>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.annotationConfigTitle,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: RdTextField(
                          key: const Key('annotationConfigPage'),
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l.quoteComposerPageLabel,
                            hintText: book?.pageCount != null
                                ? '/ ${book!.pageCount}'
                                : null,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RdTextField(
                          key: const Key('annotationConfigChapter'),
                          controller: _chapterController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l.quoteComposerChapterLabel,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RdSwitchListTile(
                    value: _pinned,
                    onChanged: (v) => setSheet(() {
                      _pinned = v;
                      setState(() {});
                    }),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.annotationPin),
                    secondary: const Icon(LucideIcons.pin, size: 18),
                  ),
                  RdSwitchListTile(
                    value: _favorite,
                    onChanged: (v) => setSheet(() {
                      _favorite = v;
                      setState(() {});
                    }),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.annotationFavorite),
                    secondary: const Icon(LucideIcons.star, size: 18),
                  ),
                  const SizedBox(height: 12),
                  RdButton.primary(
                    onPressed: saving
                        ? null
                        : () async {
                            // Create: local draft only. Edit: persist config
                            // now so the main composer Save is for body/note.
                            if (widget.existing == null) {
                              Navigator.pop(ctx);
                              return;
                            }
                            setSheet(() => saving = true);
                            final ok = await _persistConfig(
                              messenger: ScaffoldMessenger.of(context),
                            );
                            if (!ctx.mounted) return;
                            if (ok) {
                              Navigator.pop(ctx);
                            } else {
                              setSheet(() => saving = false);
                            }
                          },
                    label: widget.existing == null
                        ? l.actionClose
                        : l.actionSave,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) _clearEditorFocus();
  }

  /// Persists page/chapter/spoiler/pin/favorite for an existing
  /// annotation. Leaves body and commentary untouched (main composer Save).
  Future<bool> _persistConfig({
    required ScaffoldMessengerState messenger,
  }) async {
    final current = widget.existing;
    if (current == null) return true;
    final result = await ref
        .read(quotesControllerProvider.notifier)
        .updateQuote(
          current.copyWith(
            page: () => _intOf(_pageController),
            chapter: () => _intOf(_chapterController),
            spoiler: false,
            pinned: _pinned,
            favorite: _favorite,
          ),
        );
    if (!mounted) return false;
    return result.fold(
      (updated) {
        return true;
      },
      (failure) {
        setState(() {
          _pinned = current.pinned;
          _favorite = current.favorite;
          _pageController.text = current.page == null ? '' : '${current.page}';
          _chapterController.text = current.chapter == null
              ? ''
              : '${current.chapter}';
        });
        showRdFailureToast(context, failure, messenger: messenger);
        return false;
      },
    );
  }

  /// Inserts captured text (OCR / dictation) at the cursor, replacing any
  /// selection; keeps the caret after the inserted text.
  void insertCapturedText(String captured) {
    if (!mounted) return;
    final sel = _quill.selection;
    final index = sel.isValid ? sel.start : _quill.document.length - 1;
    final length = sel.isValid ? sel.end - sel.start : 0;
    _quill.replaceText(index, length < 0 ? 0 : length, captured, null);
    setState(() {});
  }

  Future<void> _captureFromPhoto() async {
    final l = AppL10n.of(context);
    late final OcrPage page;
    try {
      final captured = await captureOcrPage(context);
      if (captured == null || !mounted) return;
      page = captured;
    } on Object {
      if (!mounted) return;
      showRdToast(context, tone: RdToastTone.error, message: l.errorGeneric);
      return;
    }
    if (page.lines.isEmpty) {
      showRdToast(context, message: l.quoteOcrNoText);
      return;
    }
    final text = await Navigator.of(context).push<String>(
      rdPageRoute<String>(
        context,
        builder: (_) => OcrLineSelectionScreen(page: page),
      ),
    );
    if (text != null && text.isNotEmpty && mounted) insertCapturedText(text);
  }

  /// The capture-mode toolbar: photo OCR (camera) and voice dictation feed
  /// the same text field the typed mode uses.
  List<Widget> buildCaptureTools(BuildContext context) {
    final l = AppL10n.of(context);
    return [
      RdIconButton(
        tooltip: l.quoteOcrTooltip,
        onPressed: _saving ? null : _captureFromPhoto,
        icon: LucideIcons.camera,
        color: context.colors.accent,
      ),
      RdIconButton(
        tooltip: _voice.unavailable
            ? l.quoteVoiceUnavailable
            : _voice.listening
            ? l.quoteVoiceStopTooltip
            : l.quoteVoiceTooltip,
        onPressed: _saving || _voiceInitializing ? null : _toggleDictation,
        icon: _voice.unavailable
            ? LucideIcons.micOff
            : _voice.listening
            ? LucideIcons.micOff
            : LucideIcons.mic,
        color: _voice.unavailable
            ? context.colors.fg3
            : _voice.listening
            ? Theme.of(context).colorScheme.error
            : context.colors.accent,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final book =
        widget.book ??
        (widget.existing != null
            ? ref
                  .watch(booksProvider)
                  .value
                  ?.where((b) => b.id == widget.existing!.bookId)
                  .firstOrNull
            : null);
    final categoryHue = AnnotationCategoryStyle.hue(_category);
    final hidesBottomChrome = _hidesBottomChrome(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit
                  ? l.annotationComposerTitleEdit
                  : l.annotationComposerTitleNew,
            ),
            if (book != null)
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          FormSaveAction(
            saving: _saving,
            onPressed: _save,
            tooltip: l.actionSave,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    avatar: Icon(
                      AnnotationCategoryStyle.icon(_category),
                      size: 16,
                      color: categoryHue,
                    ),
                    backgroundColor: AnnotationCategoryStyle.softBg(_category),
                    side: BorderSide(color: categoryHue),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AnnotationCategoryStyle.label(l, _category)),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.pencil,
                          size: 12,
                          color: categoryHue,
                        ),
                      ],
                    ),
                    onPressed: _saving ? null : _changeCategory,
                  ),
                  ActionChip(
                    avatar: Icon(
                      LucideIcons.settings2,
                      size: 16,
                      color: c.fg2,
                    ),
                    label: Text(l.annotationConfigTitle),
                    onPressed: _saving ? null : _openConfig,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface1,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
                ),
                clipBehavior: Clip.antiAlias,
                child: _AnnotationToolbar(
                  controller: _quill,
                  extra: buildCaptureTools(context),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface1,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                    child: QuillEditor.basic(
                      controller: _quill,
                      focusNode: _editorFocus,
                      scrollController: _editorScroll,
                      config: QuillEditorConfig(
                        autoFocus: false,
                        expands: true,
                        padding: const EdgeInsets.all(12),
                        placeholder: l.annotationComposerTextHint,
                        onTapUp: (details, getPosition) {
                          _editorFocus.requestFocus();
                          return false;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_voice.unavailable && !hidesBottomChrome)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    Icon(LucideIcons.micOff, size: 16, color: c.fg3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.quoteVoiceUnavailable,
                        style: TextStyle(fontSize: 13, color: c.fg3),
                      ),
                    ),
                  ],
                ),
              )
            else if (_voice.listening && !hidesBottomChrome)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    Icon(LucideIcons.audioLines, size: 16, color: c.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _voice.partial.isEmpty
                            ? l.quoteVoiceListening
                            : _voice.partial,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: c.fg3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Keep the private note / share chrome out of the way while the
            // main editor owns the keyboard so the caret area stays usable.
            if (!hidesBottomChrome)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  children: [
                    if (_category == AnnotationCategory.quote) ...[
                      RdTextField(
                        controller: _noteController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l.quoteComposerNoteLabel,
                          hintText: l.quoteComposerNoteHint,
                          prefixIcon: const Icon(
                            LucideIcons.stickyNote,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
bool annotationComposerHidesBottomChrome({
  required bool editorFocused,
  required double keyboardInsetBottom,
}) => editorFocused && keyboardInsetBottom > 0;

QuillController _controllerFromMarkdown(String markdown) {
  final text = markdown.trim();
  if (text.isEmpty) return QuillController.basic();
  return QuillController(
    document: Document.fromDelta(annotationMarkdownToDelta(text)),
    selection: const TextSelection.collapsed(offset: 0),
  );
}

class _AnnotationToolbar extends StatelessWidget {
  const _AnnotationToolbar({required this.controller, required this.extra});

  final QuillController controller;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return RdEdgeFadingScrollView(
      scrollKey: const Key('annotation-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: ReadendarTokens.sp2),
      surfaceColor: context.colors.surface1,
      child: Row(
        children: [
          ...extra,
          QuillToolbarToggleStyleButton(
            controller: controller,
            attribute: Attribute.bold,
          ),
          QuillToolbarToggleStyleButton(
            controller: controller,
            attribute: Attribute.italic,
          ),
          QuillToolbarToggleStyleButton(
            controller: controller,
            attribute: Attribute.underline,
          ),
          QuillToolbarSelectHeaderStyleDropdownButton(controller: controller),
          QuillToolbarToggleStyleButton(
            controller: controller,
            attribute: Attribute.ul,
          ),
          QuillToolbarToggleStyleButton(
            controller: controller,
            attribute: Attribute.blockQuote,
          ),
        ],
      ),
    );
  }
}
