import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/image_pick.dart' show pickImagePath;
import 'package:readendar/features/quotes/ocr/ocr_compose.dart';
import 'package:text_sight/text_sight.dart';

/// A photographed page with its recognized lines (image-pixel coords).
class OcrPage {
  const OcrPage({
    required this.imagePath,
    required this.width,
    required this.height,
    required this.lines,
  });
  final String imagePath;
  final double width;
  final double height;
  final List<OcrLine> lines;
}

/// Latin-script preferences for Apple Vision (ML Kit Latin ignores this).
/// App locale goes first at the call site.
const _ocrLanguageHints = <Locale>[
  Locale('es'),
  Locale('ca'),
  Locale('en'),
  Locale('fr'),
  Locale('de'),
  Locale('it'),
  Locale('pt'),
  Locale('nl'),
  Locale('pl'),
  Locale('tr'),
  Locale('sv'),
  Locale('da'),
  Locale('nb'),
  Locale('fi'),
];

@visibleForTesting
List<Locale> preferredOcrLanguages(Locale appLocale) {
  final seen = <String>{};
  final out = <Locale>[];
  for (final locale in [appLocale, ..._ocrLanguageHints]) {
    final code = locale.languageCode.toLowerCase();
    if (seen.add(code)) out.add(Locale(code));
  }
  return out;
}

/// Serializes native Vision / ML Kit. Overlapping still-image calls can
/// crash the engine.
Future<void> _ocrChain = Future<void>.value();

Future<T> _withOcrLock<T>(Future<T> Function() run) {
  final previous = _ocrChain;
  final released = Completer<void>();
  _ocrChain = released.future;
  return previous.then((_) => run()).whenComplete(() {
    if (!released.isCompleted) released.complete();
  });
}

/// On-device OCR for an already-staged image path (Apple Vision on iOS,
/// ML Kit on Android). Empty [OcrPage.lines] means no recognizable text.
Future<OcrPage> recognizeOcrPageFromPath(
  String path, {
  required Locale appLocale,
}) {
  return _withOcrLock(
    () => _recognizeOcrPageFromPath(path, appLocale: appLocale),
  );
}

Future<OcrPage> _recognizeOcrPageFromPath(
  String path, {
  required Locale appLocale,
}) async {
  // Instant on iOS / bundled Android; needed if the model is ever unbundled.
  await TextSightModel.ensureReady().timeout(const Duration(seconds: 20));

  final options = TextSightOptions(
    level: RecognitionLevel.accurate,
    languages: preferredOcrLanguages(appLocale),
  );

  final capture = await TextSight.recognizePath(
    path,
    options: options,
  ).timeout(const Duration(seconds: 30));

  // imageSize is display-upright (post-EXIF), matching Image.file + boxes.
  final width = capture.imageSize.width;
  final height = capture.imageSize.height;
  final lines = buildOcrLines(
    lines: [
      for (final line in capture.lines) (line.text, line.boundingBox),
    ],
    width: width,
    height: height,
  );

  return OcrPage(
    imagePath: path,
    width: width,
    height: height,
    lines: lines,
  );
}

/// Photo (camera/gallery via the shared picker sheet) → on-device OCR
/// (Apple Vision on iOS, ML Kit on Android; Latin script covers our locales)
/// → [OcrPage]. Returns null when the user cancels the picker. An empty
/// [OcrPage.lines] means the photo had no recognizable text — the caller
/// shows the "no text" notice.
Future<OcrPage?> captureOcrPage(BuildContext context) async {
  final path = await pickImagePath(context);
  if (path == null) return null;
  return recognizeOcrPageFromPath(
    path,
    appLocale: Localizations.localeOf(context),
  );
}
