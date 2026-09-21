import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/profile/widgets/behavior_preference_card.dart';

/// Local toggles that change app automation / reading behavior.
///
/// Reached from Settings so the main Settings list stays compact; this screen
/// uses a roomier title + description layout than SettingsGroup rows.
class AppBehaviorSettingsScreen extends ConsumerWidget {
  const AppBehaviorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAppBehaviorTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              l.settingsAppBehaviorIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.fg2,
              ),
            ),
            const SizedBox(height: 20),
            const _AutoStatusEventsToggle(),
          ],
        ),
      ),
    );
  }
}

class _AutoStatusEventsToggle extends ConsumerStatefulWidget {
  const _AutoStatusEventsToggle();

  @override
  ConsumerState<_AutoStatusEventsToggle> createState() =>
      _AutoStatusEventsToggleState();
}

class _AutoStatusEventsToggleState
    extends ConsumerState<_AutoStatusEventsToggle> {
  bool _saving = false;

  Future<void> _set(bool enabled) async {
    if (_saving) return;
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    final previous = user.autoCreateStatusEvents;
    final next = user.copyWith(autoCreateStatusEvents: enabled);
    ref.read(sessionProvider.notifier).setUser(next);
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).persistLocalUser(next);
      if (!mounted) return;
      setState(() => _saving = false);
      showRdToast(
        context,
        tone: RdToastTone.success,
        message: AppL10n.of(context).profileSaved,
      );
    } on Object catch (e) {
      if (!mounted) return;
      ref
          .read(sessionProvider.notifier)
          .setUser(user.copyWith(autoCreateStatusEvents: previous));
      setState(() => _saving = false);
      showRdFailureToast(context, UnknownFailure(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final value = ref.watch(
      sessionProvider.select((s) => s.user?.autoCreateStatusEvents ?? false),
    );
    return BehaviorPreferenceCard(
      switchKey: const Key('autoStatusEventsSwitch'),
      icon: LucideIcons.calendarPlus,
      title: l.settingsAutoStatusEventsTitle,
      bullets: [
        l.settingsAutoStatusEventsBulletStart,
        l.settingsAutoStatusEventsBulletFinish,
      ],
      value: value,
      onChanged: _saving ? null : _set,
    );
  }
}
