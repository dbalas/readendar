import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_image.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/search/search_empty_art.dart';

/// Search-and-pick screen for a catalog cover. Hits without a usable cover are
/// hidden. Used by import "improve covers" and the book edit form.
class CoverPickerScreen extends ConsumerStatefulWidget {
  const CoverPickerScreen({
    required this.query,
    required this.author,
    super.key,
  });
  final String query;
  final String author;

  @override
  ConsumerState<CoverPickerScreen> createState() => _CoverPickerScreenState();
}

class _CoverPickerScreenState extends ConsumerState<CoverPickerScreen> {
  late final TextEditingController _controller;
  List<SearchHit> _hits = const [];
  bool _loading = false;
  bool _searched = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: [widget.query, widget.author].where((s) => s.isNotEmpty).join(' '),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      _generation++;
      setState(() {
        _loading = false;
        _searched = false;
        _hits = const [];
        _error = null;
      });
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _hits = const [];
    });
    final res = await ref
        .read(searchRepoProvider)
        .search(q, allLanguages: true);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      switch (res) {
        case Ok(:final value):
          _hits = value.items
              .where((h) => isUsableCoverUrl(h.coverUrl))
              .toList();
          _error = null;
        case Err(:final failure):
          _hits = const [];
          _error = failure;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.importImproveSearchTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(ReadendarTokens.sp4),
              child: RdSearchField(
                controller: _controller,
                hintText: l.importImproveSearchHint,
                showSubmitButton: true,
                submitTooltip: l.actionSearch,
                onSubmitted: (_) => _search(),
                onClear: () => setState(() {
                  _generation++;
                  _hits = const [];
                  _error = null;
                  _searched = false;
                  _loading = false;
                }),
              ),
            ),
            Expanded(child: _body(l)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppL10n l) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RdProgress(size: 36, strokeWidth: 3),
            const SizedBox(height: 12),
            Text(
              l.searchSearching,
              style: TextStyle(color: context.colors.fgFaint),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return ErrorRetry(error: _error!, onRetry: _search);
    }
    if (_hits.isEmpty) {
      return EmptyState(
        illustration: const SearchEmptyArt(),
        message: _searched ? l.searchNoResults : l.searchEmptyHint,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(ReadendarTokens.sp4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: ReadendarTokens.sp3,
        mainAxisSpacing: ReadendarTokens.sp3,
      ),
      itemCount: _hits.length,
      itemBuilder: (context, i) {
        final h = _hits[i];
        return Semantics(
          button: true,
          label: h.title,
          child: GestureDetector(
            key: ValueKey('cover-pick-${h.dedupeKey}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              child: SizedBox.expand(
                child: RemoteCoverImage(
                  url: h.coverUrl,
                  error: const CoverMissingPlaceholder(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
