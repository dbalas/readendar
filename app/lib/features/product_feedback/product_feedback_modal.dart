import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';

enum ProductFeedbackModalResult { share, dismissed }

/// Soft, branded ask for in-app feedback. Returns
/// [ProductFeedbackModalResult.share] when the user taps the CTA (caller
/// should mail hello@readendar.com via [showProductFeedbackModalAndMail]);
/// dismiss / barrier / Not now → dismissed.
Future<ProductFeedbackModalResult?> showProductFeedbackModal(
  BuildContext context,
) {
  return showGeneralDialog<ProductFeedbackModalResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondary) => const ProductFeedbackModal(),
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Presents the feedback modal and, on CTA, opens mail to hello@readendar.com.
/// Every production and debug call site must use this so send cannot diverge.
Future<ProductFeedbackModalResult?> showProductFeedbackModalAndMail(
  BuildContext context,
) async {
  final result = await showProductFeedbackModal(context);
  if (result == ProductFeedbackModalResult.share && context.mounted) {
    await openFeedbackMailto(context);
  }
  return result;
}

@visibleForTesting
class ProductFeedbackModal extends StatefulWidget {
  const ProductFeedbackModal({super.key});

  @override
  State<ProductFeedbackModal> createState() => _ProductFeedbackModalState();
}

class _ProductFeedbackModalState extends State<ProductFeedbackModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: colors.fg1.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(_pulse.value);
                        return Transform.translate(
                          offset: Offset(0, -4 * t),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ReadendarTokens.periwinkle400,
                              ReadendarTokens.teal500,
                            ],
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.messageCircle,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.productFeedbackTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.productFeedbackBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.fg2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: RdButton.primary(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(ProductFeedbackModalResult.share),
                        icon: LucideIcons.messageCircle,
                        label: l.productFeedbackCta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RdButton.plain(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProductFeedbackModalResult.dismissed),
                      label: l.productFeedbackNotNow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
