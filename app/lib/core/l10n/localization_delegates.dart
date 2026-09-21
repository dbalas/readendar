import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;

import 'package:readendar/core/l10n/gen/app_localizations.dart';

/// App and editor localization delegates.
const List<LocalizationsDelegate<dynamic>> readendarLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      ...AppL10n.localizationsDelegates,
      FlutterQuillLocalizations.delegate,
    ];
