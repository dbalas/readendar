// Configure-then-add screen for the QUOTES home-screen widget.
//
// Reached from the Widgets hub (tapping the quotes preview / its "+"). Instead of adding a widget blindly,
// the user picks what it shows (all / favorites / one book / one fixed quote)
// and how often it rotates — with a LIVE preview reflecting the choice — then
// taps "Add widget". The chosen [QuotesWidgetConfig] is written as the pending
// config so the freshly-added native instance adopts it; on success we confirm
// and pop back to wherever the user came from.
//
// All quote/book data is the user's real in-app quotes (resolveWidgetQuotes),
// so an empty library shows a "add a quote first" CTA rather than a
// mis-configurable widget.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_image.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_install.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_sync.dart';

class QuotesWidgetConfigScreen extends ConsumerStatefulWidget {
  const QuotesWidgetConfigScreen({
    super.key,
    this.editWidgetId,
    this.initialConfig,
  });

  /// When set (Android tap-to-edit), the screen edits THIS existing widget
  /// instance instead of adding a new one: the button saves + re-renders it.
  final int? editWidgetId;

  /// The instance's current config to pre-fill in edit mode.
  final QuotesWidgetConfig? initialConfig;

  @override
  ConsumerState<QuotesWidgetConfigScreen> createState() =>
      _QuotesWidgetConfigScreenState();
}

class _QuotesWidgetConfigScreenState
    extends ConsumerState<QuotesWidgetConfigScreen>
    with WidgetsBindingObserver, WidgetInstaller<QuotesWidgetConfigScreen> {
  late QuotesWidgetConfig _config =
      widget.initialConfig ?? const QuotesWidgetConfig();
  bool _adding = false;

  // Edit mode is signalled by an initial config (from the tap-to-edit deep
  // link). On Android [editWidgetId] also identifies the instance; on iOS it's
  // null and the save targets the single shared config.
  bool get _isEdit => widget.initialConfig != null;

  @override
  void initState() {
    super.initState();
    initWidgetInstaller();
  }

  @override
  void dispose() {
    disposeWidgetInstaller();
    super.dispose();
  }

  /// The distinct books present in the user's quotes, for the "one book" picker.
  List<WidgetQuote> get _resolved =>
      resolveWidgetQuotes(<T>(p) => ref.read(p)) ?? const [];

  bool get _isReady => switch (_config.mode) {
    QuotesWidgetMode.book => _config.bookId != null,
    QuotesWidgetMode.fixed => _config.quoteId != null,
    _ => true,
  };

  Future<void> _add() async {
    setState(() => _adding = true);
    await installWidget(
      ref,
      WidgetKind.quotes,
      pendingConfigJson: _configJson(),
      onInstalled: () {
        if (mounted) Navigator.of(context).maybePop();
      },
    );
    if (mounted) setState(() => _adding = false);
  }

  /// Edit mode: persist THIS instance's config natively (updates the widget
  /// immediately), confirm, and pop back to where the tap came from.
  Future<void> _save() async {
    final l = AppL10n.of(context);
    setState(() => _adding = true);
    final ok = await saveQuotesWidgetInstanceConfig(
      widget.editWidgetId,
      _configJson(),
    );
    if (!mounted) return;
    setState(() => _adding = false);
    showRdToast(
      context,
      tone: ok ? RdToastTone.success : RdToastTone.error,
      message: ok ? l.quotesWidgetUpdatedToast : l.errorGeneric,
    );
    if (ok) await Navigator.of(context).maybePop();
  }

  String _configJson() {
    // Only carry the id relevant to the mode, so a stale book/quote id from a
    // mode the user toggled away from can't leak into the native config. The
    // chosen [style] applies to every mode, so it's carried through in all.
    final c = switch (_config.mode) {
      QuotesWidgetMode.book => QuotesWidgetConfig(
        mode: _config.mode,
        bookId: _config.bookId,
        cadence: _config.cadence,
        style: _config.style,
        showNote: _config.showNote,
      ),
      QuotesWidgetMode.fixed => QuotesWidgetConfig(
        mode: _config.mode,
        quoteId: _config.quoteId,
        style: _config.style,
        showNote: _config.showNote,
      ),
      _ => QuotesWidgetConfig(
        mode: _config.mode,
        cadence: _config.cadence,
        style: _config.style,
        showNote: _config.showNote,
      ),
    };
    return jsonEncode(c.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final quotesAsync = ref.watch(quotesControllerProvider);
    final hasQuotes =
        quotesAsync.value?.any((q) => q.category == AnnotationCategory.quote) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l.quotesWidgetConfigEditTitle : l.quotesWidgetConfigTitle,
        ),
      ),
      body: switch (quotesAsync) {
        AsyncData() when !hasQuotes => _EmptyLibrary(
          onAddQuote: () async {
            await openQuoteComposer(context);
            if (mounted) setState(() {});
          },
        ),
        AsyncData() => _form(context, l),
        _ => RdProgress.centered(),
      },
    );
  }

  Widget _form(BuildContext context, AppL10n l) {
    final books = _distinctBooks();
    // Preview stays pinned; mode / cadence / style / note scroll underneath.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: QuotesWidgetPreview(config: _config),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            children: [
              _SectionLabel(l.quotesWidgetConfigMode),
              _ModeChips(
                mode: _config.mode,
                onChanged: (m) =>
                    setState(() => _config = _config.copyWith(mode: m)),
              ),
              if (_config.mode == QuotesWidgetMode.book) ...[
                const SizedBox(height: 16),
                _PickerTile(
                  label: l.quotesWidgetPickBook,
                  value: books
                      .where((b) => b.bookId == _config.bookId)
                      .map((b) => b.bookTitle)
                      .firstOrNull,
                  onTap: () => _pickBook(books),
                ),
              ],
              if (_config.mode == QuotesWidgetMode.fixed) ...[
                const SizedBox(height: 16),
                _PickerTile(
                  label: l.quotesWidgetPickQuote,
                  value: _resolved
                      .where((q) => q.id == _config.quoteId)
                      .map((q) => '«${q.text}»')
                      .firstOrNull,
                  onTap: _pickQuote,
                ),
              ],
              if (_config.mode != QuotesWidgetMode.fixed) ...[
                const SizedBox(height: 24),
                _SectionLabel(l.quotesWidgetConfigCadence),
                _CadenceChips(
                  cadence: _config.cadence,
                  onChanged: (c) =>
                      setState(() => _config = _config.copyWith(cadence: c)),
                ),
              ],
              const SizedBox(height: 24),
              _SectionLabel(l.quotesWidgetConfigStyle),
              _StyleSwatches(
                style: _config.style,
                onChanged: (s) =>
                    setState(() => _config = _config.copyWith(style: s)),
              ),
              const SizedBox(height: 12),
              RdSwitchListTile(
                value: _config.showNote,
                onChanged: (v) =>
                    setState(() => _config = _config.copyWith(showNote: v)),
                contentPadding: EdgeInsets.zero,
                title: Text(l.quotesWidgetShowNote),
                subtitle: Text(l.quotesWidgetShowNoteHint),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: RdButton.primary(
                onPressed: (_isReady && !_adding)
                    ? (_isEdit ? _save : _add)
                    : null,
                loading: _adding,
                icon: _isEdit ? LucideIcons.save : LucideIcons.plus,
                label: _isEdit ? l.actionSave : l.quotesWidgetConfigAdd,
                expand: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Distinct books (by id), newest-quote-first — the order books first appear
  /// in the resolved list.
  List<WidgetQuote> _distinctBooks() {
    final seen = <String>{};
    final out = <WidgetQuote>[];
    for (final q in _resolved) {
      if (seen.add(q.bookId)) out.add(q);
    }
    return out;
  }

  Future<void> _pickBook(List<WidgetQuote> books) async {
    final l = AppL10n.of(context);
    final picked = await _showPicker(
      title: l.quotesWidgetPickBook,
      searchHint: l.quoteBookPickerFilterHint,
      items: [
        for (final b in books)
          _PickerEntry(
            value: b.bookId,
            label: b.bookTitle,
            sub: b.bookAuthor.isEmpty ? null : b.bookAuthor,
            coverUrl: b.bookCoverUrl,
            coverTitle: b.bookTitle,
          ),
      ],
      selected: _config.bookId,
    );
    if (picked != null && mounted) {
      setState(() => _config = _config.copyWith(bookId: picked));
    }
  }

  Future<void> _pickQuote() async {
    final l = AppL10n.of(context);
    final picked = await _showPicker(
      title: l.quotesWidgetPickQuote,
      searchHint: l.quotesSearchHint,
      items: [
        for (final q in _resolved)
          _PickerEntry(
            value: q.id,
            label: '«${q.text}»',
            sub: q.bookTitle,
            coverUrl: q.bookCoverUrl,
            coverTitle: q.bookTitle,
          ),
      ],
      selected: _config.quoteId,
    );
    if (picked != null && mounted) {
      setState(() => _config = _config.copyWith(quoteId: picked));
    }
  }

  Future<String?> _showPicker({
    required String title,
    required String searchHint,
    required List<_PickerEntry> items,
    required String? selected,
  }) {
    return showRdModalSheet<String>(
      context: context,
      builder: (_) => _PickerSheet(
        title: title,
        searchHint: searchHint,
        items: items,
        selected: selected,
      ),
    );
  }
}

/// Section header, small + uppercase, matching the native config sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.colors.fg3,
        ),
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.mode, required this.onChanged});
  final QuotesWidgetMode mode;
  final ValueChanged<QuotesWidgetMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final labels = {
      QuotesWidgetMode.all: l.quotesWidgetModeAll,
      QuotesWidgetMode.favorites: l.quotesWidgetModeFavorites,
      QuotesWidgetMode.book: l.quotesWidgetModeBook,
      QuotesWidgetMode.fixed: l.quotesWidgetModeFixed,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in QuotesWidgetMode.values)
          ChoiceChip(
            label: Text(labels[m]!),
            selected: mode == m,
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}

/// The appearance picker: a wrap of swatches, one per [QuoteWidgetStyle],
/// reusing the share card's palettes so the widget and the shared image read as
/// the same styles. The live preview above reflects the tapped style, so the
/// swatches stay label-free (like the share carousel). "Auto" shows a
/// light/dark split to signal it follows the app theme; the cover style shows
/// an image glyph.
class _StyleSwatches extends StatelessWidget {
  const _StyleSwatches({required this.style, required this.onChanged});
  final QuoteWidgetStyle style;
  final ValueChanged<QuoteWidgetStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in QuoteWidgetStyle.values)
          _StyleSwatch(
            style: s,
            selected: s == style,
            onTap: () => onChanged(s),
          ),
      ],
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({
    required this.style,
    required this.selected,
    required this.onTap,
  });
  final QuoteWidgetStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const size = 54.0;

    Widget fill;
    if (style.isAuto) {
      fill = DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ReadendarTokens.paper100, ReadendarTokens.ink900],
            stops: [0.5, 0.5],
          ),
        ),
        child: Center(
          child: Icon(LucideIcons.contrast, size: 18, color: c.accent),
        ),
      );
    } else {
      final p = paletteFor(shareCardStyleFor(style)!);
      fill = DecoratedBox(
        decoration: BoxDecoration(color: p.background, gradient: p.gradient),
        child: style == QuoteWidgetStyle.coverGradient
            ? const Center(
                child: Icon(
                  LucideIcons.image,
                  size: 18,
                  color: ReadendarTokens.paper50,
                ),
              )
            : null,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('quoteStyle_${style.wire}'),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c.accent : c.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                fill,
                if (selected)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        size: 11,
                        color: ReadendarTokens.paper50,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CadenceChips extends StatelessWidget {
  const _CadenceChips({required this.cadence, required this.onChanged});
  final QuotesWidgetCadence cadence;
  final ValueChanged<QuotesWidgetCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final labels = {
      QuotesWidgetCadence.hourly: l.quotesWidgetCadenceHourly,
      QuotesWidgetCadence.sixHourly: l.quotesWidgetCadence6h,
      QuotesWidgetCadence.daily: l.quotesWidgetCadenceDaily,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in QuotesWidgetCadence.values)
          ChoiceChip(
            label: Text(labels[c]!),
            selected: cadence == c,
            onSelected: (_) => onChanged(c),
          ),
      ],
    );
  }
}

/// A tap-to-choose tile showing the current selection (or a "choose…" hint).
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null ? c.fg3 : c.fg1,
                    fontWeight: value == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronDown, size: 18, color: c.fg3),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAddQuote});
  final VoidCallback onAddQuote;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return EmptyState(
      icon: LucideIcons.quote,
      message: l.quotesWidgetConfigNeedQuotes,
      action: RdButton.primary(
        onPressed: onAddQuote,
        icon: LucideIcons.plus,
        label: l.quoteAdd,
      ),
    );
  }
}

/// One row in the book/quote picker sheet.
class _PickerEntry {
  const _PickerEntry({
    required this.value,
    required this.label,
    required this.coverUrl,
    required this.coverTitle,
    this.sub,
  });

  final String value;
  final String label;
  final String? sub;
  final String coverUrl;

  /// Book title, for the cover fallback letter (may differ from [label] in the
  /// quote picker, where the label is the quote text).
  final String coverTitle;

  bool matches(String needle) {
    if (needle.isEmpty) return true;
    final n = needle.toLowerCase();
    return label.toLowerCase().contains(n) ||
        (sub?.toLowerCase().contains(n) ?? false);
  }
}

/// A searchable picker sheet with book covers — shared by the "one book" and
/// "one fixed quote" selectors. Owns its search controller (a StatefulWidget so
/// dispose runs); pops the chosen [_PickerEntry.value].
///
/// Fixed height, not [DraggableScrollableSheet]: the modal sheet chrome hugs
/// children in an unbounded Column, which makes a draggable sheet lay out at
/// infinite height (dimmed overlay, no list).
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selected,
  });

  final String title;
  final String searchHint;
  final List<_PickerEntry> items;
  final String? selected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final needle = _search.text.trim();
    final filtered = widget.items.where((it) => it.matches(needle)).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            RdSearchField(
              controller: _search,
              hintText: widget.searchHint,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          AppL10n.of(context).searchNoResults,
                          style: TextStyle(color: c.fg3),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final it = filtered[i];
                          return ListTile(
                            leading: _CoverThumb(
                              coverUrl: it.coverUrl,
                              title: it.coverTitle,
                            ),
                            title: Text(
                              it.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: it.sub == null
                                ? null
                                : Text(
                                    it.sub!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: it.value == widget.selected
                                ? Icon(LucideIcons.check, color: c.accent)
                                : null,
                            onTap: () => Navigator.of(context).pop(it.value),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small book-cover thumbnail (artwork, else a periwinkle initial), matching
/// the cover chips used across the quotes surfaces.
class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.coverUrl, required this.title});
  final String coverUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 34,
      height: 48,
      color: ReadendarTokens.periwinkle600,
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: const TextStyle(
          color: ReadendarTokens.paper50,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 34,
        height: 48,
        child: RemoteCoverImage(
          url: coverUrl,
          tier: CoverDisplayTier.thumb,
          placeholder: fallback,
          error: fallback,
        ),
      ),
    );
  }
}
