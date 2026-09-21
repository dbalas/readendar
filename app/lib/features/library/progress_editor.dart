import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/library/progress_commit.dart';

Future<void> showProgressEditorSheet(
  BuildContext context, {
  required Book book,
  Progress? initial,
}) {
  return showRdModalSheet<void>(
    context: context,
    builder: (sheetContext) => SingleChildScrollView(
      // Keyboard inset is owned by [showRdModalSheet] — scroll only so short
      // viewports / IME do not clip fields or thrash focus.
      child: ProgressEditorForm(
        book: book,
        initial: initial,
        onSaved: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

/// Shared progress editor used by book detail and widget-launched quick entry.
/// Page, percentage, and chapter keep the same validation and synchronization
/// regardless of entry point.
class ProgressEditorForm extends ConsumerStatefulWidget {
  const ProgressEditorForm({
    required this.book,
    this.initial,
    this.onSaved,
    this.onProgressSaved,
    super.key,
  });

  final Book book;
  final Progress? initial;
  final VoidCallback? onSaved;
  final ValueChanged<Progress>? onProgressSaved;

  @override
  ConsumerState<ProgressEditorForm> createState() => _ProgressEditorFormState();
}

class _ProgressEditorFormState extends ConsumerState<ProgressEditorForm> {
  final _pageCtrl = TextEditingController();
  final _pctCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();
  bool _saving = false;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _pageCtrl.text = p?.currentPage?.toString() ?? '';
    _pctCtrl.text = p?.currentPercentage?.toString() ?? '';
    _chapterCtrl.text = p?.currentChapter?.toString() ?? '';
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pctCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(String value) {
    if (_syncing) return;
    final total = widget.book.pageCount;
    if (total == null || total <= 0) return;
    final page = int.tryParse(value.trim());
    _syncing = true;
    if (page != null && page >= 0) {
      _pctCtrl.text = ((page / total) * 100).round().clamp(0, 100).toString();
    } else {
      _pctCtrl.clear();
    }
    _syncing = false;
  }

  void _onPercentageChanged(String value) {
    if (_syncing) return;
    final total = widget.book.pageCount;
    if (total == null || total <= 0) return;
    final pct = int.tryParse(value.trim());
    _syncing = true;
    if (pct != null && pct >= 0 && pct <= 100) {
      _pageCtrl.text = ((pct / 100) * total).round().toString();
    } else {
      _pageCtrl.clear();
    }
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RdTextField(
            key: const Key('progressPageField'),
            controller: _pageCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: _onPageChanged,
            decoration: InputDecoration(
              labelText: l.metaPages,
              suffixText: widget.book.pageCount == null
                  ? null
                  : '/ ${widget.book.pageCount}',
            ),
          ),
          const SizedBox(height: 12),
          RdTextField(
            key: const Key('progressPercentageField'),
            controller: _pctCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: _onPercentageChanged,
            decoration: InputDecoration(
              labelText: l.progressPercentageLabel,
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 12),
          RdTextField(
            key: const Key('progressChapterField'),
            controller: _chapterCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_saving) unawaited(_save());
            },
            decoration: InputDecoration(
              labelText: l.progressChapterLabel,
              suffixText: widget.book.chapterCount == null
                  ? null
                  : '/ ${widget.book.chapterCount}',
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '* ',
                    style: TextStyle(color: context.colors.accent),
                  ),
                  TextSpan(text: l.chapterArbitraryHint),
                ],
              ),
              style: TextStyle(fontSize: 12, color: context.colors.fg3),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.colors.danger)),
          ],
          const SizedBox(height: 16),
          RdButton.primary(
            key: const Key('progressSaveButton'),
            expand: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
            label: l.actionUpdateProgress,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final pageText = _pageCtrl.text.trim();
    final pctText = _pctCtrl.text.trim();
    final chapterText = _chapterCtrl.text.trim();
    final resetsProgress =
        pageText.isEmpty &&
        pctText.isEmpty &&
        (widget.initial?.currentPage != null ||
            widget.initial?.currentPercentage != null);
    final page = resetsProgress
        ? 0
        : (pageText.isEmpty ? null : int.tryParse(pageText));
    final pct = resetsProgress
        ? 0
        : (pctText.isEmpty ? null : int.tryParse(pctText));
    final chapter =
        chapterText.isEmpty && widget.initial?.currentChapter != null
        ? 0
        : (chapterText.isEmpty ? null : int.tryParse(chapterText));

    if (pageText.isNotEmpty && (page == null || page < 0)) {
      setState(() => _error = l.bookPagesInvalid);
      return;
    }
    if (pctText.isNotEmpty && (pct == null || pct < 0 || pct > 100)) {
      setState(() => _error = l.progressPercentageInvalid);
      return;
    }
    if (chapterText.isNotEmpty && (chapter == null || chapter < 0)) {
      setState(() => _error = l.eventTargetChapterInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await commitBookProgress(
      ref: ref,
      bookId: widget.book.id,
      page: page,
      percentage: pct,
      chapter: chapter,
    );
    if (!mounted) return;
    result.fold(
      (progress) {
        showRdToast(
          context,
          tone: RdToastTone.success,
          message: l.progressUpdatedToast,
        );
        widget.onProgressSaved?.call(progress);
        widget.onSaved?.call();
      },
      (failure) => setState(() {
        _saving = false;
        _error = localizedFailureMessage(l, failure);
      }),
    );
  }
}
