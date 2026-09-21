import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/nav_box.dart';
import 'package:readendar/features/import/import_intro_screen.dart';

class ImportSourcesScreen extends StatelessWidget {
  const ImportSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.importDataTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(ReadendarTokens.sp6),
          children: [
            Text(
              l.importChooseSource,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ReadendarTokens.sp5),
            NavBox(
              icon: LucideIcons.bookOpen,
              title: l.importGoodreadsSourceName,
              subtitle: l.importGoodreadsSourceSubtitle,
              tintBg: context.colors.warningSoftBg,
              tintFg: context.colors.warningSoftFg,
              onTap: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => const ImportIntroScreen(),
                ),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp3),
            NavBox(
              icon: LucideIcons.chartColumn,
              title: l.importStoryGraphSourceName,
              subtitle: l.importStoryGraphSourceSubtitle,
              tintBg: context.colors.surface2,
              tintFg: context.colors.fg1,
              onTap: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => const ImportIntroScreen.storygraph(),
                ),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp3),
            NavBox(
              icon: LucideIcons.notebookTabs,
              title: l.importBookmorySourceName,
              subtitle: l.importBookmorySourceSubtitle,
              tintBg: context.colors.accentSoftBg,
              tintFg: context.colors.accentSoftFg,
              onTap: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => const ImportIntroScreen.bookmory(),
                ),
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp3),
            NavBox(
              icon: LucideIcons.library,
              title: l.importBabelioSourceName,
              subtitle: l.importBabelioSourceSubtitle,
              tintBg: context.colors.highlightSoft,
              tintFg: context.colors.warningSoftFg,
              onTap: () => Navigator.of(context).push(
                rdPageRoute<void>(
                  context,
                  builder: (_) => const ImportIntroScreen.babelio(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
