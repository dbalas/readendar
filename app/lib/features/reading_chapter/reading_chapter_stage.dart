import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

/// Feature-owned composition for a Reading Chapter story.
///
/// Controls stay in the shared design system. This owns only the editorial
/// canvas and the story-specific progress affordance.
///
/// The canvas must keep a stable identity across card changes. A key that
/// includes the current page remounts [PageView] mid-swipe and drops the
/// ballistic snap onto the wrong card.
class ReadingChapterStage extends StatelessWidget {
  const ReadingChapterStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.bg,
              Color.alphaBlend(colors.accentSoftBg, colors.bg),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class ReadingChapterStoryPager extends StatelessWidget {
  const ReadingChapterStoryPager({
    required this.controller,
    required this.current,
    required this.count,
    required this.onPageChanged,
    required this.itemBuilder,
    super.key,
    this.pageViewKey,
    this.aboveCards,
  });

  final PageController controller;
  final int current;
  final int count;
  final ValueChanged<int> onPageChanged;
  final IndexedWidgetBuilder itemBuilder;
  final Key? pageViewKey;
  final Widget? aboveCards;

  @override
  Widget build(BuildContext context) {
    final page = count == 0 ? 0 : current.clamp(0, count - 1);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: ReadingChapterStoryProgress(
                  current: page,
                  total: count,
                  onSelect: (target) {
                    if (!controller.hasClients || target == page) return;
                    controller.animateToPage(
                      target,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${page + 1}/$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.colors.fg2,
                ),
              ),
            ],
          ),
        ),
        ?aboveCards,
        Expanded(
          child: PageView.builder(
            key: pageViewKey,
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: count,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  if (!controller.hasClients ||
                      MediaQuery.disableAnimationsOf(context)) {
                    return child!;
                  }
                  final page = controller.page ?? current.toDouble();
                  final opacity = (1 - (index - page).abs()).clamp(0.0, 1.0);
                  return Opacity(opacity: opacity, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: itemBuilder(context, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReadingChapterStoryProgress extends StatelessWidget {
  const ReadingChapterStoryProgress({
    required this.current,
    required this.total,
    required this.onSelect,
    super.key,
  });

  final int current;
  final int total;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var index = 0; index < total; index++)
          Expanded(
            child: Semantics(
              button: true,
              selected: index == current,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(index),
                child: Padding(
                  padding: EdgeInsets.only(right: index == total - 1 ? 0 : 4),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    height: index == current ? 6 : 4,
                    decoration: BoxDecoration(
                      color: index <= current ? colors.accent : colors.line,
                      borderRadius: BorderRadius.circular(
                        ReadendarTokens.radiusPill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
