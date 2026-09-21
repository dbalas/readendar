import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import '../../helpers/api_repo_stubs.dart';

Book testBook({
  String id = 'b1',
  String title = 'Cien años de soledad',
  String status = BookStatus.reading,
  int? pageCount = 400,
  String? coverUrl,
  String ownerType = 'user',
  String ownerId = 'u1',
}) => Book(
  id: id,
  ownerType: ownerType,
  ownerId: ownerId,
  title: title,
  authors: const ['Gabriel García Márquez'],
  status: status,
  pageCount: pageCount,
  coverUrl: coverUrl ?? '',
);

AppUser testAppUser({String id = 'u1'}) => AppUser(
  id: id,
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime(2026, 7),
);

class FakeSessionNotifier extends SessionNotifier {
  FakeSessionNotifier(super.ref, {String userId = 'u1'}) {
    state = SessionState(user: testAppUser(id: userId));
  }
}

Quote testQuote({
  String id = 'q1',
  String bookId = 'b1',
  String text = 'El mundo era tan reciente',
  String bookTitle = '',
  List<String> bookAuthors = const [],
  int? page,
  bool favorite = false,
  bool pinned = false,
  String note = '',
  AnnotationCategory category = AnnotationCategory.quote,
  DateTime? createdAt,
}) => Quote(
  id: id,
  bookId: bookId,
  text: text,
  bookTitle: bookTitle,
  bookAuthors: bookAuthors,
  page: page,
  favorite: favorite,
  pinned: pinned,
  note: note,
  category: category,
  createdAt: createdAt ?? DateTime.utc(2026, 7, 2),
  updatedAt: createdAt ?? DateTime.utc(2026, 7, 2),
);

/// In-memory QuoteRepository: seeds `initial`, records calls, and never
/// touches the network.
class FakeQuoteRepository extends ApiAnnotationRepository {
  FakeQuoteRepository(this.quotes)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  final List<Quote> quotes;
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Quote>[];
  final deleteCalls = <String>[];
  bool failMutations = false;
  Duration updateDelay = Duration.zero;
  int _seq = 0;

  @override
  Future<Result<List<Quote>>> listMine() async => Ok(List.of(quotes));

  @override
  Future<Result<List<Annotation>>> listForBook(
    String bookId, {
    AnnotationCategory? category,
    String q = '',
  }) async {
    var items = quotes.where((e) => e.bookId == bookId);
    if (category != null) {
      items = items.where((e) => e.category == category);
    }
    final needle = q.trim().toLowerCase();
    if (needle.isNotEmpty) {
      items = items.where(
        (e) =>
            e.body.toLowerCase().contains(needle) ||
            e.commentary.toLowerCase().contains(needle),
      );
    }
    return Ok(items.toList());
  }

  @override
  Future<Result<Annotation>> get(String id) async {
    final found = quotes.where((e) => e.id == id).firstOrNull;
    if (found == null) return const Err(UnknownFailure('missing'));
    return Ok(found);
  }

  @override
  Future<Result<Quote>> create({
    required String bookId,
    required String body,
    AnnotationCategory category = AnnotationCategory.quote,
    int? page,
    int? chapter,
    bool pinned = false,
    String commentary = '',
    bool spoiler = false,
    String? text,
    bool favorite = false,
    String note = '',
  }) async {
    final resolvedBody = body.isNotEmpty ? body : (text ?? '');
    final resolvedPinned = pinned;
    final resolvedFavorite = favorite;
    final resolvedCommentary = commentary.isNotEmpty ? commentary : note;
    createCalls.add({
      'bookId': bookId,
      'body': resolvedBody,
      'text': resolvedBody,
      'category': category,
      'page': page,
      'chapter': chapter,
      'pinned': resolvedPinned,
      'favorite': resolvedFavorite,
      'commentary': resolvedCommentary,
      'note': resolvedCommentary,
    });
    if (failMutations) return const Err(UnknownFailure('boom'));
    final q = Quote(
      id: 'new-${_seq++}',
      bookId: bookId,
      body: resolvedBody,
      category: category,
      page: page,
      chapter: chapter,
      pinned: resolvedPinned,
      favorite: resolvedFavorite,
      commentary: resolvedCommentary,
      spoiler: spoiler,
    );
    quotes.insert(0, q);
    return Ok(q);
  }

  @override
  Future<Result<Quote>> update(Quote q) async {
    if (updateDelay > Duration.zero) {
      await Future<void>.delayed(updateDelay);
    }
    updateCalls.add(q);
    if (failMutations) return const Err(UnknownFailure('boom'));
    final i = quotes.indexWhere((e) => e.id == q.id);
    if (i >= 0) quotes[i] = q;
    return Ok(q);
  }

  @override
  Future<Result<void>> delete(String id) async {
    deleteCalls.add(id);
    if (failMutations) return const Err(UnknownFailure('boom'));
    quotes.removeWhere((e) => e.id == id);
    return const Ok(null);
  }
}

class FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}
