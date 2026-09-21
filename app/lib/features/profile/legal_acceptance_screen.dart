import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/di/providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocks an already-onboarded account until it accepts the current service
/// contract and confirms the current privacy policy has been reviewed.
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  bool _accepted = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.fileCheck2, size: 48, color: c.fg1),
                  const SizedBox(height: 20),
                  Text(
                    l.termsUpdateTitle,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: c.fg1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.termsUpdateDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: c.fg2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      RdButton.plain(
                        onPressed: _saving
                            ? null
                            : () => _open(
                                termsOfUseUrl(user.preferredLocale),
                              ),
                        label: l.legalTerms,
                        compact: true,
                      ),
                      RdButton.plain(
                        onPressed: _saving
                            ? null
                            : () => _open(
                                privacyPolicyUrl(user.preferredLocale),
                              ),
                        label: l.profilePrivacy,
                        compact: true,
                      ),
                    ],
                  ),
                  RdCheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _accepted,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _accepted = value ?? false),
                    title: Text(
                      l.onboardingConsentLabel,
                      style: TextStyle(color: c.fg2, fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: c.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  RdButton.primary(
                    expand: true,
                    loading: _saving,
                    onPressed: !_accepted || _saving ? null : _accept,
                    label: l.termsUpdateAccept,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    final now = DateTime.now().toUtc();
    await ref
        .read(sessionProvider.notifier)
        .persistLocalUser(
          user.copyWith(
            termsAcceptedAt: now,
            termsVersion: currentTermsVersion,
          ),
        );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _open(Uri uri) async {
    final l = AppL10n.of(context);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (mounted) setState(() => _error = l.errorGeneric);
  }
}
