// Lightweight loading skeletons (no shimmer dependency): static rounded
// blocks in paper tones under a gentle opacity pulse. Used for the cold-start
// loading states so screens sketch their layout instead of showing a bare
// spinner. Background revalidations never show these — cached data stays on
// screen (see `_cacheWhileLoggedIn` in di/providers.dart).

import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';

/// Pulses its [child]'s opacity to signal "loading" without a heavy shader.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({required this.child, super.key});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}

/// A single placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.lineStrong,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder for a list of book rows (library, status lists).
class BookListSkeleton extends StatelessWidget {
  const BookListSkeleton({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: rows,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Cover placeholder matches BookCoverSize.sm (56×84).
            SkeletonBox(width: 56, height: 84, radius: 4),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180),
                  SizedBox(height: 8),
                  SkeletonBox(width: 110, height: 12),
                  SizedBox(height: 10),
                  SkeletonBox(width: 70, height: 18, radius: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Placeholder for the month calendar: weekday strip + a 6×7 grid of cells.
class CalendarSkeleton extends StatelessWidget {
  const CalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SkeletonBox(width: 140, height: 16),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.8,
              ),
              itemCount: 42,
              itemBuilder: (_, _) =>
                  const SkeletonBox(height: double.infinity, radius: 8),
            ),
          ),
        ],
      ),
    ),
  );
}
