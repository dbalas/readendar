import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/offline/offline_config.dart';

void main() {
  test('product data plane is always local', () {
    expect(
      resolveDataPlane(raw: 'api', userId: localGuestUserId),
      DataPlane.local,
    );
    expect(
      resolveDataPlane(raw: 'local', userId: 'server-user'),
      DataPlane.local,
    );
    expect(resolveDataPlane(raw: null, userId: null), DataPlane.local);
    expect(
      resolveDataPlane(raw: null, userId: localGuestUserId),
      DataPlane.local,
    );
    expect(
      resolveDataPlane(raw: null, userId: 'server-user'),
      DataPlane.local,
    );
    expect(
      resolveDataPlane(
        raw: 'api',
        userId: 'server-user',
        windowOpen: true,
      ),
      DataPlane.local,
    );
  });

  test('API base defaults to the hosted export host', () {
    expect(
      resolveApiBaseUrl(fromEnv: '', releaseMode: false),
      defaultApiBaseUrl,
    );
    expect(
      resolveApiBaseUrl(fromEnv: '', releaseMode: true),
      defaultApiBaseUrl,
    );
    expect(
      resolveApiBaseUrl(
        fromEnv: 'https://api.example.test',
        releaseMode: true,
      ),
      'https://api.example.test',
    );
  });

  test('release builds reject a plaintext API override', () {
    expect(
      () => resolveApiBaseUrl(
        fromEnv: 'http://localhost:8080',
        releaseMode: true,
      ),
      throwsStateError,
    );
    expect(
      resolveApiBaseUrl(
        fromEnv: 'http://localhost:8080',
        releaseMode: false,
      ),
      'http://localhost:8080',
    );
  });
}
