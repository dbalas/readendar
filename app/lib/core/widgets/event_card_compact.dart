import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/completed_badge.dart';
import 'package:readendar/core/widgets/event_icon.dart';

class EventCardCompact extends StatelessWidget {
  const EventCardCompact({
    required this.title,
    required this.type,
    super.key,
    this.bookTitle,
    this.bookAuthor,
    this.bookCoverUrl,
    this.bookCoverColor,
    this.subtitle,
    this.completed = false,
    this.showCompletedBadge = true,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final EventType type;
  final String? bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final Color? bookCoverColor;
  final String? subtitle;
  final bool completed;

  /// The floating sage "done" badge over the top-right corner. On by default
  /// (the Home/calendar lists), but off for the home-screen-widget preview,
  /// where a leading complete toggle already conveys completion and the corner
  /// badge would be redundant — the native widgets show only the leading mark.
  final bool showCompletedBadge;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBookTitle = bookTitle != null && bookTitle!.isNotEmpty;
    final hasBookAuthor = bookAuthor != null && bookAuthor!.isNotEmpty;
    final hasBookInfo =
        hasBookTitle || hasBookAuthor || (bookCoverUrl ?? '').isNotEmpty;
    final hasLeading = hasBookInfo;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: completed || !enabled ? 0.5 : 1.0,
          child: RdCard(
            onTap: enabled ? onTap : null,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                if (hasBookInfo) ...[
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        if (hasBookTitle) ...[
                          BookCover(
                            title: bookTitle!,
                            author: bookAuthor,
                            coverUrl: bookCoverUrl,
                            color: bookCoverColor,
                            size: BookCoverSize.xs,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasBookTitle)
                                Text(
                                  bookTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: ReadendarTokens.fontUi,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                              if (hasBookAuthor) ...[
                                if (hasBookTitle) const SizedBox(height: 2),
                                Text(
                                  bookAuthor!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.fg2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: hasLeading ? 4 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          EventIcon(type: type, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: ReadendarTokens.fontUi,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: type.colorOf(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Absolutely positioned so the badge never reserves space inside the row.
        if (completed && showCompletedBadge)
          const Positioned(top: -6, right: -6, child: CompletedBadge(size: 20)),
      ],
    );
  }
}
