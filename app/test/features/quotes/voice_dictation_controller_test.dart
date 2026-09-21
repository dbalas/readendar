
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/features/quotes/voice/voice_dictation_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _MockSpeechToText extends Mock implements SpeechToText {}

void _stubSpeechLifecycle(_MockSpeechToText speech) {
  when(() => speech.cancel()).thenAnswer((_) async {});
  when(() => speech.stop()).thenAnswer((_) async {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice dictation requires on-device recognition', () {
    expect(voiceDictationListenOptions.onDevice, isTrue);
    expect(voiceDictationListenOptions.partialResults, isTrue);
    expect(voiceDictationListenOptions.listenMode, ListenMode.dictation);
  });

  test('init times out and stays retryable', () async {
    final speech = _MockSpeechToText();
    _stubSpeechLifecycle(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) => Future.delayed(const Duration(seconds: 10), () => true));
    when(() => speech.isListening).thenReturn(false);

    final controller = VoiceDictationController(
      speech: speech,
      initTimeout: const Duration(milliseconds: 50),
      onDeviceAvailable: (_) async => true,
    );

    final available = await controller.init('en');
    expect(available, isFalse);
    expect(controller.unavailable, isFalse);

    clearInteractions(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => false);
    expect(await controller.init('en'), isFalse);
    verify(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).called(1);
    controller.dispose();
  });

  test('permission deny resets initialized so init can retry', () async {
    final speech = _MockSpeechToText();
    _stubSpeechLifecycle(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => false);
    when(() => speech.isListening).thenReturn(false);

    final controller = VoiceDictationController(
      speech: speech,
      onDeviceAvailable: (_) async => true,
    );

    expect(await controller.init('en'), isFalse);
    expect(controller.unavailable, isFalse);

    clearInteractions(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => false);
    expect(await controller.init('en'), isFalse);
    verify(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).called(1);
    controller.dispose();
  });

  test('on-device gate blocks cloud-only recognizers', () async {
    final speech = _MockSpeechToText();
    _stubSpeechLifecycle(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => true);
    when(speech.locales).thenAnswer(
      (_) async => [LocaleName('en_US', 'English')],
    );
    when(() => speech.isListening).thenReturn(false);

    final controller = VoiceDictationController(
      speech: speech,
      onDeviceAvailable: (_) async => false,
    );

    expect(await controller.init('en'), isFalse);
    expect(controller.unavailable, isTrue);
    controller.dispose();
  });
}
