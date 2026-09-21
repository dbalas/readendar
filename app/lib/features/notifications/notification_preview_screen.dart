import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';

/// Dev-only screen (reached from the debug screen) that fires a sample
/// notification for each [EventType] straight to the system tray, so the
/// real content ([notificationContentFor]: title = the action with any
/// milestone number, body = book) can be reviewed without waiting for a
/// reminder to come due.
class NotificationPreviewScreen extends ConsumerWidget {
  const NotificationPreviewScreen({super.key});

  static const _sampleBook = 'Pedro Páramo';

  // Fixed high id range reserved for ephemeral debug previews. Production
  // event/quote ids use their own deterministic namespaces.
  static const _baseId = 990000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.debugNotifPreviewTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugNotifPreviewIntro,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  RdButton.primary(
                    onPressed: () => _fireAll(context, l),
                    icon: LucideIcons.bellRing,
                    label: l.debugNotifPreviewFireAll,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final type in EventType.values)
                    _PreviewRow(
                      type: type,
                      content: _sampleContent(type, l),
                      onTap: () => _fire(context, l, type),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A representative event for each type, run through the real content helper
  /// so the preview matches exactly what a scheduled reminder will render.
  NotificationContent _sampleContent(EventType type, AppL10n l) {
    final event = ReadingEvent(
      id: 'preview-${type.index}',
      ownerType: OwnerType.user,
      ownerId: 'preview',
      type: type.backendValue,
      title: type.label(l),
      dateLocal: DateTime.utc(2026),
      status: EventStatus.active,
      bookId: 'preview-book',
      targetChapter: type == EventType.chapterMilestone ? 5 : null,
      targetPage: switch (type) {
        EventType.pageMilestone => 135,
        EventType.deadline => 200,
        _ => null,
      },
    );
    return notificationContentFor(
      event,
      bookTitle: _sampleBook,
      l: l,
    );
  }

  Future<void> _fire(BuildContext context, AppL10n l, EventType type) async {
    final content = _sampleContent(type, l);
    await LocalNotifications.I.showSample(
      id: _baseId + type.index,
      title: content.title,
      body: content.body,
      channelName: l.notificationChannelName,
      channelDescription: l.notificationChannelDescription,
    );
    if (!context.mounted) return;
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.debugNotifPreviewSent,
    );
  }

  Future<void> _fireAll(BuildContext context, AppL10n l) async {
    for (final type in EventType.values) {
      final content = _sampleContent(type, l);
      await LocalNotifications.I.showSample(
        id: _baseId + type.index,
        title: content.title,
        body: content.body,
        channelName: l.notificationChannelName,
        channelDescription: l.notificationChannelDescription,
      );
    }
    if (!context.mounted) return;
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.debugNotifPreviewSent,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.type,
    required this.content,
    required this.onTap,
  });

  final EventType type;
  final NotificationContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = content.body;
    return ListTile(
      leading: EventIcon(type: type, size: 20),
      title: Text(content.title),
      subtitle: body == null
          ? null
          : Text(
              body,
              style: TextStyle(color: context.colors.fg2),
            ),
      trailing: const Icon(LucideIcons.send, size: 18),
      onTap: onTap,
    );
  }
}
