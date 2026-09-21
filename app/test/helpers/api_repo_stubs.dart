import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/data/repository_ports.dart';

/// Test-only stand-ins for retired hosted adapters. Subclasses override the
/// methods they exercise. Production code uses SQLite repositories.
class ApiBookRepository extends Fake implements BookRepository {
  ApiBookRepository(Object? _);
}

class ApiEventRepository extends Fake implements EventRepository {
  ApiEventRepository(Object? _);

  @override
  Future<Result<EventUserState>> markSeen(String id) async => Ok(
    EventUserState(
      eventId: id,
      status: 'active',
      reminderEnabled: true,
      muted: false,
    ),
  );
}

class ApiProgressRepository extends Fake implements ProgressRepository {
  ApiProgressRepository(Object? _);
}

class ApiPlanRepository extends Fake implements PlanRepository {
  ApiPlanRepository(Object? _);
}

class ApiCustomFieldRepository extends Fake implements CustomFieldRepository {
  ApiCustomFieldRepository(Object? _);
}

class ApiNotificationRepository extends Fake implements NotificationRepository {
  ApiNotificationRepository(Object? _);
}

class ApiAnnotationRepository extends Fake implements AnnotationRepository {
  ApiAnnotationRepository(Object? _);
}

class ApiUploadRepository extends Fake implements UploadRepository {
  ApiUploadRepository(Object? _);
}

class ApiReadingChapterRepository extends Fake
    implements ReadingChapterRepository {
  ApiReadingChapterRepository(Object? api, Object? prefs, Object? userId);

  @override
  void dispose() {}

  @override
  ReadingChapterStory? cachedStory(ReadingChapterRequest request) => null;

  @override
  ReadingChapterArchive? cachedArchive({String kind = 'all'}) => null;

  @override
  ReadingChapterArchive? cachedLatest() => null;
}
