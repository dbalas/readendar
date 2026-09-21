import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/features/library/rating_sheet.dart';

class RatingReviewValue {
  const RatingReviewValue({required this.save, this.rating, this.review = ''});

  final bool save;
  final double? rating;
  final String review;
}

Future<RatingReviewValue?> showRatingReviewSheet(
  BuildContext context, {
  double? currentRating,
  String currentReview = '',
  bool allowSkip = false,
}) => showRdModalSheet<RatingReviewValue>(
  context: context,
  builder: (_) => _RatingReviewSheet(
    currentRating: currentRating,
    currentReview: currentReview,
    allowSkip: allowSkip,
  ),
);

class _RatingReviewSheet extends StatefulWidget {
  const _RatingReviewSheet({
    required this.currentRating,
    required this.currentReview,
    required this.allowSkip,
  });

  final double? currentRating;
  final String currentReview;
  final bool allowSkip;

  @override
  State<_RatingReviewSheet> createState() => _RatingReviewSheetState();
}

class _RatingReviewSheetState extends State<_RatingReviewSheet> {
  // Default 0 is a valid rating (half-star steps in [0, 5]); review is always
  // editable — no need to tap stars first.
  late double _rating = widget.currentRating ?? 0;
  late final TextEditingController _review = TextEditingController(
    text: widget.currentReview,
  );

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ReadendarTokens.sp6,
        ReadendarTokens.sp2,
        ReadendarTokens.sp6,
        ReadendarTokens.sp7,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.reviewTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: ReadendarTokens.sp6),
            HalfStarPicker(
              value: _rating,
              size: 42,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: ReadendarTokens.sp4),
            // Same readout as the rating-only sheet / book-detail number.
            Row(
              key: ValueKey(_rating),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmtRating(_rating),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: context.colors.warning,
                  ),
                ),
                Text(
                  ' / 5',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colors.fg3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReadendarTokens.sp5),
            RdTextField(
              controller: _review,
              minLines: 4,
              maxLines: 10,
              maxLength: 5000,
              decoration: InputDecoration(labelText: l.reviewHint),
            ),
            const SizedBox(height: ReadendarTokens.sp4),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                runAlignment: WrapAlignment.end,
                spacing: ReadendarTokens.sp3,
                runSpacing: ReadendarTokens.sp3,
                children: [
                  if (widget.currentRating != null ||
                      widget.currentReview.isNotEmpty)
                    RdButton.plain(
                      key: const Key('rating-review-clear'),
                      onPressed: () => Navigator.pop(
                        context,
                        const RatingReviewValue(save: true),
                      ),
                      label: l.ratingClear,
                    ),
                  if (widget.allowSkip)
                    RdButton.plain(
                      key: const Key('rating-review-skip'),
                      onPressed: () => Navigator.pop(
                        context,
                        const RatingReviewValue(save: false),
                      ),
                      label: l.finishWithoutReview,
                    ),
                  RdButton.primary(
                    key: const Key('rating-review-save'),
                    onPressed: () => Navigator.pop(
                      context,
                      RatingReviewValue(
                        save: true,
                        rating: _rating,
                        review: _review.text.trim(),
                      ),
                    ),
                    icon: LucideIcons.save,
                    label: l.actionSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
