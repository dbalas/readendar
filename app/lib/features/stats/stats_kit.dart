// Shared visual kit for the personal statistics dashboard. Design-system
// primitives for UserStatsScreen: a tone palette, the responsive
// metric grid + tiles, the filled panels (chart / bar / info / note), the
// section header + navigable section rows, and two generic fl_chart wrappers
// (line + bar). Screen-specific glue (which sections exist, their bodies) lives
// in the screen.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

// ─── Tone palette ────────────────────────────────────────────────
// Semantic accents derived from theme + brand tokens, adaptive to dark mode.

enum StatTone { neutral, primary, good, bad, warn }

({Color bg, Color fg}) statToneColors(BuildContext context, StatTone tone) {
  final cs = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (tone) {
    case StatTone.neutral:
      return (bg: cs.surfaceContainerHigh, fg: cs.onSurface);
    case StatTone.primary:
      return (bg: cs.primary.withValues(alpha: 0.10), fg: cs.primary);
    case StatTone.good:
      return (
        bg: ReadendarTokens.sage500.withValues(alpha: 0.12),
        fg: dark ? ReadendarTokens.sage300 : ReadendarTokens.sage600,
      );
    case StatTone.bad:
      return (
        bg: ReadendarTokens.wine500.withValues(alpha: 0.12),
        fg: dark ? ReadendarTokens.wine300 : ReadendarTokens.wine600,
      );
    case StatTone.warn:
      return (
        bg: ReadendarTokens.amber500.withValues(alpha: 0.14),
        fg: dark ? ReadendarTokens.amber300 : ReadendarTokens.amber700,
      );
  }
}

// ─── Section scaffold ────────────────────────────────────────────

class StatSection extends StatelessWidget {
  const StatSection({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  // Chip (28) + gap (sp4) = where the title text starts; the subtitle is
  // indented by the same amount so it lines up under the title.
  static const double _titleInset = 28 + ReadendarTokens.sp4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ReadendarTokens.sp8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon),
              const SizedBox(width: ReadendarTokens.sp4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: _titleInset, top: 4),
              child: Text(subtitle!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: ReadendarTokens.sp4),
          child,
        ],
      ),
    );
  }
}

// ─── Metric tiles (responsive, width-filling grid) ───────────────

class StatTile {
  const StatTile(
    this.label,
    this.value, {
    this.unit,
    this.tone = StatTone.neutral,
  });
  final String label;
  final String value;

  /// Short qualifier rendered inline after the value (e.g. "días", "altas"),
  /// on the same baseline but smaller and muted.
  final String? unit;
  final StatTone tone;
}

/// Lays the tiles into equal-width columns that fill the row, choosing the
/// column count from the available width. Every tile in a row shares the
/// tallest tile's height (CrossAxisAlignment.stretch) so the grid stays even.
class MetricGrid extends StatelessWidget {
  const MetricGrid(this.tiles, {super.key, this.maxColumns = 4});
  final List<StatTile> tiles;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    const gap = ReadendarTokens.sp3;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / 116).floor().clamp(2, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          final last = i + cols >= tiles.length;
          final cells = <Widget>[];
          for (var j = 0; j < cols; j++) {
            if (j > 0) cells.add(const SizedBox(width: gap));
            final idx = i + j;
            cells.add(
              Expanded(
                child: idx < tiles.length
                    ? _MetricTile(tiles[idx])
                    : const SizedBox.shrink(),
              ),
            );
          }
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : gap),
              // IntrinsicHeight bounds the row's cross-axis so the tiles can
              // stretch to a shared height (the tallest tile in the row).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cells,
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.data);
  final StatTile data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = statToneColors(context, data.tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: data.value,
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
                if (data.unit != null)
                  TextSpan(
                    text: ' ${data.unit}',
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(data.label, maxLines: 2, style: tt.bodySmall),
        ],
      ),
    );
  }
}

// ─── Panels (filled, width-filling content blocks) ───────────────

/// Bare filled surface used by the chart / bar / info / note panels so every
/// non-tile block shares one background, radius and padding.
class StatPanel extends StatelessWidget {
  const StatPanel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: child,
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

class NotePanel extends StatelessWidget {
  const NotePanel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => StatPanel(
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class ChartPanel extends StatelessWidget {
  const ChartPanel({
    required this.label,
    required this.child,
    this.height,
    super.key,
  });
  final String label;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StatPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(label),
          const SizedBox(height: ReadendarTokens.sp4),
          if (height case final value?)
            SizedBox(height: value, child: child)
          else
            child,
        ],
      ),
    );
  }
}

class BarData {
  const BarData({
    required this.label,
    required this.fraction,
    required this.trailing,
    this.tone = StatTone.primary,
  });
  final String label;
  final double fraction;
  final String trailing;
  final StatTone tone;
}

class BarPanel extends StatelessWidget {
  const BarPanel({
    required this.label,
    required this.rows,
    super.key,
    this.barColor,
  });
  final String label;
  final List<BarData> rows;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final color = barColor ?? Theme.of(context).colorScheme.primary;
    return StatPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(label),
          const SizedBox(height: ReadendarTokens.sp3),
          for (final r in rows)
            _BarRow(
              data: r,
              color: barColor == null
                  ? statToneColors(context, r.tone).fg
                  : color,
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.data, required this.color});
  final BarData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Label + value on their own line above the full-width bar, so even long
    // category names (genres) are never truncated.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  data.label,
                  style: tt.bodySmall?.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(width: ReadendarTokens.sp3),
              Text(
                data.trailing,
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
            child: LinearProgressIndicator(
              value: data.fraction.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label + emphasized value on a tinted strip (e.g. current book, most
/// abandoned, total pages). The leading icon + tint signal the tone.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.tone = StatTone.neutral,
  });
  final IconData icon;
  final String label;
  final String value;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = statToneColors(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.fg),
          const SizedBox(width: ReadendarTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.labelSmall),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DistributionData {
  const DistributionData({required this.label, required this.value});
  final String label;
  final int value;
}

/// Compact stacked distribution plus exact-value legend. Useful when the total
/// matters less than the composition (library status and reading formats).
class DistributionPanel extends StatelessWidget {
  const DistributionPanel({
    required this.label,
    required this.items,
    super.key,
    this.colors,
  });
  final String label;
  final List<DistributionData> items;
  final List<Color>? colors;

  static const _tones = <Color>[
    ReadendarTokens.teal400,
    ReadendarTokens.sage500,
    ReadendarTokens.amber500,
    ReadendarTokens.wine500,
    ReadendarTokens.paper500,
  ];

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (var i = 0; i < items.length; i++)
        if (items[i].value > 0) (item: items[i], colorIndex: i),
    ];
    final cs = Theme.of(context).colorScheme;
    Color colorAt(int index) {
      final palette = colors;
      return palette != null && palette.isNotEmpty
          ? palette[index % palette.length]
          : _tones[index % _tones.length];
    }

    return StatPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(label),
          const SizedBox(height: ReadendarTokens.sp4),
          if (visible.isEmpty)
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
              ),
            )
          else
            ClipRRect(
              key: const Key('distribution-panel-bar'),
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      Expanded(
                        flex: visible[i].item.value,
                        child: SizedBox.expand(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorAt(visible[i].colorIndex),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: ReadendarTokens.sp4),
          Wrap(
            spacing: ReadendarTokens.sp4,
            runSpacing: ReadendarTokens.sp2,
            children: [
              for (var i = 0; i < visible.length; i++)
                _DistributionLegend(
                  color: colorAt(visible[i].colorIndex),
                  label: visible[i].item.label,
                  value: '${visible[i].item.value}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutDistributionPanel extends StatelessWidget {
  const DonutDistributionPanel({
    required this.label,
    required this.items,
    super.key,
  });
  final String label;
  final List<DistributionData> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) => item.value > 0).toList();
    final total = visible.fold<int>(0, (sum, item) => sum + item.value);
    return StatPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(label),
          const SizedBox(height: ReadendarTokens.sp4),
          if (visible.isEmpty)
            const SizedBox.shrink()
          else
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 34,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < visible.length; i++)
                          PieChartSectionData(
                            value: visible[i].value.toDouble(),
                            color: DistributionPanel
                                ._tones[i % DistributionPanel._tones.length],
                            showTitle: false,
                            radius: 18,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: ReadendarTokens.sp5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _DistributionLegend(
                            color: DistributionPanel
                                ._tones[i % DistributionPanel._tones.length],
                            label: visible[i].label,
                            value:
                                '${visible[i].value} · ${(visible[i].value * 100 / total).round()}%',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  const _DistributionLegend({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    runSpacing: 2,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class ReadingHeatmapDay {
  const ReadingHeatmapDay({
    required this.date,
    required this.value,
    required this.label,
  });

  final DateTime date;
  final int value;
  final String label;
}

/// Locale-aware calendar grid. Empty reading days remain visible, and every
/// cell exposes its date and value to tooltips and accessibility services.
class ReadingHeatmap extends StatelessWidget {
  const ReadingHeatmap({required this.days, super.key});
  final List<ReadingHeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (days.isEmpty) return const SizedBox.shrink();
    final max = maxOf(days.map((day) => day.value));
    final material = MaterialLocalizations.of(context);
    final firstWeekday = material.firstDayOfWeekIndex;
    final firstDateWeekday = days.first.date.weekday % 7;
    final leadingCells = (firstDateWeekday - firstWeekday + 7) % 7;
    final labels = <String>[
      for (var i = 0; i < 7; i++)
        material.narrowWeekdays[(firstWeekday + i) % 7],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        // Derive each cell from the available width. Seven cells plus six
        // gaps fill the panel exactly, so every day remains a real square.
        final cellSize = (constraints.maxWidth - gap * 6) / 7;
        final cells = <ReadingHeatmapDay?>[
          ...List<ReadingHeatmapDay?>.filled(leadingCells, null),
          ...days,
        ];
        final rowCount = (cells.length / 7).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Column(
              children: [
                for (var row = 0; row < rowCount; row++) ...[
                  if (row > 0) const SizedBox(height: gap),
                  Row(
                    children: [
                      for (var column = 0; column < 7; column++) ...[
                        if (column > 0) const SizedBox(width: gap),
                        Expanded(
                          child: switch (row * 7 + column) {
                            final index when index >= cells.length => SizedBox(
                              height: cellSize,
                            ),
                            final index when cells[index] == null => SizedBox(
                              height: cellSize,
                            ),
                            final index => Semantics(
                              label: cells[index]!.label,
                              child: Tooltip(
                                message: cells[index]!.label,
                                child: Container(
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: cells[index]!.value == 0
                                        ? cs.surfaceContainerHighest
                                        : cs.primary.withValues(
                                            alpha:
                                                0.22 +
                                                (cells[index]!.value / max) *
                                                    0.78,
                                          ),
                                    border: Border.all(
                                      color: cells[index]!.value == 0
                                          ? cs.outlineVariant
                                          : Colors.transparent,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Navigation row + list container ─────────────────────────────

class StatPreview {
  const StatPreview(this.text, this.tone);
  final String text;
  final StatTone tone;
}

class SectionList extends StatelessWidget {
  const SectionList({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SectionRow extends StatelessWidget {
  const SectionRow({
    required this.icon,
    required this.title,
    required this.preview,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final StatPreview? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            IconChip(icon),
            const SizedBox(width: ReadendarTokens.sp4),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(left: ReadendarTokens.sp3),
                child: Text(
                  preview!.text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statToneColors(context, preview!.tone).fg,
                  ),
                ),
              ),
            const SizedBox(width: ReadendarTokens.sp2),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: context.colors.fg3,
            ),
          ],
        ),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  const IconChip(this.icon, {super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Icon(icon, size: 16, color: cs.primary),
    );
  }
}

class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
}

// ─── Section detail subview ──────────────────────────────────────

/// The scaffold a section row pushes to: an AppBar carrying the section title
/// plus the section body in a scroll view. Both dashboards share it.
class StatSectionDetailScreen extends StatelessWidget {
  const StatSectionDetailScreen({
    required this.title,
    required this.child,
    super.key,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [child],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────

/// Bucket labels for a 0–100% progress histogram, shared by both dashboards.
const statBucketLabels = ['0-20', '20-40', '40-60', '60-80', '80-100'];

/// Largest value, floored at 1 so it's safe as a bar-chart denominator even when
/// the list is empty or all-zero.
int maxOf(Iterable<int> values) {
  var max = 1;
  for (final v in values) {
    if (v > max) max = v;
  }
  return max;
}

double _axisInterval(double maxValue) {
  if (maxValue <= 4) return 1;
  final rough = maxValue / 4;
  if (rough <= 5) return 5;
  if (rough <= 10) return 10;
  if (rough <= 25) return 25;
  if (rough <= 50) return 50;
  if (rough <= 100) return 100;
  return (rough / 100).ceil() * 100;
}

/// A 0–1 rate as a rounded whole-percent string (e.g. 0.66 → "66%").
String statPct(double v) => '${(v * 100).round()}%';

/// Semantic tone for a 0–1 rate: green when healthy, amber when middling, red
/// when poor. Pass [higherIsBetter] = false for rates where low is the good
/// outcome (churn, abandon).
StatTone statRateTone(double v, {bool higherIsBetter = true}) {
  final score = higherIsBetter ? v : 1 - v;
  if (score >= 0.6) return StatTone.good;
  if (score >= 0.3) return StatTone.warn;
  return StatTone.bad;
}

/// Sign-based tone: positive green, negative red, zero neutral.
StatTone statSignTone(num v) =>
    v > 0 ? StatTone.good : (v < 0 ? StatTone.bad : StatTone.neutral);

/// Light, readable tooltip text on the dark inverse-surface bubble — never the
/// series colour (primary on dark reads poorly).
TextStyle tooltipTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.labelMedium!.copyWith(
    color: theme.colorScheme.onInverseSurface,
    fontWeight: FontWeight.w600,
  );
}

// ─── Charts ──────────────────────────────────────────────────────

/// Dual normalized trend: real page deltas and finished-book counts share the
/// time axis while tooltips retain their exact units. Normalization avoids a
/// misleading second numeric axis on a phone-width card.
class BooksPagesTrendChart extends StatelessWidget {
  const BooksPagesTrendChart({
    required this.pages,
    required this.books,
    required this.labels,
    required this.pagesLabel,
    required this.booksLabel,
    super.key,
  });
  final List<int> pages;
  final List<int> books;
  final List<String> labels;
  final String pagesLabel;
  final String booksLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pageMax = maxOf(pages);
    final bookMax = maxOf(books);
    List<FlSpot> spots(List<int> values, int max) => [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i] / max),
    ];
    LineChartBarData line(List<FlSpot> points, Color color) => LineChartBarData(
      spots: points,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
    return Column(
      children: [
        Wrap(
          spacing: ReadendarTokens.sp4,
          children: [
            _DistributionLegend(
              color: cs.primary,
              label: pagesLabel,
              value: '',
            ),
            _DistributionLegend(
              color: ReadendarTokens.teal400,
              label: booksLabel,
              value: '',
            ),
          ],
        ),
        const SizedBox(height: ReadendarTokens.sp2),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1.05,
              minX: 0,
              maxX: labels.isEmpty ? 1 : (labels.length - 1).toDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: cs.outline, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= labels.length || i.isOdd) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                line(spots(pages, pageMax), cs.primary),
                line(spots(books, bookMax), ReadendarTokens.teal400),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItems: (touched) => [
                    for (final spot in touched)
                      LineTooltipItem(
                        spot.barIndex == 0
                            ? '$pagesLabel: ${pages[spot.x.toInt()]}'
                            : '$booksLabel: ${books[spot.x.toInt()]}',
                        tooltipTextStyle(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Curved area line over a series of values, with sparse bottom labels and a
/// rounded-value tooltip. Used for the personal finished-per-month trend.
class LineTrendChart extends StatelessWidget {
  const LineTrendChart({required this.values, required this.labels, super.key});
  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxY = values.fold<double>(1, (a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY + 1,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outline, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (values.length / 4).ceilToDouble().clamp(1, 12),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: cs.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem('${s.y.round()}', tooltipTextStyle(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical bars over a series of values. When [maxY] is given the bars sit on a
/// faint full-height track (e.g. percentages out of 100); when null the chart
/// auto-scales with no track (e.g. raw counts). [tooltip] formats the tapped
/// value (defaults to a rounded integer).
class BarTrendChart extends StatelessWidget {
  const BarTrendChart({
    required this.values,
    required this.labels,
    super.key,
    this.maxY,
    this.tooltip,
    this.tooltipForIndex,
    this.barWidth = 18,
    this.labelInterval = 1,
    this.mutedIndices = const <int>{},
    this.color,
    this.showYAxis = false,
  });
  final List<double> values;
  final List<String> labels;
  final double? maxY;
  final String Function(double)? tooltip;
  final String? Function(int, double)? tooltipForIndex;
  final double barWidth;
  final int labelInterval;
  final Set<int> mutedIndices;
  final Color? color;
  final bool showYAxis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seriesColor = color ?? cs.primary;
    final autoMax = values.fold<double>(1, (a, b) => a > b ? a : b);
    final top = maxY ?? autoMax;
    final fmt = tooltip ?? (double v) => '${v.round()}';
    final groups = [
      for (var i = 0; i < values.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: mutedIndices.contains(i)
                  ? seriesColor.withValues(alpha: 0.24)
                  : seriesColor,
              width: barWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: maxY != null,
                toY: top,
                color: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
    ];
    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            // Keep the bubble inside the chart viewport. Without these flags
            // fl_chart lets edge bars place it outside the canvas, where the
            // surrounding panel clips the date range and page count.
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItem: (group, gi, rod, ri) {
              final text = tooltipForIndex == null
                  ? fmt(rod.toY)
                  : tooltipForIndex!(group.x, rod.toY);
              if (text == null) return null;
              return BarTooltipItem(text, tooltipTextStyle(context));
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showYAxis,
              reservedSize: showYAxis ? 34 : 0,
              interval: _axisInterval(top),
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > top) return const SizedBox.shrink();
                return Text(
                  '${value.round()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                if (i % labelInterval != 0 && i != labels.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mutedIndices.contains(i)
                          ? cs.onSurfaceVariant.withValues(alpha: 0.42)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
      ),
    );
  }
}
