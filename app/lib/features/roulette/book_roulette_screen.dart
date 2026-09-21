import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/search/search_screen.dart';

/// Shelves the roulette can draw from. Read/abandoned stay out of the pool.
/// Order is display order: Pending / Wanted first; Reading last (off by default).
const List<String> kRouletteStatuses = [
  BookStatus.pending,
  BookStatus.wanted,
  BookStatus.reading,
];

/// Pushes the full-screen book roulette. The single entry point shared by
/// Home, Library and the celebration screen so all three stay in sync.
Future<void> openBookRoulette(BuildContext context) {
  return Navigator.of(
    context,
  ).push(
    rdPageRoute<void>(context, builder: (_) => const BookRouletteScreen()),
  );
}

/// Full-screen "spin to pick your next read" experience. Pushed as a route
/// from Home, Library and the finish-a-book celebration. Readers toggle
/// Reading / Pending / Wanted badges to build the pool:
///   * 0 matching → empty (add books, or turn shelves back on)
///   * 1 → show that book + nudge to add more
///   * 2+ → the [_RouletteWheel]
class BookRouletteScreen extends ConsumerStatefulWidget {
  const BookRouletteScreen({super.key});

  @override
  ConsumerState<BookRouletteScreen> createState() => _BookRouletteScreenState();
}

class _BookRouletteScreenState extends ConsumerState<BookRouletteScreen> {
  /// Pending + Wanted on by default; Reading starts off (badge last in row).
  final Set<String> _selected = {
    BookStatus.pending,
    BookStatus.wanted,
  };

  void _toggleStatus(String status, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(status);
      } else {
        _selected.remove(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final books = ref.watch(booksProvider);
    return RevalidateOnEnter(
      providers: [booksProvider],
      child: Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(title: Text(l.celebrationRoulette)),
        body: SafeArea(
          top: false,
          child: books.when(
            skipError: true,
            loading: RdProgress.centered,
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(booksProvider),
            ),
            data: (list) {
              final eligible = list
                  .where((b) => kRouletteStatuses.contains(b.status))
                  .toList(growable: false);
              final pool = eligible
                  .where((b) => _selected.contains(b.status))
                  .toList(growable: false);
              // Badges sit under the roulette so the wheel stays the hero.
              return Column(
                children: [
                  Expanded(
                    child: _body(eligible: eligible, pool: pool),
                  ),
                  _RouletteStatusFilters(
                    selected: _selected,
                    onToggle: _toggleStatus,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body({required List<Book> eligible, required List<Book> pool}) {
    if (pool.isEmpty) {
      return _RouletteEmpty(hasEligibleBooks: eligible.isNotEmpty);
    }
    if (pool.length == 1) {
      return _RouletteSingle(book: pool.first);
    }
    return _RouletteWheel(
      // Recreate when the pool membership changes so the PageController and
      // spin state stay in sync with the selected shelves.
      key: ValueKey(pool.map((b) => b.id).join(',')),
      books: pool,
    );
  }
}

/// Reading / Pending / Wanted badges under the wheel. Active = filled with the
/// status soft tint + matching icon/label; inactive = outline ghost.
class _RouletteStatusFilters extends StatelessWidget {
  const _RouletteStatusFilters({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String status, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ReadendarTokens.sp5,
        ReadendarTokens.sp2,
        ReadendarTokens.sp5,
        ReadendarTokens.sp5,
      ),
      child: Row(
        children: [
          for (var i = 0; i < kRouletteStatuses.length; i++) ...[
            if (i > 0) const SizedBox(width: ReadendarTokens.sp3),
            Expanded(
              child: _RouletteStatusBadge(
                key: Key('roulette-status-${kRouletteStatuses[i]}'),
                status: kRouletteStatuses[i],
                label: bookStatusLabel(l, kRouletteStatuses[i]),
                active: selected.contains(kRouletteStatuses[i]),
                onTap: () => onToggle(
                  kRouletteStatuses[i],
                  !selected.contains(kRouletteStatuses[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouletteStatusBadge extends StatelessWidget {
  const _RouletteStatusBadge({
    required this.status,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String status;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = bookStatusColor(status, c);
    final bg = bookStatusTint(status, c);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: ReadendarTokens.sp2,
            vertical: ReadendarTokens.sp3,
          ),
          decoration: BoxDecoration(
            color: active ? bg : Colors.transparent,
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
            border: Border.all(
              color: active ? bg : fg.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                bookStatusIcon(status),
                size: 16,
                color: active ? fg : fg.withValues(alpha: 0.45),
              ),
              const SizedBox(width: ReadendarTokens.sp2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? fg : fg.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes the add-book search flow and refreshes the book list on return, so a
/// freshly added eligible book is immediately spinnable.
Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
  await Navigator.of(
    context,
  ).push(rdPageRoute<void>(context, builder: (_) => const SearchScreen()));
  ref.invalidate(booksProvider);
}

class _RouletteEmpty extends ConsumerWidget {
  const _RouletteEmpty({required this.hasEligibleBooks});

  /// True when Reading/Pending/Wanted have books, but none match the active
  /// shelf badges — nudge to re-enable filters instead of "add books".
  final bool hasEligibleBooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    if (hasEligibleBooks) {
      return EmptyState(
        icon: LucideIcons.galleryHorizontal,
        message: l.rouletteEmptyFilteredMessage,
      );
    }
    return EmptyState(
      icon: LucideIcons.galleryHorizontal,
      message: l.rouletteEmptyMessage,
      action: RdButton.primary(
        onPressed: () async => _openSearch(context, ref),
        icon: LucideIcons.bookPlus,
        label: l.rouletteAddBooks,
      ),
    );
  }
}

class _RouletteSingle extends ConsumerWidget {
  const _RouletteSingle({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ReadendarTokens.sp7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              onTap: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => BookDetailScreen(bookId: book.id),
                ),
              ),
              child: BookCover(
                title: book.title,
                author: book.authors.isEmpty ? null : book.authors.first,
                coverUrl: book.coverUrl.isEmpty ? null : book.coverUrl,
                size: BookCoverSize.lg,
                color: ReadendarTokens.teal500,
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp5),
            Text(
              l.rouletteSingleMessage(book.title),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.colors.fg2),
            ),
            const SizedBox(height: ReadendarTokens.sp6),
            RdButton.primary(
              onPressed: () async => _openSearch(context, ref),
              icon: LucideIcons.bookPlus,
              label: l.rouletteAddMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// The roulette itself: a curved, coverflow-style carousel of covers that the
/// user flings to spin. Side covers recede in scale, depth (perspective) and a
/// downward arc so the books read as arranged around a circle. The winner is
/// picked up-front; a fling triggers a canned decelerating spin that snaps the
/// chosen cover to the centre, above the pointer.
class _RouletteWheel extends StatefulWidget {
  const _RouletteWheel({required this.books, super.key});

  final List<Book> books;

  @override
  State<_RouletteWheel> createState() => _RouletteWheelState();
}

class _RouletteWheelState extends State<_RouletteWheel>
    with SingleTickerProviderStateMixin {
  // Each cover occupies one PageView "page"; snapping guarantees an exact
  // landing on the centre book. A narrow viewport fraction shows several
  // neighbours at once for the carousel feel.
  static const double _viewportFraction = 0.42;
  // Fling speed (px/s) above which a drag-release "accelerates" into a spin
  // instead of springing back to the resting book.
  static const double _flingThreshold = 220;

  final _rng = math.Random();
  late final PageController _page;
  late final ConfettiController _confetti;
  // Drives the staggered fade-in of the winner panel.
  late final AnimationController _reveal;

  // Start deep inside the (virtually huge) page range so there is always room
  // to spin forward. PageController.initialPage centres us without a post-frame
  // jump, so opening the screen is smooth.
  late final int _initialPage = _n * 500;

  bool _spinning = false;
  bool _landed = false;
  bool _dragging = false;
  Book? _winner;
  int _lastTick = -1; // last centred page a tick haptic fired for
  late int _restPage = _initialPage; // page to spring back to after a soft drag

  int get _n => widget.books.length;

  @override
  void initState() {
    super.initState();
    _page = PageController(
      initialPage: _initialPage,
      viewportFraction: _viewportFraction,
    )..addListener(_onPage);
    _confetti = ConfettiController(
      duration: const Duration(milliseconds: 1100),
    );
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _page.dispose();
    _confetti.dispose();
    _reveal.dispose();
    super.dispose();
  }

  int get _currentPage {
    if (_page.hasClients &&
        _page.position.haveDimensions &&
        _page.page != null) {
      return _page.page!.round();
    }
    return _initialPage;
  }

  // Fire a light "tick" each time a new cover crosses the centre while the
  // wheel is in motion (a real spin or a finger drag).
  void _onPage() {
    if (!_spinning && !_dragging) return;
    final centered = _currentPage;
    if (centered != _lastTick) {
      _lastTick = centered;
      HapticFeedback.selectionClick();
    }
  }

  // ── Drag: the strip follows the finger; releasing fast accelerates into a
  // spin, releasing slow springs back to the resting book. ──────────────────
  void _onDragStart(DragStartDetails _) {
    if (_spinning) return;
    _dragging = true;
    _restPage = _currentPage;
    _lastTick = _currentPage;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || !_page.hasClients) return;
    final pos = _page.position;
    final next = (pos.pixels - details.delta.dx).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    _page.jumpTo(next);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!_dragging) return;
    _dragging = false;
    final v = details.primaryVelocity ?? 0;
    if (v.abs() >= _flingThreshold) {
      // Swiping left (negative velocity) advances the strip; swiping right
      // sends it the other way — the wheel spins toward the flick.
      await _spin(forward: v < 0);
    } else if (_page.hasClients) {
      // Not enough to launch — glide back to where we started.
      await _page.animateToPage(
        _restPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  // [forward] spins toward increasing pages (a leftward swipe); when null the
  // direction is random (tap / "spin again").
  Future<void> _spin({bool? forward}) async {
    if (_spinning) return;
    final dir = forward ?? _rng.nextBool();
    _reveal.reset();
    setState(() {
      _spinning = true;
      _landed = false;
      _winner = null;
    });

    final winner = _rng.nextInt(_n); // fully random each spin (repeats allowed)
    final loops = 4 + _rng.nextInt(4); // 4..7 full passes for the spin feel
    final base = _currentPage;
    final int target;
    if (dir) {
      final fwd = ((winner - base) % _n + _n) % _n;
      target = base + loops * _n + fwd;
    } else {
      final back = ((base - winner) % _n + _n) % _n;
      target = base - loops * _n - back;
    }
    final ms = 3200 + _rng.nextInt(2300); // random 3.2–5.5s

    _lastTick = base;
    await _page.animateToPage(
      target,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;

    _restPage = target;
    setState(() {
      _spinning = false;
      _landed = true;
      _winner = widget.books[winner];
    });
    _confetti.play();
    unawaited(_reveal.forward(from: 0));
    await HapticFeedback.mediumImpact();
  }

  // Tapping also spins; allowed any time the wheel is at rest (re-spin too).
  void _trySpin() {
    if (!_spinning) _spin();
  }

  void _openWinner() {
    final w = _winner;
    if (w == null) return;
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => BookDetailScreen(bookId: w.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // The header floats in the upper area (flanked by Spacers so it sits more
    // centred than pinned to the top). The wheel follows, and the panel lives
    // in a fixed Expanded region below it, top-anchored and scrollable — so
    // revealing the winner fills already reserved space without shoving the
    // wheel up, and never overflows.
    return Column(
      children: [
        const Spacer(),
        _header(l),
        const Spacer(),
        _wheel(),
        const SizedBox(height: ReadendarTokens.sp2),
        Expanded(flex: 5, child: SingleChildScrollView(child: _panel(l))),
      ],
    );
  }

  Widget _header(AppL10n l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ReadendarTokens.sp7),
      child: Column(
        children: [
          Text(
            l.rouletteTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ReadendarTokens.fontUi,
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.1,
              color: context.colors.accent,
            ),
          ),
          const SizedBox(height: ReadendarTokens.sp3),
          // Persistent "swipe to spin" caption.
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.moveHorizontal,
                size: 16,
                color: context.colors.fgFaint,
              ),
              const SizedBox(width: ReadendarTokens.sp2),
              Text(
                l.rouletteSwipeHint,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.colors.fgFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wheel() {
    return RepaintBoundary(
      key: const Key('roulette-repaint-boundary'),
      child: SizedBox(
        height: 268,
        child: GestureDetector(
          key: const Key('roulette-strip'),
          behavior: HitTestBehavior.opaque,
          // Drag follows the finger; a fast release accelerates into a spin, a
          // soft release springs back. A tap also spins.
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTap: _trySpin,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Edge-faded carousel: covers melt away at the left/right edges.
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0, 0.2, 0.8, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: PageView.builder(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _n * 1000,
                  itemBuilder: (context, i) {
                    final b = widget.books[i % _n];
                    // Built once per item; the AnimatedBuilder only recomputes the
                    // cheap transform as the page offset changes.
                    final cover = RepaintBoundary(
                      child: BookCover(
                        title: b.title,
                        author: b.authors.isEmpty ? null : b.authors.first,
                        coverUrl: b.coverUrl.isEmpty ? null : b.coverUrl,
                        color: ReadendarTokens.teal500,
                      ),
                    );
                    return AnimatedBuilder(
                      animation: _page,
                      child: cover,
                      builder: (context, child) => _depth(i, child!),
                    );
                  },
                ),
              ),
              // Straight editorial rails and fixed bookmark pointers frame the
              // selection without competing with the carousel motion.
              Positioned.fill(child: _portalChrome()),
              // Confetti bursts from the centre book on landing.
              ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 18,
                maxBlastForce: 22,
                minBlastForce: 8,
                gravity: 0.3,
                colors: ReadendarTokens.confettiColors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portalChrome() {
    final c = context.colors;
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            height: 40,
            child: CustomPaint(
              key: const Key('roulette-rail-top'),
              painter: _EditorialRailPainter(
                lineAtBottom: true,
                color: c.accent,
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            height: 40,
            child: CustomPaint(
              key: const Key('roulette-rail-bottom'),
              painter: _EditorialRailPainter(
                lineAtBottom: false,
                color: c.accent,
              ),
            ),
          ),
          Positioned(
            key: const Key('roulette-pointer-top-position'),
            top: 21,
            child: Transform.rotate(
              angle: math.pi,
              child: CustomPaint(
                key: const Key('roulette-pointer-top'),
                size: const Size(18, 24),
                painter: _BookmarkPointerPainter(color: c.accent),
              ),
            ),
          ),
          Positioned(
            key: const Key('roulette-pointer-bottom-position'),
            bottom: 21,
            child: CustomPaint(
              key: const Key('roulette-pointer-bottom'),
              size: const Size(18, 24),
              painter: _BookmarkPointerPainter(color: c.accent),
            ),
          ),
        ],
      ),
    );
  }

  /// Positions [child] in the carousel by its distance from the centred page:
  /// recede in scale, rotate in perspective, drop along an arc and fade — so
  /// the covers read as arranged around a circle with depth.
  Widget _depth(int index, Widget child) {
    var page = _initialPage.toDouble();
    if (_page.hasClients && _page.position.haveDimensions) {
      page = _page.page ?? page;
    }
    final delta = index - page;
    final ad = delta.abs();
    final focus = (1 - ad).clamp(0.0, 1.0);
    final opacity = (1 - ad * 0.42).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    final scale = (1 - ad * 0.26).clamp(0.4, 1.0);
    final dy = ad * ad * 16.0; // parabolic arc: edges sink below the centre
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0016) // perspective
      ..rotateY(-delta * 0.34); // coverflow turn toward the centre
    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Center(
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  _saturationMatrix(0.62 + focus * 0.38),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Wraps [child] in a quick fade + slight slide-up over the [begin]–[end]
  // slice of the reveal controller, so the winner details cascade in.
  Widget _revealChild(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _reveal,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Widget _panel(AppL10n l) {
    final winner = _winner;
    if (!_landed || winner == null) return const SizedBox.shrink();
    return Padding(
      key: const Key('roulette-winner-panel'),
      padding: const EdgeInsets.symmetric(horizontal: ReadendarTokens.sp7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _revealChild(
            0,
            0.4,
            Text(
              l.rouletteWinnerLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: ReadendarTokens.sp2),
          _revealChild(
            0.12,
            0.52,
            Text(
              winner.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: ReadendarTokens.fontDisplay,
              ),
            ),
          ),
          if (winner.authors.isNotEmpty) ...[
            const SizedBox(height: ReadendarTokens.sp1),
            _revealChild(
              0.24,
              0.64,
              Text(
                winner.authors.join(', '),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.colors.fg2),
              ),
            ),
          ],
          const SizedBox(height: ReadendarTokens.sp6),
          // Stacked actions: primary open, then spin again beneath it.
          _revealChild(
            0.36,
            0.78,
            SizedBox(
              width: double.infinity,
              child: RdButton.primary(
                onPressed: _openWinner,
                icon: LucideIcons.bookOpen,
                label: l.rouletteOpenBook,
                expand: true,
              ),
            ),
          ),
          const SizedBox(height: ReadendarTokens.sp3),
          _revealChild(
            0.5,
            0.92,
            SizedBox(
              width: double.infinity,
              child: RdButton.secondary(
                onPressed: _spin,
                icon: LucideIcons.galleryHorizontal,
                label: l.rouletteSpinAgain,
                expand: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<double> _saturationMatrix(double saturation) {
  final inverse = 1 - saturation;
  final red = 0.213 * inverse;
  final green = 0.715 * inverse;
  final blue = 0.072 * inverse;
  return [
    red + saturation,
    green,
    blue,
    0,
    0,
    red,
    green + saturation,
    blue,
    0,
    0,
    red,
    green,
    blue + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// Straight selection rail aligned with the bookmark pointer tip.
class _EditorialRailPainter extends CustomPainter {
  const _EditorialRailPainter({
    required this.lineAtBottom,
    required this.color,
  });

  final bool lineAtBottom;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = lineAtBottom ? size.height - 9 : 9.0;
    final railPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(ReadendarTokens.sp4, y),
      Offset(size.width - ReadendarTokens.sp4, y),
      railPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EditorialRailPainter oldDelegate) =>
      oldDelegate.lineAtBottom != lineAtBottom || oldDelegate.color != color;
}

/// Thin, solid bookmark marker pointing toward the selected cover.
class _BookmarkPointerPainter extends CustomPainter {
  const _BookmarkPointerPainter({required this.color});

  final Color color;

  Path _path(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, 7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 7)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_path(size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
