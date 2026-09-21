import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_scaffold.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';

class ReadingChapterCurationScreen extends ConsumerStatefulWidget {
  const ReadingChapterCurationScreen({required this.story, super.key});

  final ReadingChapterStory story;

  @override
  ConsumerState<ReadingChapterCurationScreen> createState() =>
      _ReadingChapterCurationScreenState();
}

class _ReadingChapterCurationScreenState
    extends ConsumerState<ReadingChapterCurationScreen> {
  static const _annualPrompts = [
    'favorite',
    'biggest_surprise',
    'comfort_read',
    'challenged_me',
    'best_cover',
    'memorable_passage',
    'favorite_return',
    'unfinished_unforgettable',
  ];

  final _selections = <String, ReadingChapterBook>{};
  final _expandedPrompts = <String>{};
  final _excerptControllers = <String, TextEditingController>{};
  final _attributionControllers = <String, TextEditingController>{};
  final _safeToReveal = <String>{};
  bool _saving = false;

  bool get _annual => widget.story.period.kind == ReadingChapterKind.year;
  int get _maximum => _annual ? 3 : 1;
  List<String> get _prompts => _annual ? _annualPrompts : const ['favorite'];

  @override
  void initState() {
    super.initState();
    final books = {for (final book in widget.story.books) book.entryId: book};
    for (final reflection in widget.story.curation) {
      final book = books[reflection.bookEntryId];
      if (book == null) continue;
      _selections[reflection.prompt] = book;
      _excerptControllers[reflection.prompt] = TextEditingController(
        text: reflection.excerpt,
      );
      _attributionControllers[reflection.prompt] = TextEditingController(
        text: reflection.attribution,
      );
      if ((reflection.excerpt.isNotEmpty ||
              reflection.attribution.isNotEmpty) &&
          !reflection.spoiler) {
        _safeToReveal.add(reflection.prompt);
      }
      _expandedPrompts.add(reflection.prompt);
    }
  }

  @override
  void dispose() {
    for (final controller in _excerptControllers.values) {
      controller.dispose();
    }
    for (final controller in _attributionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePrompt(String prompt) async {
    if (_selections.containsKey(prompt)) {
      setState(() {
        if (_expandedPrompts.contains(prompt)) {
          _expandedPrompts.remove(prompt);
        } else {
          _expandedPrompts.add(prompt);
        }
      });
      return;
    }
    final l = AppL10n.of(context);
    if (_selections.length >= _maximum) {
      showRdToast(
        context,
        message: _annual
            ? l.readingChapterPickExactlyThree
            : l.readingChapterPickOne,
      );
      return;
    }
    final book = await _pickBook();
    if (!mounted || book == null) return;
    setState(() {
      _selections[prompt] = book;
      _expandedPrompts.add(prompt);
      _excerptControllers.putIfAbsent(prompt, TextEditingController.new);
      _attributionControllers.putIfAbsent(prompt, TextEditingController.new);
    });
  }

  Future<ReadingChapterBook?> _pickBook() =>
      showRdModalSheet<ReadingChapterBook>(
        context: context,
        builder: (_) => _BookPicker(books: widget.story.books),
      );

  Future<void> _changeBook(String prompt) async {
    final book = await _pickBook();
    if (!mounted || book == null) return;
    setState(() => _selections[prompt] = book);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppL10n.of(context);
    if (_annual && _selections.isNotEmpty && _selections.length != 3) {
      showRdToast(context, message: l.readingChapterPickExactlyThree);
      return;
    }
    setState(() => _saving = true);
    final reflections = [
      for (final prompt in _prompts)
        if (_selections[prompt] case final book?)
          ReadingChapterReflection(
            prompt: prompt,
            bookEntryId: book.entryId,
            excerpt: _excerptControllers[prompt]?.text.trim() ?? '',
            attribution: _attributionControllers[prompt]?.text.trim() ?? '',
            spoiler: !_safeToReveal.contains(prompt),
          ),
    ];
    final result = await ref
        .read(readingChapterRepoProvider)
        .saveCuration(
          ReadingChapterRequest(
            widget.story.period.kind,
            widget.story.period.key,
          ),
          expectedSourceRevision: widget.story.sourceRevision,
          reflections: reflections,
          safeToRevealPrompts: _safeToReveal,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isErr) {
      showRdFailureToast(context, result.failure!);
      return;
    }
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.readingChapterHighlightsSaved,
    );
    Navigator.of(context).pop(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return RdScaffold(
      title: Text(l.readingChapterHighlightsTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          EditorialTitle(l.readingChapterHighlightsTitle),
          const SizedBox(height: 12),
          Text(
            _annual
                ? l.readingChapterHighlightsAnnualBody
                : l.readingChapterHighlightsMonthBody,
            style: TextStyle(color: context.colors.fg2),
          ),
          const SizedBox(height: 20),
          for (final prompt in _prompts) ...[
            _PromptEditor(
              prompt: prompt,
              label: readingChapterPromptLabel(l, prompt),
              selectedBook: _selections[prompt],
              expanded: _expandedPrompts.contains(prompt),
              excerptController: _excerptControllers[prompt],
              attributionController: _attributionControllers[prompt],
              safeToReveal: _safeToReveal.contains(prompt),
              onToggle: () => _togglePrompt(prompt),
              onChangeBook: () => _changeBook(prompt),
              onSafeChanged: (value) => setState(() {
                if (value) {
                  _safeToReveal.add(prompt);
                } else {
                  _safeToReveal.remove(prompt);
                }
              }),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: RdButton.primary(
          label: l.actionSave,
          icon: LucideIcons.check,
          loading: _saving,
          onPressed: _saving ? null : _save,
          expand: true,
        ),
      ),
    );
  }
}

class _PromptEditor extends StatelessWidget {
  const _PromptEditor({
    required this.prompt,
    required this.label,
    required this.selectedBook,
    required this.expanded,
    required this.excerptController,
    required this.attributionController,
    required this.safeToReveal,
    required this.onToggle,
    required this.onChangeBook,
    required this.onSafeChanged,
  });

  final String prompt;
  final String label;
  final ReadingChapterBook? selectedBook;
  final bool expanded;
  final TextEditingController? excerptController;
  final TextEditingController? attributionController;
  final bool safeToReveal;
  final VoidCallback onToggle;
  final VoidCallback onChangeBook;
  final ValueChanged<bool> onSafeChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final book = selectedBook;
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Icon(
                  book == null
                      ? LucideIcons.circlePlus
                      : LucideIcons.circleCheck,
                  color: book == null
                      ? context.colors.fg3
                      : context.colors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (book != null)
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: context.colors.fg3,
                  ),
              ],
            ),
          ),
          if (book != null && expanded) ...[
            const SizedBox(height: 16),
            Material(
              key: Key('readingChapterHighlightBook-$prompt'),
              color: context.colors.surface2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
                side: BorderSide(color: context.colors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onChangeBook,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      BookCover(
                        title: book.title,
                        author: book.primaryAuthor,
                        coverUrl: book.coverUrl,
                        size: BookCoverSize.sm,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              book.primaryAuthor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.colors.fg2),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: context.colors.fg3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            RdTextField(
              controller: excerptController,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.readingChapterExcerptOptional,
              ),
            ),
            const SizedBox(height: 10),
            RdTextField(
              controller: attributionController,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.readingChapterAttributionOptional,
              ),
            ),
            RdSwitchListTile(
              value: safeToReveal,
              onChanged: onSafeChanged,
              contentPadding: EdgeInsets.zero,
              title: Text(l.readingChapterSafeToReveal),
              subtitle: Text(l.readingChapterSafeToRevealBody),
              secondary: const Icon(LucideIcons.shieldCheck),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookPicker extends StatelessWidget {
  const _BookPicker({required this.books});
  final List<ReadingChapterBook> books;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                l.readingChapterChooseBook,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: books.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return ListTile(
                    onTap: () => Navigator.of(context).pop(book),
                    leading: BookCover(
                      title: book.title,
                      author: book.primaryAuthor,
                      coverUrl: book.coverUrl,
                      size: BookCoverSize.xs,
                    ),
                    title: Text(book.title),
                    subtitle: Text(book.primaryAuthor),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.colors.fg3,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
