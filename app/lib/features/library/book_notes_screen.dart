// Visual (WYSIWYG) editor for a book's private notes (spec §5). The user sees a
// formatted rich-text editor with a toolbar; under the hood the content is
// stored as Markdown (portable + interpretable elsewhere). flutter_quill drives
// the editing, markdown_quill converts Markdown ⇄ the editor's Delta on load and
// save. A separate full-screen view (not a modal) so there's room for long text.

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/annotation_markdown.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/rd_edge_fading_scroll.dart';
import 'package:readendar/di/providers.dart';

class BookNotesScreen extends ConsumerStatefulWidget {
  /// Editor bound to an existing book: saving creates a note annotation and
  /// pops `true`.
  const BookNotesScreen({required Book this.book, super.key})
    : initialNotes = null,
      privacyHint = null,
      persist = true;

  /// Draft editor with no backing book yet: saving pops the edited Markdown
  /// string instead of persisting.
  const BookNotesScreen.draft({
    required String notes,
    this.privacyHint,
    super.key,
  }) : book = null,
       initialNotes = notes,
       persist = false;

  final Book? book;
  final String? initialNotes;

  /// Overrides [AppL10n.notesPrivateHint].
  final String? privacyHint;
  final bool persist;

  String get _initialNotes => book?.notes ?? initialNotes ?? '';

  @override
  ConsumerState<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends ConsumerState<BookNotesScreen> {
  late final QuillController _controller = _controllerFromMarkdown(
    widget._initialNotes,
  );
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final markdown = _markdownFromDocument(_controller.document);
    // Draft mode: hand the edited Markdown back to the form, which persists it
    // together with the rest of the book on its own save.
    if (!widget.persist) {
      Navigator.pop(context, markdown);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final book = widget.book!;
    if (markdown.trim().isEmpty) {
      Navigator.pop(context, true);
      return;
    }
    if (annotationBodyExceedsLimit(markdown)) {
      setState(() {
        _saving = false;
        _error = l.annotationBodyTooLong(kAnnotationMaxBodyLen);
      });
      return;
    }
    final r = await ref
        .read(annotationRepoProvider)
        .create(
          bookId: book.id,
          body: markdown,
          category: AnnotationCategory.note,
        );
    if (!mounted) return;
    r.fold(
      (_) => Navigator.pop(context, true),
      (f) => setState(() {
        _saving = false;
        _error = localizedFailureMessage(l, f);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notesEditTitle),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A focused notes toolbar: text emphasis, headings, lists, quote,
            // link, undo/redo. The rest (fonts, colors, alignment, code,
            // sub/superscript…) is noise for private notes. Single scrollable row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface1,
                  border: Border.all(color: context.colors.line),
                  borderRadius: BorderRadius.circular(
                    ReadendarTokens.radiusSm,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _NotesToolbar(controller: _controller),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.lock,
                    size: 14,
                    color: context.colors.fg3,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.privacyHint ?? l.notesPrivateHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.fg3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surface1,
                    border: Border.all(color: context.colors.line),
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                    child: QuillEditor.basic(
                      controller: _controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: QuillEditorConfig(
                        autoFocus: false,
                        expands: true,
                        padding: const EdgeInsets.all(12),
                        placeholder: l.notesHint,
                        onTapUp: (details, getPosition) {
                          _focusNode.requestFocus();
                          return false;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact toolbar with edge shadows when more actions sit off-screen.
class _NotesToolbar extends StatelessWidget {
  const _NotesToolbar({required this.controller});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return RdEdgeFadingScrollView(
      scrollKey: const Key('notes-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: ReadendarTokens.sp2),
      surfaceColor: context.colors.surface1,
      child: Row(children: _toolbarButtons),
    );
  }

  List<Widget> get _toolbarButtons => [
    QuillToolbarHistoryButton(controller: controller, isUndo: true),
    QuillToolbarHistoryButton(controller: controller, isUndo: false),
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
    QuillToolbarToggleStyleButton(
      controller: controller,
      attribute: Attribute.strikeThrough,
    ),
    QuillToolbarSelectHeaderStyleDropdownButton(controller: controller),
    QuillToolbarToggleStyleButton(
      controller: controller,
      attribute: Attribute.ol,
    ),
    QuillToolbarToggleStyleButton(
      controller: controller,
      attribute: Attribute.ul,
    ),
    QuillToolbarToggleStyleButton(
      controller: controller,
      attribute: Attribute.blockQuote,
    ),
    QuillToolbarLinkStyleButton(controller: controller),
  ];
}

/// Builds the editor controller from stored Markdown. Empty notes start a blank
/// document.
QuillController _controllerFromMarkdown(String markdown) {
  final text = markdown.trim();
  if (text.isEmpty) return QuillController.basic();
  return QuillController(
    document: Document.fromDelta(annotationMarkdownToDelta(text)),
    selection: const TextSelection.collapsed(offset: 0),
  );
}

/// Serializes the editor document back to Markdown for storage.
String _markdownFromDocument(Document document) =>
    annotationMarkdownFromDocument(document);
