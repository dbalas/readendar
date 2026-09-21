// 1:1 port of design/colors_and_type.css.
// Keep this file in sync with the design tokens.

import 'package:flutter/material.dart';

class ReadendarTokens {
  ReadendarTokens._();

  // ─── Periwinkle (primary) ──────────────────────────────────
  static const periwinkle50 = Color(0xFFF1F2FA);
  static const periwinkle100 = Color(0xFFE2E4F4);
  static const periwinkle200 = Color(0xFFC5C9EA);
  static const periwinkle300 = Color(0xFFA8ADDD);
  static const periwinkle400 = Color(0xFF8E94D3);
  static const periwinkle500 = Color(0xFF7479D6);
  static const periwinkle600 = Color(0xFF5A5FBC);
  static const periwinkle700 = Color(0xFF44489A);
  static const periwinkle800 = Color(0xFF2F3373);
  static const periwinkle900 = Color(0xFF1B1E48);

  // ─── Teal (secondary) ──────────────────────────────────────
  static const teal50 = Color(0xFFE8F5F1);
  static const teal100 = Color(0xFFC9E9E0);
  static const teal200 = Color(0xFF97D6C8);
  static const teal300 = Color(0xFF64BCAC);
  static const teal400 = Color(0xFF3FA694);
  static const teal500 = Color(0xFF2A8F7D);
  static const teal600 = Color(0xFF1F7666);
  static const teal700 = Color(0xFF18594E);
  static const teal800 = Color(0xFF103D35);
  static const teal900 = Color(0xFF082420);

  // ─── Sage (success) ────────────────────────────────────────
  static const sage50 = Color(0xFFEEF5EB);
  static const sage100 = Color(0xFFD6E6CF);
  static const sage200 = Color(0xFFADCDA0);
  static const sage300 = Color(0xFF82B373);
  static const sage400 = Color(0xFF6BA15D);
  static const sage500 = Color(0xFF5B924C);
  static const sage600 = Color(0xFF487539);
  static const sage700 = Color(0xFF36572B);
  static const sage800 = Color(0xFF243A1D);
  static const sage900 = Color(0xFF131F10);

  // ─── Amber (highlight / warning) ───────────────────────────
  static const amber50 = Color(0xFFFCF2DE);
  static const amber100 = Color(0xFFF7E2B5);
  static const amber200 = Color(0xFFF1CB83);
  static const amber300 = Color(0xFFEBB35A);
  static const amber400 = Color(0xFFE5A848);
  static const amber500 = Color(0xFFE0A03A);
  static const amber600 = Color(0xFFB97D26);
  static const amber700 = Color(0xFF8E5E18);
  static const amber800 = Color(0xFF644111);
  static const amber900 = Color(0xFF3F2809);

  /// The favorite-star gold, shared by the quotes widget's three renderers
  /// (Flutter preview + the raw `#DD9D2B` literals in the iOS/Android widgets).
  static const amberStar = Color(0xFFDD9D2B);

  /// Dark scrim laid over blurred cover artwork so paper-tone text stays
  /// legible — the quotes "cover" widget style + the share card's cover card.
  /// Brightness-independent on purpose (a fixed scrim over arbitrary imagery).
  static const coverScrim = Color(0xB3141326);

  // ─── Wine (destructive) ────────────────────────────────────
  static const wine50 = Color(0xFFFBE9EB);
  static const wine100 = Color(0xFFF4C8CD);
  static const wine200 = Color(0xFFE5969B);
  static const wine300 = Color(0xFFD26669);
  static const wine400 = Color(0xFFC04F54);
  static const wine500 = Color(0xFFB23F45);
  static const wine600 = Color(0xFF8F2F35);
  static const wine700 = Color(0xFF6B2125);
  static const wine800 = Color(0xFF471417);
  static const wine900 = Color(0xFF28090B);

  // Annotation categories: exclusive hues, not used as app accent/status.
  static const annNote = Color(0xFFC85A42);
  static const annQuote = Color(0xFF2F7FB0);
  static const annTheory = Color(0xFF9A5FAF);
  static const annQuestion = Color(0xFFC45B8A);

  // ─── Paper / Ink (neutrals) ────────────────────────────────
  static const paper50 = Color(0xFFFFFFFF);
  static const paper100 = Color(0xFFF7F7F5);
  static const paper200 = Color(0xFFEFEFEC);
  static const paper300 = Color(0xFFE5E5E0);
  static const paper400 = Color(0xFFC9C9C2);
  static const paper500 = Color(0xFFA3A39C);
  static const paper600 = Color(0xFF7A7A74);
  static const paper700 = Color(0xFF525250);
  static const paper800 = Color(0xFF2E2E2D);
  static const paper900 = Color(0xFF18181A);

  /// Light scaffold — warm papyrus (`--paper-canvas` / `--bg`).
  static const paperCanvas = Color(0xFFFAF5EF);

  static const ink50 = Color(0xFFFAFAF9);
  static const ink100 = Color(0xFFEDEDEB);
  static const ink200 = Color(0xFFC7C7C2);
  static const ink300 = Color(0xFF8E8E8A);
  static const ink400 = Color(0xFF5E5E5B);
  static const ink500 = Color(0xFF404040);
  static const ink600 = Color(0xFF2A2A2A);
  static const ink700 = Color(0xFF1F1F1F);
  static const ink800 = Color(0xFF161617);
  static const ink900 = Color(0xFF0F1014);

  // ─── Dark theme surface tokens (per design) ───────────────
  static const darkBg = Color(0xFF0E1018);
  static const darkSurface1 = Color(0xFF161A26);
  static const darkSurface2 = Color(0xFF1F2433);
  static const darkFg1 = Color(0xFFF2F2F5);
  static const darkFg2 = Color(0xFFB7B8C0);
  static const darkFg3 = Color(0xFF808290);

  // ─── Fonts ────────────────────────────────────────────────
  static const fontDisplay = 'Newsreader';
  static const fontUi = 'DMSans';
  static const fontMono = 'JetBrainsMono';

  /// Platform UI fonts so missing DM Sans / Newsreader glyphs (arrows, emoji)
  /// do not render as iOS tofu.
  static const fontFamilyFallback = <String>[
    'CupertinoSystemText',
    'Roboto',
  ];

  // ─── Spacing (4-pt) ───────────────────────────────────────
  static const sp0 = 0.0;
  static const sp1 = 2.0;
  static const sp2 = 4.0;
  static const sp3 = 8.0;
  static const sp4 = 12.0;
  static const sp5 = 16.0;
  static const sp6 = 20.0;
  static const sp7 = 24.0;
  static const sp8 = 32.0;
  static const sp9 = 40.0;
  static const sp10 = 56.0;
  static const sp11 = 72.0;
  static const sp12 = 96.0;

  // ─── Radii ────────────────────────────────────────────────
  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const radiusCard = 12.0;
  static const radiusLg = 16.0;
  static const radiusSheet = 20.0;
  static const radiusPill = 999.0;

  // ─── Elevation (menus / dialogs / floating overlays) ──────
  // Material elevation for PopupMenu / Menu / Dialog. Shadows are
  // cooled slate-tinted, matching --shadow-floating in design tokens.
  static const overlayElevation = 8.0;
  static const overlayShadowLight = Color(0x2E0F1014); // ~18% ink-900
  static const overlayShadowDark = Color(0xBF000000); // ~75% black

  /// Deep-lift toast shadows — stronger than [overlayShadowLight] so the
  /// icon-chip pill separates from papyrus / night canvas (design mockup A).
  static List<BoxShadow> toastDeepLiftShadows(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [
          BoxShadow(color: Color(0x0FF2F2F5)),
          BoxShadow(
            color: Color(0xD9000000), // ~85% black
            offset: Offset(0, 16),
            blurRadius: 40,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Color(0x8C000000), // ~55% black
            offset: Offset(0, 6),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0D0F1014), // ~5% ink-900
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x520F1014), // ~32% ink-900
            offset: Offset(0, 14),
            blurRadius: 36,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Color(0x1F0F1014), // ~12% ink-900
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ];

  // ─── Confetti (celebration moments) ───────────────────────
  // Shared brand palette for confetti/fireworks bursts.
  static const List<Color> confettiColors = [
    periwinkle500,
    amber500,
    sage500,
    wine400,
    teal300,
  ];
}
