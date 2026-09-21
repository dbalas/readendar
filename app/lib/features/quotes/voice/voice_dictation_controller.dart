import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Preferred platform speech locale per app locale. The device list uses
/// underscores on Android and hyphens on iOS, so matching normalizes both.
const _localePreference = {
  'es': 'es-ES',
  'ca': 'ca-ES',
  'en': 'en-US',
  'fr': 'fr-FR',
  'de': 'de-DE',
  'it': 'it-IT',
  'pl': 'pl-PL',
  'tr': 'tr-TR',
  'sv': 'sv-SE',
  'da': 'da-DK',
  'nb': 'nb-NO',
  'fi': 'fi-FI',
};

@visibleForTesting
const voiceDictationInitTimeout = Duration(seconds: 5);

String _norm(String localeId) => localeId.toLowerCase().replaceAll('_', '-');

@visibleForTesting
final voiceDictationListenOptions = SpeechListenOptions(
  onDevice: true,
  listenMode: ListenMode.dictation,
);

typedef OnDeviceSpeechAvailability = Future<bool> Function(String? localeId);

const _speechChannel = MethodChannel('readendar/speech');

Future<bool> _platformOnDeviceSpeechAvailable(String? localeId) async {
  try {
    return await _speechChannel.invokeMethod<bool>(
          'isOnDeviceRecognitionAvailable',
          {'localeId': localeId},
        ) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// Streaming voice dictation for the quote composer, on top of the OS speech
/// recognizer (speech_to_text). Partial results land in [partial] for a live
/// inline preview; final segments are handed to the composer via `onFinal`.
///
/// Catalan is missing from many Android recognizers: when the app locale has
/// no match, dictation falls back to the device default and [localeFallback]
/// flips so the composer can show a one-line notice.
class VoiceDictationController extends ChangeNotifier {
  VoiceDictationController({
    @visibleForTesting SpeechToText? speech,
    @visibleForTesting OnDeviceSpeechAvailability? onDeviceAvailable,
    @visibleForTesting this.initTimeout = voiceDictationInitTimeout,
  }) : _speech = speech ?? SpeechToText(),
       _onDeviceAvailable =
           onDeviceAvailable ?? _platformOnDeviceSpeechAvailable;

  final SpeechToText _speech;
  final OnDeviceSpeechAvailability _onDeviceAvailable;
  final Duration initTimeout;
  bool _initialized = false;
  bool _available = false;
  String? _localeId;

  bool localeFallback = false;
  String partial = '';

  /// True only when on-device STT is missing; timeout/permission stay retryable.
  bool unavailable = false;

  bool get listening => _speech.isListening;

  /// Lazily initializes the recognizer (triggers the mic/speech permission
  /// prompts) and resolves the best locale. Returns availability.
  Future<bool> init(String appLocale) async {
    if (unavailable) return false;
    if (_initialized) return _available;
    try {
      _available = await _speech
          .initialize(
            onStatus: (_) => notifyListeners(),
            onError: (_) => notifyListeners(),
          )
          .timeout(initTimeout, onTimeout: () => false);
    } on TimeoutException {
      _available = false;
    } on Exception {
      _available = false;
    }
    if (!_available) {
      // Timeout / permission prompt still open / user denied for now — keep
      // retryable. Permanent [unavailable] is reserved for no on-device STT.
      _initialized = false;
      notifyListeners();
      return false;
    }
    _initialized = true;

    final wanted = _localePreference[appLocale] ?? appLocale;
    // Base language, normalized (hyphens, no region): `l.localeName` arrives in
    // underscore form (`es_419`, `en_US`), so lower-casing alone would leave the
    // separator mismatched against the hyphenated device ids and the
    // same-language fallback below would never match (e.g. es-419 → 'es_419'
    // never equals 'es-mx' nor startsWith('es_419-')).
    final lang = _norm(appLocale).split('-').first;
    final locales = await _speech.locales();
    final ids = locales.map((e) => e.localeId).toList();
    _localeId = ids.firstWhere(
      (id) => _norm(id) == _norm(wanted),
      orElse: () => ids.firstWhere(
        // Same language with any region ('es-MX') OR a region-less id ('es') —
        // some recognizers list bare language codes, which the previous
        // 'startsWith("$lang-")' check missed, triggering a spurious fallback.
        (id) => _norm(id) == lang || _norm(id).startsWith('$lang-'),
        orElse: () => '',
      ),
    );
    if (_localeId!.isEmpty) {
      _localeId = null; // device default
      localeFallback = true;
    }
    // speech_to_text treats `onDevice` as a preference and falls back to the
    // default recognizer on unsupported Android devices. The platform check is
    // therefore a hard gate: never start listening unless the OS confirms a
    // genuine on-device recognizer for the selected locale.
    final onDevice = await _onDeviceAvailable(_localeId);
    if (!onDevice) {
      _available = false;
      _resetAfterFailedInit();
      return false;
    }
    return _available = true;
  }

  void _resetAfterFailedInit() {
    _initialized = false;
    unavailable = true;
    notifyListeners();
  }

  Future<void> start({required void Function(String text) onFinal}) async {
    partial = '';
    await _speech.listen(
      listenOptions: voiceDictationListenOptions.copyWith(localeId: _localeId),
      onResult: (r) {
        if (r.finalResult) {
          partial = '';
          if (r.recognizedWords.trim().isNotEmpty) {
            onFinal(r.recognizedWords.trim());
          }
        } else {
          partial = r.recognizedWords;
        }
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> stop() async {
    await _speech.stop();
    partial = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}
