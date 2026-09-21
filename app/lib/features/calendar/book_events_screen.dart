// Thin scaffold kept for tests / rare deep entry. Production book detail uses
// [BookEventsListBody] inside the Eventos tab.

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/book_events_list_body.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';

class BookEventsScreen extends ConsumerWidget {
  const BookEventsScreen({required this.bookId, super.key});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final book = ref.watch(bookViewProvider(bookId)).value;
    final canAdd = book != null;

    return Scaffold(
      floatingActionButton: canAdd
          ? RdCreateAction.fab(
              context: context,
              tooltip: l.actionAddEvent,
              icon: LucideIcons.calendarPlus,
              onPressed: () => _addEvent(context),
            )
          : null,
      appBar: AppBar(
        title: Text(l.sectionEvents),
        actions: [
          if (canAdd)
            ...RdCreateAction.appBarActions(
              context: context,
              tooltip: l.actionAddEvent,
              icon: LucideIcons.calendarPlus,
              onPressed: () => _addEvent(context),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: BookEventsListBody(bookId: bookId),
      ),
    );
  }

  void _addEvent(BuildContext context) => Navigator.of(context).push(
    rdPageRoute<void>(
      context,
      builder: (_) => EventFormScreen(defaultBookId: bookId),
    ),
  );
}
