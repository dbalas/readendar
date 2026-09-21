/// Context for the shared book detail screen: same chrome, different visibility.
enum BookDetailScope {
  /// Caller's library copy — full personal chrome.
  personal,
}

/// Feature flags derived from [BookDetailScope].
///
/// One screen owns the layout; callers pass [bookId] for personal library books.
class BookDetailVisibility {
  const BookDetailVisibility({
    required this.scope,
    required this.canEdit,
    required this.showCreateActions,
    required this.showEditInfo,
    required this.showOverflowMenu,
    required this.showStatusProgress,
    required this.showPlan,
    required this.showNotesQuotes,
    required this.showRating,
    required this.ratingEditable,
    required this.showPageTotalsInMetadata,
  });

  factory BookDetailVisibility.forOwnedBook({
    required bool canEdit,
    required bool canPlan,
  }) {
    return BookDetailVisibility(
      scope: BookDetailScope.personal,
      canEdit: canEdit,
      showCreateActions: canEdit,
      showEditInfo: canEdit,
      showOverflowMenu: canEdit,
      showStatusProgress: true,
      showPlan: canPlan,
      showNotesQuotes: true,
      showRating: true,
      ratingEditable: canEdit,
      showPageTotalsInMetadata: false,
    );
  }

  final BookDetailScope scope;
  final bool canEdit;
  final bool showCreateActions;
  final bool showEditInfo;
  final bool showOverflowMenu;
  final bool showStatusProgress;
  final bool showPlan;
  final bool showNotesQuotes;
  final bool showRating;
  final bool ratingEditable;
  final bool showPageTotalsInMetadata;
}
