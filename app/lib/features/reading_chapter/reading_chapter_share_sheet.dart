import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';
import 'package:share_plus/share_plus.dart';

Future<void> openReadingChapterShareSheet(
  BuildContext context, {
  required ReadingChapterStory story,
}) => showRdModalSheet<void>(
  context: context,
  builder: (_) => _ReadingChapterShareSheet(story: story),
);

class _ReadingChapterShareSheet extends ConsumerStatefulWidget {
  const _ReadingChapterShareSheet({required this.story});

  final ReadingChapterStory story;

  @override
  ConsumerState<_ReadingChapterShareSheet> createState() =>
      _ReadingChapterShareSheetState();
}

class _ReadingChapterShareSheetState
    extends ConsumerState<_ReadingChapterShareSheet> {
  final _hiddenBookIds = <String>{};
  final _hiddenCardIds = <String>{};
  final _approvedPrompts = <String>{};
  bool _sharing = false;

  Future<void> _shareChapter() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final l = AppL10n.of(context);
      final period = readingChapterPeriodLabel(
        context,
        widget.story.period.kind,
        widget.story.period.key,
      );
      final books = widget.story.books
          .where((book) => !_hiddenBookIds.contains(book.entryId))
          .map((book) => book.title.trim())
          .where((title) => title.isNotEmpty)
          .join('\n');
      await SharePlus.instance.share(
        ShareParams(text: l.readingChapterShareLocalText(period, books)),
      );
    } on Object {
      if (!mounted) return;
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: AppL10n.of(context).errorGeneric,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.readingChapterShareTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  RdIconButton(
                    tooltip: l.actionClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: LucideIcons.x,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                l.readingChapterSharePrivacyBody,
                style: TextStyle(color: context.colors.fg2),
              ),
            ),
            Expanded(child: _options(l)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: RdButton.primary(
                label: l.actionShare,
                icon: LucideIcons.share2,
                loading: _sharing,
                onPressed: _sharing ? null : _shareChapter,
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _options(AppL10n l) {
    final books = widget.story.books;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        SectionHeader(l.readingChapterIncludedBooks, padding: EdgeInsets.zero),
        for (final book in books)
          RdCheckboxListTile(
            value: !_hiddenBookIds.contains(book.entryId),
            onChanged: (included) {
              setState(() {
                if (included ?? false) {
                  _hiddenBookIds.remove(book.entryId);
                } else {
                  _hiddenBookIds.add(book.entryId);
                }
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: _ShareOptionRow(
              leading: BookCover(
                title: book.title,
                author: book.primaryAuthor,
                coverUrl: book.coverUrl,
                size: BookCoverSize.xs,
              ),
              primary: book.title,
              secondary: book.primaryAuthor,
            ),
          ),
        const SizedBox(height: 12),
        SectionHeader(l.readingChapterIncludedCards, padding: EdgeInsets.zero),
        for (final card in readingChapterVisibleCards(widget.story.cards))
          RdCheckboxListTile(
            value: !_hiddenCardIds.contains(card.id),
            onChanged: (included) {
              setState(() {
                if (included ?? false) {
                  _hiddenCardIds.remove(card.id);
                } else {
                  _hiddenCardIds.add(card.id);
                }
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: _ShareOptionLabels(
              primary: readingChapterShareCardPrimaryLabel(l, card),
              secondary: readingChapterShareCardBookTitle(card, books),
            ),
          ),
        for (final reflection in widget.story.curation)
          if (reflection.excerpt.isNotEmpty ||
              reflection.attribution.isNotEmpty)
            RdCheckboxListTile(
              value: _approvedPrompts.contains(reflection.prompt),
              onChanged: (included) {
                setState(() {
                  if (included ?? false) {
                    _approvedPrompts.add(reflection.prompt);
                  } else {
                    _approvedPrompts.remove(reflection.prompt);
                  }
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: _ShareOptionLabels(
                primary: readingChapterPromptLabel(l, reflection.prompt),
                secondary: l.readingChapterIncludeExcerpt,
              ),
            ),
      ],
    );
  }
}

class _ShareOptionLabels extends StatelessWidget {
  const _ShareOptionLabels({required this.primary, this.secondary});

  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final secondaryText = secondary?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        if (secondaryText != null && secondaryText.isNotEmpty)
          Text(
            secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: context.colors.fg3),
          ),
      ],
    );
  }
}

class _ShareOptionRow extends StatelessWidget {
  const _ShareOptionRow({
    required this.leading,
    required this.primary,
    this.secondary,
  });

  final Widget leading;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: _ShareOptionLabels(primary: primary, secondary: secondary),
        ),
      ],
    );
  }
}
