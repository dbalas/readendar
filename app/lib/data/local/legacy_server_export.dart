/// Frozen JSON keys and enum strings from retired cloud exports.
///
/// Single migration seam: product code must not scatter these literals.
abstract final class LegacyServerExport {
  LegacyServerExport._();

  static const ownerTypeShared = 'club';
  static const linkedOwnerIdKey = 'linkedClubId';
  static const linkedBookIdKey = 'linkedClubBookId';
  static const groupIdKey = 'clubId';

  static const stripKeys = <String>{
    linkedOwnerIdKey,
    linkedBookIdKey,
    groupIdKey,
  };
}
