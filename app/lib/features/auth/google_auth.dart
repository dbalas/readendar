// Thin wrapper around google_sign_in v7 (Credential Manager on Android).
// v7 exposes a singleton that must be initialize()d exactly once per process;
// both the login screen and the identity-linking screen route through here so
// neither has to track that lifecycle (or duplicate the cancel handling).

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The backend verifies the Google ID token's audience against its own client
/// id, so the app must request a token minted for that same (web) client id.
/// Overridable at build time via --dart-define=GOOGLE_SERVER_CLIENT_ID=…; the
/// default is the production web client so Google sign-in is always active.
const kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '724407297440-ntu5jglbivracdthm7fdpbgptrhq6lbv.apps.googleusercontent.com',
);

/// iOS OAuth client id (must match `GIDClientID` in ios/Runner/Info.plist).
/// Required on iOS when passing `serverClientId` through Dart: the native plugin
/// builds a `GIDConfiguration` only when a client id is present, otherwise it
/// drops the whole config — including `serverClientId` — and the idToken is
/// minted for the iOS client alone (backend then rejects audience).
const kGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue:
      '724407297440-vtub67r9dkr4ksv6l5lkj0coi79qe84e.apps.googleusercontent.com',
);

abstract final class GoogleAuth {
  static bool _initialized = false;

  /// Widget tests inject a delayed/cancelled flow so OAuth loading stays
  /// isolated from the email Continue button.
  @visibleForTesting
  static Future<GoogleSignInAccount?> Function()? authenticateForTest;

  /// Runs the interactive Google authentication flow and returns the signed-in
  /// account, or null when the user cancels the account chooser. Any other
  /// [GoogleSignInException] propagates to the caller's error handling.
  static Future<GoogleSignInAccount?> authenticate() async {
    if (authenticateForTest != null) return authenticateForTest!();
    final gsi = GoogleSignIn.instance;
    if (!_initialized) {
      await gsi.initialize(
        // iOS native plugin requires clientId to apply serverClientId; Android
        // identifies the app via package name + SHA and must not receive the
        // iOS client id.
        clientId: _iosClientIdOrNull,
        serverClientId: kGoogleServerClientId,
      );
      _initialized = true;
    }
    // Drop any cached Google session so the account chooser always shows — on
    // a shared/multi-account device the user must be able to pick which Google
    // account signs in, not be silently logged in as the last one.
    await gsi.signOut();
    try {
      return await gsi.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  static String? get _iosClientIdOrNull {
    if (kIsWeb) return null;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? kGoogleIosClientId
        : null;
  }
}
