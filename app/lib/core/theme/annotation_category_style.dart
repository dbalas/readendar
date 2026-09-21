import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

/// Colors and icons for annotation categories. Hues are exclusive to this
/// system (not reused as accent/success/warning/danger).
abstract final class AnnotationCategoryStyle {
  static Color hue(AnnotationCategory category) => switch (category) {
    AnnotationCategory.note => ReadendarTokens.annNote,
    AnnotationCategory.quote => ReadendarTokens.annQuote,
    AnnotationCategory.theory => ReadendarTokens.annTheory,
    AnnotationCategory.question => ReadendarTokens.annQuestion,
  };

  static Color softBg(AnnotationCategory category) =>
      hue(category).withValues(alpha: 0.16);

  static Color foreground(AnnotationCategory category, Brightness brightness) =>
      brightness == Brightness.dark
      ? Color.lerp(hue(category), Colors.white, 0.28)!
      : Color.lerp(hue(category), Colors.black, 0.22)!;

  static IconData icon(AnnotationCategory category) => switch (category) {
    AnnotationCategory.note => LucideIcons.stickyNote,
    AnnotationCategory.quote => LucideIcons.quote,
    AnnotationCategory.theory => LucideIcons.lightbulb,
    AnnotationCategory.question => LucideIcons.circleHelp,
  };

  static String label(AppL10n l, AnnotationCategory category) =>
      switch (category) {
        AnnotationCategory.note => l.annotationCategoryNote,
        AnnotationCategory.quote => l.annotationCategoryQuote,
        AnnotationCategory.theory => l.annotationCategoryTheory,
        AnnotationCategory.question => l.annotationCategoryQuestion,
      };

  static String addLabel(AppL10n l, AnnotationCategory category) =>
      switch (category) {
        AnnotationCategory.note => l.annotationAddNote,
        AnnotationCategory.quote => l.annotationAddQuote,
        AnnotationCategory.theory => l.annotationAddTheory,
        AnnotationCategory.question => l.annotationAddQuestion,
      };

  static String shareTitle(AppL10n l, AnnotationCategory category) =>
      switch (category) {
        AnnotationCategory.note => l.quoteShareTitleNote,
        AnnotationCategory.quote => l.quoteShareTitle,
        AnnotationCategory.theory => l.quoteShareTitleTheory,
        AnnotationCategory.question => l.quoteShareTitleQuestion,
      };
}

/// Create-menu for note / quote / theory / question. Same labels and hues
/// everywhere (book FAB, annotations FAB, empty-state CTAs).
Future<AnnotationCategory?> pickAnnotationCategoryToCreate(
  BuildContext context,
) {
  final l = AppL10n.of(context);
  return showRdModalSheet<AnnotationCategory>(
    context: context,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.annotationAdd,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final cat in AnnotationCategory.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  AnnotationCategoryStyle.icon(cat),
                  color: AnnotationCategoryStyle.hue(cat),
                ),
                title: Text(AnnotationCategoryStyle.addLabel(l, cat)),
                onTap: () => Navigator.pop(ctx, cat),
              ),
          ],
        ),
      );
    },
  );
}

/// Filter chip (icon + label) matching other filter sheets. Keeps category
/// icon hue; never a checkbox. Used in category pickers and filter sheets.
class AnnotationCategoryChip extends StatelessWidget {
  const AnnotationCategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
    this.label,
    super.key,
  });

  final AnnotationCategory category;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final hue = AnnotationCategoryStyle.hue(category);
    return FilterChip(
      avatar: Icon(
        AnnotationCategoryStyle.icon(category),
        size: 16,
        color: hue,
      ),
      showCheckmark: false,
      label: Text(label ?? AnnotationCategoryStyle.label(l, category)),
      selected: selected,
      selectedColor: AnnotationCategoryStyle.softBg(category),
      side: BorderSide(
        color: selected ? hue : context.colors.line,
      ),
      onSelected: onSelected,
    );
  }
}
