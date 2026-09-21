import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/email.dart';
import 'package:readendar/core/widgets/apple_sign_in_button.dart';
import 'package:readendar/core/widgets/brand_wordmark.dart';
import 'package:readendar/core/widgets/google_sign_in_button.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_prompt.dart';
import 'package:readendar/features/auth/apple_auth.dart';
import 'package:readendar/features/auth/google_auth.dart';
import 'package:readendar/features/auth/magic_link_deep_link.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _resendCooldown = Duration(seconds: 5);

  static TextStyle _codeTextStyle(ReadendarColors c) => TextStyle(
    color: c.fg1,
    fontFamily: ReadendarTokens.fontMono,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
  );

  static TextStyle _codeHintStyle(ReadendarColors c) => TextStyle(
    color: c.fgFaint,
    fontFamily: ReadendarTokens.fontMono,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
  );

  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _emailLoading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;

  bool get _anyLoading => _emailLoading || _googleLoading || _appleLoading;
  bool _codeStep = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  // When the server rate-limits a magic-link request it returns Retry-After;
  // we count it down so the user sees a live "try again in N" and the request
  // buttons stay disabled until the window clears (no point hammering it).
  int _rateLimitedSecondsRemaining = 0;
  Timer? _rateLimitTimer;
  String? _devCode;
  String? _devLink;
  String? _error;
  String? _sentTo;

  @override
  void initState() {
    super.initState();
    // A magic-link tap that failed during boot (expired/invalid token) lands
    // the user back here with no visible cause — surface it inline. Warm-start
    // failures are caught by the listener in build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showMagicLinkFailure(ref.read(magicLinkFailureProvider));
      if (mounted) {
        unawaited(
          maybeShowAppUpdatePrompt(
            context,
            ref,
            stillVisible: () {
              if (!mounted) return false;
              final insets =
                  MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0;
              return appUpdateLoginSurfaceIdle(
                codeStep: _codeStep,
                loading: _anyLoading,
                hasEmailText: _email.text.trim().isNotEmpty,
                hasCodeText: _code.text.trim().isNotEmpty,
                keyboardOpen: insets > 0,
              );
            },
          ),
        );
      }
    });
  }

  void _showMagicLinkFailure(Failure? f) {
    if (f == null) return;
    ref.read(magicLinkFailureProvider.notifier).state = null;
    final l = AppL10n.of(context);
    setState(
      () => _error = f is NetworkFailure
          ? localizedFailureMessage(l, f)
          : l.magicLinkInvalid,
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _rateLimitTimer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_anyLoading ||
        _rateLimitedSecondsRemaining > 0 ||
        (_codeStep && _resendSecondsRemaining > 0)) {
      return;
    }
    final l = AppL10n.of(context);
    final email = _email.text.trim();
    // Distinguish empty vs bad format before hitting the API — both used to
    // collapse into the generic "check the entered data" validation message.
    if (email.isEmpty) {
      setState(() => _error = l.errFieldRequired);
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => _error = l.errInvalidEmail);
      return;
    }
    final isResend = _codeStep;
    setState(() {
      _emailLoading = true;
      _error = null;
      _devCode = null;
      _devLink = null;
      if (!isResend) _sentTo = null;
    });
    if (isResend) _startResendCooldown();
    final locale = localeToTag(ref.read(localeProvider) ?? const Locale('es'));
    final r = await ref
        .read(authRepoProvider)
        .requestMagicLink(email: email, locale: locale);
    if (!mounted) return;
    r.fold(
      (out) {
        setState(() {
          _emailLoading = false;
          _codeStep = true;
          _devCode = out.devCode;
          _devLink = out.devLink;
          _sentTo = email;
          _code.text = out.devCode ?? '';
        });
        if (!isResend) _startResendCooldown();
      },
      (f) {
        if (f is RateLimitedFailure && (f.retryAfterSeconds ?? 0) > 0) {
          _startRateLimitCountdown(f.retryAfterSeconds!);
          return;
        }
        setState(() {
          _emailLoading = false;
          _error = localizedFailureMessage(AppL10n.of(context), f);
        });
      },
    );
  }

  Future<void> _verifyCode([String? rawCode]) async {
    final token = (rawCode ?? _code.text).trim();
    if (token.isEmpty) {
      setState(() => _error = AppL10n.of(context).authCodeRequired);
      return;
    }
    setState(() {
      _emailLoading = true;
      _error = null;
    });
    final locale = localeToTag(ref.read(localeProvider) ?? const Locale('es'));
    final r = await ref
        .read(authRepoProvider)
        .verifyMagicLink(token: token, locale: locale);
    if (!mounted) return;
    r.fold(
      (_) => _completeAuthenticated(),
      (f) {
        setState(() {
          _emailLoading = false;
          _error = localizedFailureMessage(AppL10n.of(context), f);
        });
      },
    );
  }

  Future<void> _signInGoogle() async {
    if (_anyLoading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      // GoogleAuth (google_sign_in v7 / Credential Manager) always shows the
      // account chooser and returns null on cancel; the server client id lives
      // in google_auth.dart.
      final account = await GoogleAuth.authenticate();
      if (account == null) {
        if (mounted) setState(() => _googleLoading = false); // user cancelled
        return;
      }
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _googleLoading = false;
            _error = AppL10n.of(context).errorGeneric;
          });
        }
        return;
      }
      final locale = localeToTag(
        ref.read(localeProvider) ?? const Locale('es'),
      );
      final r = await ref
          .read(authRepoProvider)
          .signInGoogle(idToken: idToken, locale: locale);
      if (!mounted) return;
      r.fold(
        (_) => _completeAuthenticated(),
        (f) => setState(() {
          _googleLoading = false;
          _error = localizedFailureMessage(AppL10n.of(context), f);
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error = localizedErrorMessage(AppL10n.of(context), e);
        });
      }
    }
  }

  Future<void> _signInApple() async {
    if (_anyLoading) return;
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    try {
      final credential = await AppleAuth.authenticate();
      if (credential == null) {
        if (mounted) setState(() => _appleLoading = false); // user cancelled
        return;
      }
      final locale = localeToTag(
        ref.read(localeProvider) ?? const Locale('es'),
      );
      final r = await ref
          .read(authRepoProvider)
          .signInApple(
            idToken: credential.identityToken,
            locale: locale,
            name: credential.fullName,
          );
      if (!mounted) return;
      r.fold(
        (_) => _completeAuthenticated(),
        (f) => setState(() {
          _appleLoading = false;
          _error = localizedFailureMessage(AppL10n.of(context), f);
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _appleLoading = false;
          _error = localizedErrorMessage(AppL10n.of(context), e);
        });
      }
    }
  }

  void _completeAuthenticated() {
    if (!mounted) return;
    Navigator.of(context).maybePop(true);
  }

  void _editEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeStep = false;
      _resendSecondsRemaining = 0;
      _code.clear();
      _error = null;
      _devCode = null;
      _devLink = null;
      _sentTo = null;
    });
  }

  void _startRateLimitCountdown(int seconds) {
    // The rate-limit window supersedes the short resend cooldown: cancel it so
    // only one countdown drives the disabled buttons.
    _resendTimer?.cancel();
    _rateLimitTimer?.cancel();
    setState(() {
      _emailLoading = false;
      _error = null;
      _resendSecondsRemaining = 0;
      _rateLimitedSecondsRemaining = seconds;
    });
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_rateLimitedSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _rateLimitedSecondsRemaining = 0);
        return;
      }
      setState(() => _rateLimitedSecondsRemaining -= 1);
    });
  }

  // Compact mm:ss / Ns label for the disabled submit button while waiting out a
  // rate limit. The full sentence lives in the error area.
  static String _formatCountdown(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    return '$minutes:${rem.toString().padLeft(2, '0')}';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendCooldown.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
        return;
      }
      setState(() => _resendSecondsRemaining -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    ref.listen<Failure?>(
      magicLinkFailureProvider,
      (_, next) => _showMagicLinkFailure(next),
    );
    ref.listen<int>(magicLinkSignedInTickProvider, (previous, next) {
      if (previous == next) return;
      _completeAuthenticated();
    });
    // The rate-limit countdown owns the error line while it runs so the
    // remaining time updates every tick.
    final errorText = _rateLimitedSecondsRemaining > 0
        ? localizedRateLimitedMessage(l, _rateLimitedSecondsRemaining)
        : _error;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthLogo(label: l.appName),
                      const SizedBox(height: 36),
                      Text(
                        _codeStep ? l.authCodeTitle : l.authSignInTitle,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: c.fg1,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _codeStep
                            ? l.authCodeSubtitle(_sentTo ?? _email.text.trim())
                            : l.authSignInSubtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: c.fg2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _codeStep
                            ? _buildCodeView(l)
                            : _buildEmailView(l),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          errorText,
                          style: TextStyle(
                            color: c.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        l.authPasswordlessNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.fg2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GoogleSignInButton(
                        onPressed: _anyLoading ? null : _signInGoogle,
                        loading: _googleLoading,
                        label: l.authSignInWithGoogle,
                      ),
                      if (kAppleSignInSupportedPlatform) ...[
                        const SizedBox(height: 12),
                        AppleSignInButton(
                          onPressed: _anyLoading ? null : _signInApple,
                          loading: _appleLoading,
                          label: l.authSignInWithApple,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                key: const Key('loginClose'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: _anyLoading
                    ? null
                    : () => Navigator.of(context).maybePop(false),
                icon: const Icon(LucideIcons.x),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailView(AppL10n l) {
    return Column(
      key: const ValueKey('email-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdTextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: RdFormFieldLabel.decoration(
            context,
            labelText: l.authEmail,
            required: true,
            decoration: InputDecoration(
              hintText: l.authEmailHint,
              prefixIcon: const Icon(LucideIcons.mail),
            ),
          ),
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_anyLoading) _sendCode();
          },
        ),
        const SizedBox(height: 18),
        RdButton.primary(
          expand: true,
          loading: _emailLoading,
          onPressed: (_anyLoading || _rateLimitedSecondsRemaining > 0)
              ? null
              : _sendCode,
          icon: _rateLimitedSecondsRemaining > 0
              ? LucideIcons.clock
              : LucideIcons.arrowRight,
          label: _rateLimitedSecondsRemaining > 0
              ? l.authWaitCountdown(
                  _formatCountdown(_rateLimitedSecondsRemaining),
                )
              : l.authSubmitSignIn,
        ),
      ],
    );
  }

  Widget _buildCodeView(AppL10n l) {
    final c = context.colors;
    return Column(
      key: const ValueKey('code-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdAuthNotice(
          icon: LucideIcons.mailCheck,
          title: l.authMagicLinkSent(_sentTo ?? _email.text.trim()),
          body: l.authMagicLinkInstructions,
        ),
        const SizedBox(height: 18),
        RdTextField(
          controller: _code,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: _codeTextStyle(c),
          decoration: RdFormFieldLabel.decoration(
            context,
            labelText: l.authCode,
            required: true,
            decoration: InputDecoration(
              hintText: l.authCodeHint,
              hintStyle: _codeHintStyle(c),
              prefixIcon: const Icon(LucideIcons.keyRound),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(8),
            TextInputFormatter.withFunction(
              (oldValue, newValue) =>
                  newValue.copyWith(text: newValue.text.toUpperCase()),
            ),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_anyLoading) _verifyCode();
          },
        ),
        const SizedBox(height: 18),
        RdButton.primary(
          expand: true,
          loading: _emailLoading,
          onPressed: _anyLoading ? null : _verifyCode,
          icon: LucideIcons.check,
          label: l.authVerifyCode,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: RdButton.plain(
                onPressed: _anyLoading ? null : _editEmail,
                label: l.authChangeEmail,
              ),
            ),
            Expanded(
              child: RdButton.plain(
                onPressed:
                    _anyLoading ||
                        _resendSecondsRemaining > 0 ||
                        _rateLimitedSecondsRemaining > 0
                    ? null
                    : _sendCode,
                label: _rateLimitedSecondsRemaining > 0
                    ? l.authWaitCountdown(
                        _formatCountdown(_rateLimitedSecondsRemaining),
                      )
                    : _resendSecondsRemaining > 0
                    ? l.authResendCodeCountdown(_resendSecondsRemaining)
                    : l.authResendCode,
              ),
            ),
          ],
        ),
        if (_devCode != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.warningSoftBg,
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.authDevCodeTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.warningSoftFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _devCode!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: ReadendarTokens.fontMono,
                  ),
                ),
                if (_devLink != null) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    _devLink!,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.fg2,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                RdButton.primary(
                  expand: true,
                  onPressed: () => _verifyCode(_devCode),
                  label: l.authDevCodeAction,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/icons/app-icon.svg',
          width: 58,
          height: 58,
          semanticsLabel: label,
        ),
        const SizedBox(width: 14),
        BrandWordmark(
          label: label,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class RdAuthNotice extends StatelessWidget {
  const RdAuthNotice({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.successSoftBg,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.successSoftFg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: c.fg2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
