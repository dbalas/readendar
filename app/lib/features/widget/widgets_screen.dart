// The "Widgets" hub reached from Profile. Lists every home-screen widget the
// user can configure — upcoming events, quick progress, and quotes — each with
// a live preview and its own "add to home screen" button.
//
// Everything here reuses existing components: [WidgetAddButton] owns the
// (platform-smart) per-widget install orchestration, [WidgetPreview] renders
// the events widget, and [QuotesWidgetPreview] renders the quotes widget — no
// duplication.

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/features/widget/progress_widget_preview.dart';
import 'package:readendar/features/widget/quotes_widget_config_screen.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart';
import 'package:readendar/features/widget/widget_add_button.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_preview.dart';
import 'package:readendar/features/widget/widget_preview_card.dart';

class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: EditorialTitle(
          l.widgetsTitle,
          key: const Key('widgetsEditorialTitle'),
          maxLines: 1,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l.widgetsIntro,
              style: TextStyle(color: context.colors.fg2, height: 1.4),
            ),
            const SizedBox(height: 24),
            _WidgetSection(
              title: l.actionUpdateProgress,
              child: const WidgetAddButton(
                kind: WidgetKind.progress,
                child: ProgressWidgetPreview(),
              ),
            ),
            const SizedBox(height: 24),
            _WidgetSection(
              title: l.widgetEventsTitle,
              // Events add directly — nothing to configure.
              child: const WidgetAddButton(
                kind: WidgetKind.events,
                child: WidgetPreview(),
              ),
            ),
            const SizedBox(height: 24),
            _WidgetSection(
              title: l.quotesCardTitle,
              // Quotes route through the config screen (pick quotes + rotation
              // first), so the preview taps open it instead of adding directly.
              child: Builder(
                builder: (context) => WidgetPreviewCard(
                  tooltip: l.quotesWidgetConfigTitle,
                  onTap: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const QuotesWidgetConfigScreen(),
                    ),
                  ),
                  child: const QuotesWidgetPreview(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetSection extends StatelessWidget {
  const _WidgetSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title,
          key: const Key('widgetsSectionTitle'),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
