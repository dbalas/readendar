/// Email shape check aligned with backend `user.ParseEmail`
/// (`^[^@\s]+@[^@\s]+\.[^@\s]+$`, max 254 after trim/lower).
final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String raw) {
  final s = raw.trim().toLowerCase();
  return s.length <= 254 && _emailRe.hasMatch(s);
}
