import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('persisted theme is the effective theme', () async {
    SharedPreferences.setMockInitialValues({'theme_preset': 'ethereal'});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionProvider.overrideWith(_TestSession.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(readendarThemeProvider), ReadendarThemeId.ethereal);
    expect(
      container.read(effectiveReadendarThemeProvider),
      ReadendarThemeId.ethereal,
    );
  });

  test('signed-out bootstrap pushes the selected theme to widgets', () async {
    SharedPreferences.setMockInitialValues({'theme_preset': 'ethereal'});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(_SignedOutStorage()),
        sessionProvider.overrideWith(SessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(_lastAppTheme(calls), ReadendarThemeId.ethereal.wire);
    expect(container.read(readendarThemeProvider), ReadendarThemeId.ethereal);
  });
}

class _TestSession extends SessionNotifier {
  _TestSession(super.ref);
}

String? _lastAppTheme(List<MethodCall> calls) {
  final writes = calls.where(
    (call) =>
        call.method == 'saveWidgetData' &&
        (call.arguments as Map)['id'] == kWidgetKeyAppTheme,
  );
  return writes.isEmpty
      ? null
      : (writes.last.arguments as Map)['data'] as String?;
}

class _SignedOutStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
