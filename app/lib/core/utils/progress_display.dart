/// Display helpers for reading progress.
///
/// Domain and the progress editor keep page and percentage in sync when a total
/// page count is known. Chapter is the independent field. Display still needs a
/// single source of truth when stored values disagree (no total, stale pair, or
/// both supplied without sync): **pages win** whenever page + total are known;
/// an explicit percentage is only used when percentage cannot be derived.
library;

/// Resolves the percentage shown in progress UI (badges, bars, previews).
///
/// Prefer page ÷ [pageCount] when both are known. Fall back to
/// [currentPercentage] only when derivation is impossible.
int? effectiveProgressPercent({
  int? currentPage,
  int? currentPercentage,
  int? pageCount,
}) {
  if (currentPage != null && pageCount != null && pageCount > 0) {
    return ((currentPage / pageCount) * 100).round().clamp(0, 100);
  }
  final pct = currentPercentage;
  if (pct == null) return null;
  return pct.clamp(0, 100);
}

/// Whether a percent label (and matching bar fill) should appear next to a page.
///
/// When a page is set but total pages are unknown, an explicit percentage can
/// disagree with that page — suppress the percent so the badge has one truth.
bool shouldShowProgressPercentLabel({
  int? currentPage,
  int? currentPercentage,
  int? pageCount,
}) {
  final pct = effectiveProgressPercent(
    currentPage: currentPage,
    currentPercentage: currentPercentage,
    pageCount: pageCount,
  );
  if (pct == null) return false;
  if (currentPage != null && (pageCount == null || pageCount <= 0)) {
    return false;
  }
  return true;
}
