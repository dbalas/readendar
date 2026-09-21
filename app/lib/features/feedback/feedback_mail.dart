import 'package:flutter/material.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:url_launcher/url_launcher.dart';

const feedbackSupportEmail = 'hello@readendar.com';

typedef FeedbackUrlLauncher = Future<bool> Function(Uri uri);

FeedbackUrlLauncher feedbackLaunchUrl = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Uri feedbackMailtoUri({
  required String kind,
  required String message,
  required String version,
  required String os,
}) {
  final subject = 'Readendar ($kind)';
  final body = StringBuffer(message.trim())
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln('version: $version')
    ..writeln('os: $os');
  return Uri(
    scheme: 'mailto',
    path: feedbackSupportEmail,
    query: _encodeMailtoQuery({
      'subject': subject,
      'body': body.toString(),
    }),
  );
}

/// Opens the device mail app to hello@readendar.com. Returns whether launch
/// succeeded.
Future<bool> openFeedbackMailto([BuildContext? context]) async {
  final uri = Uri(
    scheme: 'mailto',
    path: feedbackSupportEmail,
    query: _encodeMailtoQuery({'subject': 'Readendar'}),
  );
  var opened = false;
  try {
    opened = await feedbackLaunchUrl(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context != null && context.mounted) {
    showRdToast(
      context,
      message: AppL10n.of(context).feedbackMailOpenFailed,
      tone: RdToastTone.error,
    );
  }
  return opened;
}

String _encodeMailtoQuery(Map<String, String> params) => params.entries
    .map(
      (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
    )
    .join('&');
