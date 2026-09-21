// Shared book-share bits with no UI deps.

final _isbn13ShareRef = RegExp(r'^[0-9]{13}$');

bool isBookShareRef(String ref) {
  if (ref.isEmpty || ref.length > 13) return false;
  return _isbn13ShareRef.hasMatch(ref);
}
