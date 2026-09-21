import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/features/onboarding/onboarding_slide.dart';
import 'package:readendar/features/onboarding/onboarding_slides.dart';
import 'package:readendar/features/onboarding/widgets/onboarding_page_dots.dart';

/// The first-run feature carousel: a swipeable, always-skippable tour of the
/// app's headline features. Calls [onFinish] when the user taps "Get started"
/// on the last slide or "Skip" from anywhere.
///
/// Each slide owns its own entrance controller that plays a one-shot cascade
/// the first time it becomes the active slide. Because neighbours pre-built by
/// the [PageView] sit at entrance 0 (invisible) until they're reached — and the
/// one being left keeps its finished value — slides never snap from visible to
/// hidden, so there's no flicker.
class OnboardingTourScreen extends StatefulWidget {
  const OnboardingTourScreen({required this.onFinish, super.key});

  final VoidCallback onFinish;

  @override
  State<OnboardingTourScreen> createState() => _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends State<OnboardingTourScreen> {
  final _controller = PageController();

  // Built once per locale; the carousel content is otherwise stable.
  late List<OnboardingSlide> _slides;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slides = buildOnboardingSlides(AppL10n.of(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Live fractional page position (for the dots), or the settled index before
  /// the controller has attached/measured.
  double get _livePage =>
      _controller.hasClients && _controller.position.haveDimensions
      ? (_controller.page ?? _index.toDouble())
      : _index.toDouble();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final accent = _slides[_index].accent;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) =>
                    _TourPage(slide: _slides[i], isActive: i == _index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ReadendarTokens.sp7,
                ReadendarTokens.sp4,
                ReadendarTokens.sp7,
                ReadendarTokens.sp6,
              ),
              child: Column(
                children: [
                  // Only the dots track the live fractional page, so a swipe
                  // repaints just this strip — not the PageView or the buttons.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => OnboardingPageDots(
                      count: _slides.length,
                      page: _livePage,
                      activeColor: accent,
                    ),
                  ),
                  const SizedBox(height: ReadendarTokens.sp6),
                  Row(
                    children: [
                      if (!isLast)
                        RdButton.plain(
                          onPressed: widget.onFinish,
                          label: l.tourSkip,
                        ),
                      const Spacer(),
                      RdButton.primary(
                        onPressed: isLast ? widget.onFinish : _next,
                        icon: isLast ? null : LucideIcons.arrowRight,
                        label: isLast ? l.tourGetStarted : l.tourNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourPage extends StatefulWidget {
  const _TourPage({required this.slide, required this.isActive});

  final OnboardingSlide slide;
  final bool isActive;

  @override
  State<_TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<_TourPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _played = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _play();
  }

  @override
  void didUpdateWidget(_TourPage old) {
    super.didUpdateWidget(old);
    // Play once, the first time this slide becomes the active one. Never reset:
    // a slide being left keeps its finished value and slides off cleanly.
    if (widget.isActive && !_played) _play();
  }

  void _play() {
    _played = true;
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Fade + slight slide-up over the [begin]–[end] slice of the entrance, so
  /// the hero, icon, title and subtitle cascade in when the slide arrives.
  Widget _appear(double begin, double end, Widget child) {
    final t = Curves.easeOut.transform(
      ((_entrance.value - begin) / (end - begin)).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slide = widget.slide;
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: ReadendarTokens.sp7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _appear(0, 0.9, slide.heroBuilder(_entrance.value)),
            const SizedBox(height: ReadendarTokens.sp8),
            _appear(
              0.15,
              0.6,
              Container(
                padding: const EdgeInsets.all(ReadendarTokens.sp4),
                decoration: BoxDecoration(
                  color: slide.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(slide.icon, color: slide.accent, size: 26),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp5),
            _appear(
              0.25,
              0.7,
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  color: context.colors.fg1,
                ),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp3),
            _appear(
              0.35,
              0.8,
              Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: context.colors.fg2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
