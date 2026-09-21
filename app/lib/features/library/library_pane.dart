import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:readendar/di/providers.dart';

/// Owned-books canvas inside the Libros root tab.
enum LibraryPane { books }

/// Survives leaving the Libros tab so Home can open the library before the
/// screen mounts. Recreated (back to books) on user-id change.
final libraryPaneProvider = StateProvider<LibraryPane>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return LibraryPane.books;
});

/// Single owner for "go to Libros". Always owned books.
void openLibrosTab(WidgetRef ref) {
  ref.read(libraryPaneProvider.notifier).state = LibraryPane.books;
  ref.read(tabIndexProvider.notifier).state = 1;
}
