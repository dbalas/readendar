// Dedicated "thank you" screen shown after feedback is sent. A small, calm
// moment — a custom-built illustration (no art assets), a warm line, and one
// gentle confetti burst — so the user feels genuinely heard, not toasted.

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_button.dart';

class FeedbackThanksScreen extends StatefulWidget {
  const FeedbackThanksScreen({super.key});

  @override
  State<FeedbackThanksScreen> createState() => _FeedbackThanksScreenState();
}

class _FeedbackThanksScreenState extends State<FeedbackThanksScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scale = CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(scale: scale, child: const _ThanksBadge()),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: fade,
                      child: Column(
                        children: [
                          Text(
                            l.feedbackThanksTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              l.feedbackThanksBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.colors.fg2,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          RdButton.primary(
                            onPressed: () => Navigator.of(context).pop(),
                            label: l.feedbackThanksDone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // One short, centred burst — celebratory but not a full rain.
          Align(
            alignment: const Alignment(0, -0.2),
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 16,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.25,
              emissionFrequency: 0,
              colors: ReadendarTokens.confettiColors,
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft teal halo with a filled brand chip and a heart-message mark.
class _ThanksBadge extends StatelessWidget {
  const _ThanksBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: const BoxDecoration(
              color: ReadendarTokens.teal50,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              color: ReadendarTokens.teal100,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: ReadendarTokens.teal600,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.messageCircleHeart,
              color: ReadendarTokens.paper50,
              size: 36,
            ),
          ),
          // A couple of decorative sparks in brand colors.
          const Positioned(
            top: 12,
            right: 18,
            child: _Spark(color: ReadendarTokens.amber500, size: 12),
          ),
          const Positioned(
            bottom: 20,
            left: 14,
            child: _Spark(color: ReadendarTokens.periwinkle500, size: 9),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Icon(LucideIcons.sparkle, color: color, size: size),
    );
  }
}
