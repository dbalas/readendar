// In-app feedback / bug report (profile → Help). Opens the mail composer to
// hello@readendar.com. Diagnostics (app version + platform + OS) are appended
// to the body.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:readendar/features/feedback/feedback_thanks_screen.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  String _kind = FeedbackKind.bug;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppL10n.of(context);
    final navigator = Navigator.of(context);
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = l.feedbackMessageRequired);
      return;
    }
    if (message.runes.length < 10) {
      setState(() => _error = l.feedbackMessageTooShort);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });

    final diag = await _diagnostics();
    final os = '${diag.platform} ${diag.osVersion}'.trim();
    final uri = feedbackMailtoUri(
      kind: _kind,
      message: message,
      version: diag.appVersion,
      os: os,
    );
    var opened = false;
    try {
      opened = await feedbackLaunchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      await navigator.pushReplacement(
        rdPageRoute<void>(
          context,
          builder: (_) => const FeedbackThanksScreen(),
        ),
      );
      return;
    }
    setState(() {
      _sending = false;
      _error = l.feedbackMailOpenFailed;
    });
  }

  Future<_Diagnostics> _diagnostics() async {
    var appVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Best-effort: a missing version must never block sending feedback.
    }
    return _Diagnostics(
      appVersion: appVersion,
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.feedbackTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.feedbackIntro, style: TextStyle(color: context.colors.fg2)),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: _sending,
              child: RdSegmentedControl<String>(
                selected: _kind,
                onChanged: (v) => setState(() => _kind = v),
                segments: [
                  RdSegment(
                    value: FeedbackKind.bug,
                    label: l.feedbackKindBug,
                    icon: LucideIcons.bug,
                  ),
                  RdSegment(
                    value: FeedbackKind.idea,
                    label: l.feedbackKindIdea,
                    icon: LucideIcons.lightbulb,
                  ),
                  RdSegment(
                    value: FeedbackKind.other,
                    label: l.feedbackKindOther,
                    icon: LucideIcons.messageCircle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RdTextField(
              controller: _message,
              minLines: 7,
              maxLines: 14,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: RdFormFieldLabel.decoration(
                context,
                labelText: l.feedbackMessageLabel,
                required: true,
                decoration: InputDecoration(
                  hintText: l.feedbackMessageHint,
                  alignLabelWithHint: true,
                ),
              ),
              onChanged: (value) {
                if (_error == null) return;
                final message = value.trim();
                setState(() {
                  _error = message.isEmpty
                      ? l.feedbackMessageRequired
                      : message.runes.length < 10
                      ? l.feedbackMessageTooShort
                      : null;
                });
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: context.colors.danger)),
            ],
            const SizedBox(height: 8),
            RdCard(
              backgroundColor: context.colors.surface2,
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 18, color: context.colors.fg2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.feedbackDiagnosticsNote,
                      style: TextStyle(color: context.colors.fg2, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RdButton.primary(
              icon: LucideIcons.send,
              label: l.feedbackSubmit,
              loading: _sending,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Diagnostics {
  const _Diagnostics({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
  });
  final String appVersion;
  final String platform;
  final String osVersion;
}
