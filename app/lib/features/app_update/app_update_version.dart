/// Compares dotted marketing versions (`1.1.6` vs `1.1.10`).
///
/// Missing or unparsable segments count as 0. Returns negative if [a] < [b].
int compareDottedVersions(String a, String b) {
  final ap = _parts(a);
  final bp = _parts(b);
  final n = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < n; i++) {
    final av = i < ap.length ? ap[i] : 0;
    final bv = i < bp.length ? bp[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

bool isNewerVersion(String store, String installed) =>
    compareDottedVersions(store, installed) > 0;

List<int> _parts(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [0];
  return [
    for (final piece in trimmed.split('.')) int.tryParse(piece.trim()) ?? 0,
  ];
}
