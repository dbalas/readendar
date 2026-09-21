import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';

typedef RequestCapturePermission = Future<PermissionStatus> Function();
typedef OpenDeviceSettings = Future<bool> Function();

bool quoteVoicePermissionAllowed(PermissionStatus status) =>
    status.isGranted || status.isLimited || status.isProvisional;

/// Explains that microphone (and speech recognition) access is required
/// and offers a path to Settings after the OS permission was denied.
Future<void> showQuoteVoicePermissionDeniedDialog(
  BuildContext context, {
  OpenDeviceSettings? openSettings,
}) async {
  final l = AppL10n.of(context);
  final open = await showConfirmDialog(
    context: context,
    icon: LucideIcons.micOff,
    title: l.quoteVoicePermissionTitle,
    message: l.quoteVoicePermissionBody,
    confirmLabel: l.scanPermissionOpenSettings,
    confirmIcon: LucideIcons.settings,
  );
  if (open) {
    await (openSettings ?? openAppSettings)();
  }
}

/// Requests microphone access, plus speech recognition on iOS, before
/// dictation. Returns false after showing the settings modal when denied.
Future<bool> ensureQuoteVoiceAccess(
  BuildContext context, {
  RequestCapturePermission? requestMicrophone,
  RequestCapturePermission? requestSpeech,
  OpenDeviceSettings? openSettings,
}) async {
  try {
    final microphone =
        await (requestMicrophone ?? () => Permission.microphone.request())();
    if (!quoteVoicePermissionAllowed(microphone)) {
      if (context.mounted) {
        await showQuoteVoicePermissionDeniedDialog(
          context,
          openSettings: openSettings,
        );
      }
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final speech =
          await (requestSpeech ?? () => Permission.speech.request())();
      if (!quoteVoicePermissionAllowed(speech)) {
        if (context.mounted) {
          await showQuoteVoicePermissionDeniedDialog(
            context,
            openSettings: openSettings,
          );
        }
        return false;
      }
    }
    return true;
  } on MissingPluginException {
    // Widget tests and hosts without permission_handler.
    return true;
  }
}
