import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/timezone_picker_sheet.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _name = TextEditingController();
  String _timezone = 'Europe/Madrid';
  bool _saving = false;
  String? _error;
  String? _nameError;
  bool _initialized = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final l = AppL10n.of(context);
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    _initFromUser(user);

    return Scaffold(
      appBar: widget.onboarding
          ? null
          : AppBar(
              title: Text(l.profileEditTitle),
              actions: [
                FormSaveAction(
                  saving: _saving,
                  onPressed: _save,
                  tooltip: l.actionSave,
                  label: l.actionSave,
                ),
              ],
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Gate screens (tour / legal / onboarding profile)
                  // share one content width so the stack doesn't jump.
                  maxWidth: widget.onboarding ? 440 : 520,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onboarding) ...[
                      _Header(
                        title: l.onboardingTitle,
                        subtitle: l.onboardingSubtitle,
                      ),
                      const SizedBox(height: 28),
                    ],
                    RdTextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: RdFormFieldLabel.decoration(
                        context,
                        labelText: l.profileDisplayName,
                        required: true,
                        decoration: InputDecoration(
                          errorText: _nameError,
                        ),
                      ),
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    RdFormSelectField(
                      label: l.profileTimezone,
                      required: true,
                      leading: const Icon(LucideIcons.clock3),
                      valueText: _timezone,
                      onTap: _saving ? null : _showTimezoneSheet,
                      enabled: !_saving,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: context.colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (widget.onboarding) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RdCheckbox(
                            value: _termsAccepted,
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                    () => _termsAccepted = v ?? false,
                                  ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                l.onboardingConsentLabel,
                                style: TextStyle(
                                  color: context.colors.fg2,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            RdButton.plain(
                              onPressed: _openPrivacy,
                              label: l.profilePrivacy,
                              compact: true,
                            ),
                            RdButton.plain(
                              onPressed: _openTerms,
                              label: l.legalTerms,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RdButton.primary(
                        expand: true,
                        loading: _saving,
                        onPressed: (_saving || !_termsAccepted) ? null : _save,
                        icon: LucideIcons.save,
                        label: l.onboardingSave,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initFromUser(AppUser user) {
    if (_initialized) return;
    _name.text = user.displayName;
    _timezone = _normalizeTimezone(user.timezone);
    _initialized = true;
  }

  String _normalizeTimezone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'UTC') return 'Europe/Madrid';
    return trimmed;
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final currentUser = ref.read(sessionProvider).user;
    final oldTimezone = currentUser?.timezone;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = l.errFieldRequired;
        _error = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    if (currentUser == null) {
      setState(() => _saving = false);
      return;
    }
    final now = DateTime.now().toUtc();
    final completeOnboarding = widget.onboarding;
    final updated = currentUser.copyWith(
      displayName: name,
      timezone: _timezone,
      onboardingCompletedAt: completeOnboarding
          ? now
          : currentUser.onboardingCompletedAt,
      termsAcceptedAt: widget.onboarding
          ? (currentUser.termsAcceptedAt ?? now)
          : currentUser.termsAcceptedAt,
      termsVersion: widget.onboarding
          ? currentTermsVersion
          : currentUser.termsVersion,
    );
    try {
      await ref.read(sessionProvider.notifier).persistLocalUser(updated);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.errorGeneric;
      });
      return;
    }
    if (!mounted) return;
    if (!widget.onboarding && updated.timezone != oldTimezone) {
      try {
        await resyncLocalNotifications(ref, l, updated);
      } catch (_) {}
    }
    if (!mounted) return;
    if (widget.onboarding) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _openPrivacy() => _openLegal(privacyPolicyUrl);

  Future<void> _openTerms() => _openLegal(termsOfUseUrl);

  Future<void> _openLegal(Uri Function(String) builder) async {
    final localeCode = ref.read(localeProvider)?.languageCode ?? 'es';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        builder(localeCode),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('launch returned false');
    } catch (_) {
      if (mounted) {
        showRdToast(
          context,
          messenger: messenger,
          tone: RdToastTone.error,
          message: AppL10n.of(context).errorGeneric,
        );
      }
    }
  }

  Future<void> _showTimezoneSheet() async {
    final picked = await showRdModalSheet<String>(
      context: context,
      builder: (_) => TimezonePickerSheet(selected: _timezone),
    );
    if (picked != null) {
      setState(() => _timezone = picked);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: context.colors.fg1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.colors.fg2),
          ),
        ],
      ],
    );
  }
}
