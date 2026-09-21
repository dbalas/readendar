// Thin wrapper around sign_in_with_apple. Login and Auth Methods route through
// here so cancel handling and name assembly stay in one place.
//
// iOS-only product surface (App Store requirement when Google is offered). The
// native flow needs no client id in Dart — the bundle id is the audience the
// backend verifies via APPLE_OAUTH_CLIENT_ID.
//
// Email/name arrive on the Apple credential only for the first authorization.
// Subsequent identity tokens often still carry an `email` JWT claim — we read
// that as a fallback for client-side link guards (backend trusts only the
// verified JWT). If both are empty and the server has no Apple identity yet
// (`apple_missing_email`), the user must revoke Readendar under Settings →
// Apple ID → Sign in with Apple and try again.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Whether Sign in with Apple should be offered in the UI.
///
/// True only on iOS (not web/Android). Availability still depends on the device
/// supporting the API (`SignInWithApple.isAvailable`).
bool get kAppleSignInSupportedPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}

/// Result of an interactive Apple sign-in. [email] may be null on returning
/// authorizations (Apple only returns it on first consent).
class AppleAuthCredential {
  const AppleAuthCredential({
    required this.identityToken,
    this.email,
    this.fullName,
  });

  final String identityToken;
  final String? email;
  final String? fullName;
}

abstract final class AppleAuth {
  /// Widget tests inject a delayed/cancelled flow without calling the native
  /// Sign in with Apple sheet.
  @visibleForTesting
  static Future<AppleAuthCredential?> Function()? authenticateForTest;

  /// Runs the interactive Apple authentication flow.
  ///
  /// Returns null when the user cancels. Other authorization errors propagate.
  static Future<AppleAuthCredential?> authenticate() async {
    if (authenticateForTest != null) return authenticateForTest!();
    if (!kAppleSignInSupportedPlatform) {
      throw UnsupportedError('Sign in with Apple is only available on iOS');
    }
    if (!await SignInWithApple.isAvailable()) {
      throw StateError('Sign in with Apple is not available on this device');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw StateError('Apple identity token missing');
      }
      final email =
          _nonEmpty(credential.email) ?? emailFromIdentityToken(token);
      return AppleAuthCredential(
        identityToken: token,
        email: email,
        fullName: _fullName(credential.givenName, credential.familyName),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /// Unverified JWT payload peek — used only for client-side UX (link email
  /// mismatch). Auth decisions stay on the backend JWKS verification.
  @visibleForTesting
  static String? emailFromIdentityToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      return _nonEmpty(payload['email'] as String?);
    } on Object {
      return null;
    }
  }

  static String? _fullName(String? given, String? family) {
    final parts = [
      if (_nonEmpty(given) != null) given!.trim(),
      if (_nonEmpty(family) != null) family!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
