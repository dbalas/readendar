import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

const readingChapterArchetypes = [
  'keeper',
  'curator',
  'hearth',
  'spark',
  'cartographer',
  'constellation',
  'comet',
  'vault',
  'scholar',
  'oak',
  'forge',
  'beacon',
  'atlas',
  'nebula',
  'leviathan',
];

/// Distinct Lucide glyph per reader archetype; [LucideIcons.orbit] is fallback only.
/// Legacy published `lantern` maps to beacon.
IconData readingChapterArchetypeIcon(String name) => switch (name) {
  'keeper' => LucideIcons.shield,
  'curator' => LucideIcons.layoutGrid,
  'hearth' => LucideIcons.flame,
  'spark' => LucideIcons.zap,
  'cartographer' => LucideIcons.mapPinned,
  'constellation' => LucideIcons.sparkles,
  'comet' => LucideIcons.rocket,
  'vault' => LucideIcons.vault,
  'scholar' => LucideIcons.graduationCap,
  'oak' => LucideIcons.treeDeciduous,
  'forge' => LucideIcons.anvil,
  'beacon' || 'lantern' => LucideIcons.landmark,
  'atlas' => LucideIcons.globe2,
  'nebula' => LucideIcons.cloud,
  'leviathan' => LucideIcons.waves,
  _ => LucideIcons.orbit,
};
