import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/celebration/celebration_metrics.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/rating_review_sheet.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen "you finished a book" celebration: confetti + fireworks, the
/// book, a few proud metrics, and next-step actions. Pushed as a route above
/// the shell when a book's status transitions into `read`.
class CelebrationScreen extends ConsumerStatefulWidget {
  const CelebrationScreen({required this.book, super.key});

  final Book book;

  @override
  ConsumerState<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends ConsumerState<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  // One long confetti rain from the top, plus several firework bursts fired in
  // a stagger so the screen reads as a sustained, festive celebration.
  late final ConfettiController _rain;
  late final List<ConfettiController> _fireworks;

  // Drives the fast staggered fade/slide-in of each element on open.
  late final AnimationController _entrance;

  // A local copy so rating/note edits made right here on the celebration
  // screen show instantly; persisted in the background to the personal copy.
  late Book _book = widget.book;

  @override
  void initState() {
    super.initState();
    // ~3× longer than the first pass: a 6s rain and five 2.1s bursts.
    _rain = ConfettiController(duration: const Duration(seconds: 6));
    _fireworks = List.generate(
      5,
      (_) => ConfettiController(duration: const Duration(milliseconds: 2100)),
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    if ((media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false)) {
      _entrance.value = 1;
    }
  }

  /// Wraps [child] in a fast fade + slight slide-up, timed to the [begin]–[end]
  /// slice of the entrance controller so elements cascade in.
  Widget _appear(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Future<void> _celebrate() async {
    if (!mounted) return;
    final identity = ReadendarThemes.byId(
      context.readendarTheme.id,
    ).identity.effect;
    if (identity != ReadendarIdentityEffect.none) return;
    _rain.play();
    for (var i = 0; i < _fireworks.length; i++) {
      if (!mounted) return;
      _fireworks[i].play();
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _rain.dispose();
    for (final c in _fireworks) {
      c.dispose();
    }
    super.dispose();
  }

  void _share() {
    final l = AppL10n.of(context);
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: l.celebrationShareMessage(_book.title)),
      ),
    );
  }

  Future<void> _editRatingReview() async {
    final value = await showRatingReviewSheet(
      context,
      currentRating: _book.rating,
      currentReview: _book.reviewMarkdown,
    );
    if (value == null || !mounted) return;
    final prev = _book;
    setState(
      () => _book = _book.copyWith(
        rating: value.rating,
        clearRating: value.rating == null,
        reviewMarkdown: value.review,
      ),
    );
    final r = await ref
        .read(bookRepoProvider)
        .updateRatingReview(
          _book.id,
          rating: value.rating,
          reviewMarkdown: value.review,
        );
    if (!mounted) return;
    r.fold(
      (book) {
        setState(() => _book = book);
        ref
          ..invalidate(bookProvider(_book.id))
          ..invalidate(booksProvider)
          ..invalidatePersonalStats();
      },
      (f) {
        setState(() => _book = prev);
        showRdFailureToast(context, f);
      },
    );
  }

  Future<void> _close([int? sessions]) async {
    final count = sessions ?? _promptSessions();
    if (!mounted) return;
    Navigator.of(context).pop(count);
  }

  /// Sessions to feed the post-celebration store-review gate.
  int? _promptSessions() {
    final events = ref.read(bookEventsHistoryProvider(_book.id)).value;
    if (events == null) return 0;
    final progress = ref.read(progressProvider(_book.id)).value;
    return CelebrationMetrics.from(
          book: _book,
          events: events,
          progress: progress,
        ).sessions ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final b = _book;
    final themeId = context.readendarTheme.id;

    final events = ref.watch(bookEventsHistoryProvider(b.id)).value;
    final progress = ref.watch(progressProvider(b.id)).value;
    final metrics = events == null
        ? null
        : CelebrationMetrics.from(book: b, events: events, progress: progress);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: DecoratedBox(
          decoration: BoxDecoration(color: context.colors.bg),
          child: Stack(
            children: [
              // Festive backdrop: solid little book shapes scattered at low
              // opacity over plain paper.
              Positioned.fill(
                child: CustomPaint(
                  key: ValueKey('celebrationThemeBackdrop-${themeId.wire}'),
                  painter: _FestiveBackgroundPainter(themeId),
                ),
              ),
              _confettiLayer(themeId),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: RdIconButton(
                        icon: LucideIcons.x,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => unawaited(_close()),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            ReadendarTokens.sp7,
                            ReadendarTokens.sp3,
                            ReadendarTokens.sp7,
                            ReadendarTokens.sp7,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight -
                                  ReadendarTokens.sp3 -
                                  ReadendarTokens.sp7,
                            ),
                            // A single uniform gap (sp7) sits between every
                            // group, with a tighter consistent rhythm inside
                            // each, so the screen stays evenly spaced at any
                            // height — instead of spaceEvenly's variable gaps.
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ── Block 1: headline ────────────────────
                                _appear(
                                  0,
                                  0.4,
                                  Text(
                                    l.celebrationTitle,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: context.colors.accent,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: ReadendarTokens.sp7),
                                // ── Block 2: cover ───────────────────────
                                _appear(
                                  0.24,
                                  0.62,
                                  BookCover(
                                    title: b.title,
                                    author: b.authors.isNotEmpty
                                        ? b.authors.first
                                        : null,
                                    coverUrl: b.coverUrl.isEmpty
                                        ? null
                                        : b.coverUrl,
                                    size: BookCoverSize.lg,
                                    width: 120,
                                  ),
                                ),
                                const SizedBox(height: ReadendarTokens.sp7),
                                // ── Block 3: book title + author ─────────
                                _appear(
                                  0.36,
                                  0.74,
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        b.title,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontFamily:
                                                  ReadendarTokens.fontDisplay,
                                            ),
                                      ),
                                      if (b.authors.isNotEmpty) ...[
                                        const SizedBox(
                                          height: ReadendarTokens.sp2,
                                        ),
                                        Text(
                                          b.authors.join(', '),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: context.colors.fg2,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // ── Block 4: metrics (optional) ──────────
                                if (metrics != null && metrics.hasAny) ...[
                                  const SizedBox(height: ReadendarTokens.sp7),
                                  _appear(
                                    0.46,
                                    0.84,
                                    _MetricsRow(metrics: metrics),
                                  ),
                                ],
                                // ── Block 5: rating + public review ──────
                                const SizedBox(height: ReadendarTokens.sp7),
                                _appear(0.5, 0.92, _rateAndNote(l)),
                                // ── Block 6: actions ─────────────────────
                                const SizedBox(height: ReadendarTokens.sp7),
                                _appear(0.56, 1, _actions(l)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rateAndNote(AppL10n l) {
    final rating = _book.rating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.celebrationRatePrompt,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: context.colors.accent2),
        ),
        const SizedBox(height: ReadendarTokens.sp3),
        // Same pattern as book detail: static stars → tap opens rating+review.
        InkWell(
          key: const Key('celebrationHeaderRating'),
          onTap: _editRatingReview,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ReadendarTokens.sp3,
              vertical: ReadendarTokens.sp2,
            ),
            child: BookRatingDisplay(
              rating: rating,
              review: _book.reviewMarkdown,
              showEditHint: true,
              crossAxisAlignment: CrossAxisAlignment.center,
              reviewKey: const Key('celebrationReviewPreview'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(AppL10n l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RdButton.primary(
          key: const Key('celebrationRateCta'),
          onPressed: _editRatingReview,
          icon: LucideIcons.star,
          label: l.celebrationRatePrompt,
        ),
        RdButton.plain(
          onPressed: _share,
          icon: LucideIcons.share2,
          label: l.celebrationShare,
        ),
      ],
    );
  }

  Widget _confettiLayer(ReadendarThemeId themeId) {
    final definition = ReadendarThemes.byId(themeId);
    if (definition.identity.effect == ReadendarIdentityEffect.ethereal) {
      return Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) => CustomPaint(
                key: const Key('etherealCelebrationOrbit'),
                painter: _EtherealCelebrationPainter(
                  progress: _entrance.value,
                  accent: context.colors.accent,
                  gold: context.colors.accent2,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (definition.identity.effect != ReadendarIdentityEffect.none) {
      final identity = definition.identity.effect;
      return Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) => CustomPaint(
                key: Key('premiumCelebration-${identity.name}'),
                painter: _PremiumIdentityCelebrationPainter(
                  identity: identity,
                  progress: _entrance.value,
                  primary: context.colors.accent,
                  secondary: context.colors.accent2,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final celebrationColors = definition.isPremium
        ? <Color>[
            definition.light.accent,
            definition.light.accent2,
            definition.dark.accent,
            definition.dark.accent2,
          ]
        : ReadendarTokens.confettiColors;
    return Stack(
      key: const Key('standardCelebrationConfetti'),
      children: [
        // Downward confetti rain from the top edge.
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _rain,
            blastDirection: math.pi / 2, // downward
            emissionFrequency: 0.05,
            numberOfParticles: 12,
            maxBlastForce: 18,
            minBlastForce: 8,
            gravity: 0.25,
            colors: celebrationColors,
          ),
        ),
        // Explosive firework bursts spread across the upper half of the screen.
        for (var i = 0; i < _fireworks.length; i++)
          Align(
            alignment: Alignment(-0.7 + i * 0.35, -0.4 + (i.isEven ? 0 : 0.3)),
            child: ConfettiWidget(
              confettiController: _fireworks[i],
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              maxBlastForce: 26,
              minBlastForce: 12,
              gravity: 0.3,
              colors: celebrationColors,
            ),
          ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final CelebrationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final tiles = <Widget>[
      if (metrics.daysToFinish != null)
        _MetricTile(
          icon: LucideIcons.calendarCheck,
          color: c.accent,
          text: l.celebrationDaysMetric(metrics.daysToFinish!),
        ),
      if (metrics.pagesRead != null)
        _MetricTile(
          icon: LucideIcons.bookOpen,
          color: c.success,
          text: l.celebrationPagesMetric(metrics.pagesRead!),
        ),
      if (metrics.sessions != null)
        _MetricTile(
          icon: LucideIcons.flame,
          color: c.warning,
          text: l.celebrationSessionsMetric(metrics.sessions!),
        ),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: ReadendarTokens.sp3,
      runSpacing: ReadendarTokens.sp3,
      children: tiles,
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ReadendarTokens.sp4,
        vertical: ReadendarTokens.sp3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: ReadendarTokens.sp3),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.fg1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the festive backdrop: a fixed scatter of solid little **books**
/// (a rounded cover with a spine stripe) in brand colours at low opacity,
/// tilted at varied angles. Positions hug the edges so they never compete
/// with the centred content.
class _FestiveBackgroundPainter extends CustomPainter {
  const _FestiveBackgroundPainter(this.themeId);

  final ReadendarThemeId themeId;

  // (dx, dy as fractions of size, cover width in px, colour, tilt in radians).
  static const _books = <(double, double, double, Color, double)>[
    (0.12, 0.10, 40, ReadendarTokens.periwinkle500, -0.30),
    (0.87, 0.14, 34, ReadendarTokens.teal400, 0.35),
    (0.93, 0.42, 26, ReadendarTokens.amber500, -0.20),
    (0.07, 0.37, 30, ReadendarTokens.sage500, 0.25),
    (0.18, 0.82, 38, ReadendarTokens.wine400, 0.18),
    (0.84, 0.80, 32, ReadendarTokens.periwinkle500, -0.32),
    (0.52, 0.05, 22, ReadendarTokens.teal400, 0.12),
    (0.95, 0.91, 20, ReadendarTokens.amber500, -0.15),
    (0.05, 0.60, 24, ReadendarTokens.sage500, -0.22),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final definition = ReadendarThemes.byId(themeId);
    if (definition.identity.effect == ReadendarIdentityEffect.ethereal) {
      _paintEtherealConstellation(canvas, size, definition);
      return;
    }
    if (definition.identity.effect != ReadendarIdentityEffect.none) {
      _paintPremiumIdentity(canvas, size, definition);
      return;
    }
    final premiumColors = <Color>[
      definition.light.accent,
      definition.light.accent2,
      definition.dark.accent,
      definition.dark.accent2,
    ];
    for (var index = 0; index < _books.length; index++) {
      final (fx, fy, w, standardColor, angle) = _books[index];
      final color = definition.isPremium
          ? premiumColors[index % premiumColors.length]
          : standardColor;
      final h = w * 1.4;
      final body = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final spine = Paint()
        ..color = color.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(fx * size.width, fy * size.height);
      canvas.rotate(angle);

      final cover = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cover, const Radius.circular(3)),
        body,
      );
      // Spine stripe down the left edge.
      final spineRect = Rect.fromLTWH(cover.left, cover.top, w * 0.22, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(spineRect, const Radius.circular(3)),
        spine,
      );

      canvas.restore();
    }
  }

  void _paintEtherealConstellation(
    Canvas canvas,
    Size size,
    ReadendarThemeDefinition definition,
  ) {
    final random = math.Random(4307);
    final points = <Offset>[
      for (var index = 0; index < 26; index++)
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
    ];
    final line = Paint()
      ..color = definition.light.accent.withValues(alpha: 0.13)
      ..strokeWidth = 0.8;
    for (var index = 1; index < points.length; index++) {
      if (index % 4 != 0) {
        canvas.drawLine(points[index - 1], points[index], line);
      }
    }
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(
        points[index],
        index % 6 == 0 ? 1.8 : 0.8,
        Paint()
          ..color =
              (index % 6 == 0
                      ? definition.light.accent2
                      : definition.light.accent)
                  .withValues(alpha: 0.28),
      );
    }
  }

  void _paintPremiumIdentity(
    Canvas canvas,
    Size size,
    ReadendarThemeDefinition definition,
  ) {
    final identity = definition.identity.effect;
    final primary = definition.light.accent;
    final secondary = definition.light.accent2;
    final path = Path();
    switch (identity) {
      case ReadendarIdentityEffect.stormbound:
        path
          ..moveTo(size.width * 0.18, 0)
          ..lineTo(size.width * 0.15, size.height * 0.16)
          ..lineTo(size.width * 0.18, size.height * 0.18)
          ..lineTo(size.width * 0.11, size.height * 0.36)
          ..moveTo(size.width * 0.72, 0)
          ..lineTo(size.width * 0.68, size.height * 0.19)
          ..lineTo(size.width * 0.71, size.height * 0.22)
          ..lineTo(size.width * 0.6, size.height * 0.48)
          ..moveTo(size.width * 0.68, size.height * 0.19)
          ..lineTo(size.width * 0.59, size.height * 0.31);
      case ReadendarIdentityEffect.evercourt:
        final summit = Offset(size.width * 0.5, size.height * 0.4);
        final mountain = Path()
          ..moveTo(-size.width * 0.05, size.height * 0.92)
          ..lineTo(size.width * 0.14, size.height * 0.7)
          ..lineTo(size.width * 0.27, size.height * 0.8)
          ..lineTo(summit.dx, summit.dy)
          ..lineTo(size.width * 0.65, size.height * 0.7)
          ..lineTo(size.width * 0.78, size.height * 0.59)
          ..lineTo(size.width * 1.05, size.height * 0.87)
          ..lineTo(size.width * 1.05, size.height * 1.05)
          ..lineTo(-size.width * 0.05, size.height * 1.05)
          ..close();
        canvas.drawPath(
          mountain,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primary.withValues(alpha: 0.12),
                secondary.withValues(alpha: 0.035),
              ],
            ).createShader(mountain.getBounds()),
        );
        final ridge = Path()
          ..moveTo(-size.width * 0.05, size.height * 0.92)
          ..lineTo(size.width * 0.14, size.height * 0.7)
          ..lineTo(size.width * 0.27, size.height * 0.8)
          ..lineTo(summit.dx, summit.dy)
          ..lineTo(size.width * 0.65, size.height * 0.7)
          ..lineTo(size.width * 0.78, size.height * 0.59)
          ..lineTo(size.width * 1.05, size.height * 0.87);
        canvas.drawPath(
          ridge,
          Paint()
            ..color = primary.withValues(alpha: 0.32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.05
            ..strokeJoin = StrokeJoin.bevel,
        );
        final stars = <Offset>[
          Offset(size.width * 0.5, size.height * 0.23),
          Offset(size.width * 0.41, size.height * 0.31),
          Offset(size.width * 0.59, size.height * 0.31),
        ];
        for (var index = 0; index < stars.length; index++) {
          _paintCourtStar(
            canvas,
            stars[index],
            size.shortestSide * (index == 0 ? 0.019 : 0.015),
            (index == 0 ? secondary : primary).withValues(alpha: 0.58),
          );
        }
        return;
      case ReadendarIdentityEffect.neonMoon:
        path
          ..moveTo(size.width * 0.12, size.height * 0.8)
          ..lineTo(size.width * 0.35, size.height * 0.36)
          ..lineTo(size.width * 0.58, size.height * 0.8)
          ..moveTo(size.width * 0.5, size.height * 0.8)
          ..lineTo(size.width * 0.72, size.height * 0.28)
          ..lineTo(size.width * 0.9, size.height * 0.8);
      case ReadendarIdentityEffect.trail:
        for (var index = 0; index < 15; index++) {
          final t = index / 14;
          _paintPaw(
            canvas,
            Offset(size.width * t, size.height * (0.9 - t * 0.62)),
            4.6 + index % 2,
            index.isEven ? primary : secondary,
            claws: true,
          );
        }
        return;
      case ReadendarIdentityEffect.serpents:
        path.moveTo(0, size.height * 0.46);
        for (var index = 0; index <= 24; index++) {
          path.lineTo(
            size.width * index / 24,
            size.height * (0.46 + math.sin(index * 0.72) * 0.18),
          );
        }
      case ReadendarIdentityEffect.thornCrown:
        path.moveTo(0, size.height * 0.72);
        for (var index = 0; index <= 12; index++) {
          path.lineTo(
            size.width * index / 12,
            size.height * (0.68 + math.sin(index * 0.8) * 0.08),
          );
        }
      case ReadendarIdentityEffect.iridescent:
        path
          ..moveTo(size.width * 0.18, size.height)
          ..lineTo(size.width * 0.48, 0)
          ..moveTo(size.width * 0.5, size.height)
          ..lineTo(size.width * 0.8, 0);
      case ReadendarIdentityEffect.lastLight:
        final center = Offset(size.width * 0.68, size.height * 0.3);
        for (var index = 0; index < 3; index++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: 42.0 + index * 34),
            -math.pi / 2 + index,
            math.pi * 1.15,
            false,
            Paint()
              ..color = (index.isEven ? primary : secondary).withValues(
                alpha: 0.16,
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9,
          );
        }
        return;
      case ReadendarIdentityEffect.none || ReadendarIdentityEffect.ethereal:
        return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            secondary.withValues(alpha: 0.2),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _paintCourtStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final star = Path();
    for (var index = 0; index < 16; index++) {
      final angle = -math.pi / 2 + index * math.pi / 8;
      final pointRadius = index.isEven
          ? radius * (index % 4 == 0 ? 1.8 : 1.0)
          : radius * 0.34;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * pointRadius;
      if (index == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  void _paintPaw(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    bool claws = false,
  }) {
    final paint = Paint()..color = color.withValues(alpha: 0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.55),
        width: radius * 1.7,
        height: radius * 1.35,
      ),
      paint,
    );
    for (var toe = 0; toe < 4; toe++) {
      final toeCenter = Offset(
        center.dx + (toe - 1.5) * radius * 0.55,
        center.dy - radius * (0.4 + (toe == 1 || toe == 2 ? 0.18 : 0)),
      );
      canvas.drawCircle(toeCenter, radius * 0.32, paint);
      if (claws) {
        canvas.drawLine(
          toeCenter - Offset(0, radius * 0.4),
          toeCenter - Offset(0, radius * 0.68),
          Paint()
            ..color = paint.color
            ..strokeWidth = 0.65
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FestiveBackgroundPainter oldDelegate) =>
      themeId != oldDelegate.themeId;
}

class _EtherealCelebrationPainter extends CustomPainter {
  const _EtherealCelebrationPainter({
    required this.progress,
    required this.accent,
    required this.gold,
  });

  final double progress;
  final Color accent;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    for (var index = 0; index < 3; index++) {
      final radius = size.width * (0.19 + index * 0.105) * reveal;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + index * 0.55,
        math.pi * (1.15 + index * 0.18) * reveal,
        false,
        Paint()
          ..color = (index.isEven ? accent : gold).withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 1.4 : 0.8,
      );
    }
    final random = math.Random(991);
    for (var index = 0; index < 22; index++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance =
          size.width * (0.12 + random.nextDouble() * 0.42) * reveal;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final intensity = (reveal - index / 44).clamp(0.0, 1.0);
      canvas.drawCircle(
        point,
        index % 5 == 0 ? 2.2 : 1,
        Paint()
          ..color = (index.isEven ? gold : accent).withValues(
            alpha: 0.72 * intensity,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EtherealCelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.gold != gold;
}

class _PremiumIdentityCelebrationPainter extends CustomPainter {
  const _PremiumIdentityCelebrationPainter({
    required this.identity,
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final ReadendarIdentityEffect identity;
  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final center = Offset(size.width / 2, size.height * 0.34);
    final count = switch (identity) {
      ReadendarIdentityEffect.evercourt => 12,
      ReadendarIdentityEffect.stormbound => 8,
      ReadendarIdentityEffect.lastLight => 8,
      ReadendarIdentityEffect.trail => 10,
      ReadendarIdentityEffect.serpents => 13,
      ReadendarIdentityEffect.neonMoon => 10,
      ReadendarIdentityEffect.thornCrown => 11,
      ReadendarIdentityEffect.iridescent => 12,
      _ => 9,
    };
    final angularOffset = identity == ReadendarIdentityEffect.lastLight
        ? progress * 0.45
        : 0.0;
    for (var index = 0; index < count; index++) {
      final angle = -math.pi / 2 + index * math.pi * 2 / count + angularOffset;
      final distance = size.width * (0.14 + (index % 3) * 0.09) * reveal;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final color = index.isEven ? primary : secondary;
      final shapeProgress = (reveal - index / (count * 1.8)).clamp(0.0, 1.0);
      if (shapeProgress <= 0) continue;
      switch (identity) {
        case ReadendarIdentityEffect.stormbound:
          final bolt = Path()
            ..moveTo(point.dx - 1.5, point.dy - 8)
            ..lineTo(point.dx - 3, point.dy - 1)
            ..lineTo(point.dx, point.dy)
            ..lineTo(point.dx - 2, point.dy + 8);
          canvas.drawPath(
            bolt,
            Paint()
              ..color = color.withValues(alpha: 0.72 * shapeProgress)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.square
              ..strokeJoin = StrokeJoin.bevel,
          );
        case ReadendarIdentityEffect.evercourt:
          final radius = 2.5 + index % 3;
          final star = Path()
            ..moveTo(point.dx, point.dy - radius * 1.6)
            ..lineTo(point.dx + radius * 0.5, point.dy)
            ..lineTo(point.dx, point.dy + radius * 1.6)
            ..lineTo(point.dx - radius * 0.5, point.dy)
            ..close();
          canvas.drawPath(
            star,
            Paint()..color = color.withValues(alpha: 0.68 * shapeProgress),
          );
        case ReadendarIdentityEffect.neonMoon:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: point, width: 10, height: 2.2),
              const Radius.circular(2),
            ),
            Paint()..color = color.withValues(alpha: 0.7 * shapeProgress),
          );
        case ReadendarIdentityEffect.trail:
          canvas.drawCircle(
            point + const Offset(0, 2),
            3.8,
            Paint()..color = color.withValues(alpha: 0.66 * shapeProgress),
          );
          for (var toe = 0; toe < 4; toe++) {
            final toePoint = point + Offset(-4.5 + toe * 3, -3.6);
            canvas.drawCircle(
              toePoint,
              1.4,
              Paint()..color = color.withValues(alpha: 0.66 * shapeProgress),
            );
            canvas.drawLine(
              toePoint - const Offset(0, 1.8),
              toePoint - const Offset(0, 3.2),
              Paint()
                ..color = color.withValues(alpha: 0.58 * shapeProgress)
                ..strokeWidth = 0.7,
            );
          }
        case ReadendarIdentityEffect.serpents:
          canvas.drawArc(
            Rect.fromCenter(center: point, width: 12, height: 7),
            angle,
            math.pi * 1.35 * shapeProgress,
            false,
            Paint()
              ..color = color.withValues(alpha: 0.68)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        case ReadendarIdentityEffect.thornCrown:
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 9, height: 4),
            Paint()..color = color.withValues(alpha: 0.64 * shapeProgress),
          );
        case ReadendarIdentityEffect.iridescent:
          canvas.drawLine(
            point - const Offset(5, 8),
            point + const Offset(5, 8),
            Paint()
              ..shader =
                  LinearGradient(
                    colors: [primary, secondary],
                  ).createShader(
                    Rect.fromCenter(center: point, width: 12, height: 18),
                  )
              ..strokeWidth = 2,
          );
        case ReadendarIdentityEffect.lastLight:
          canvas.drawArc(
            Rect.fromCircle(center: point, radius: 5),
            angle,
            math.pi * 1.25 * shapeProgress,
            false,
            Paint()
              ..color = color.withValues(alpha: 0.68)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        case ReadendarIdentityEffect.none || ReadendarIdentityEffect.ethereal:
          return;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _PremiumIdentityCelebrationPainter oldDelegate,
  ) =>
      oldDelegate.identity != identity ||
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
