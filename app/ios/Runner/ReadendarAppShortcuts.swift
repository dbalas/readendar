import AppIntents
import UIKit

/// Discoverable App Shortcuts for Siri / Shortcuts / Spotlight suggestions.
/// Opens the host app via the same `readendar://` scheme widget deep links use.
@available(iOS 16.0, *)
struct OpenQuoteComposerIntent: AppIntent {
  static var title: LocalizedStringResource = "Nueva anotación"
  static var description = IntentDescription("Abre el compositor de anotaciones en Readendar.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await Self.open(url: URL(string: "readendar://quote/new")!)
    return .result()
  }

  private static func open(url: URL) async {
    await MainActor.run {
      UIApplication.shared.open(url)
    }
  }
}

@available(iOS 16.0, *)
struct OpenProgressIntent: AppIntent {
  static var title: LocalizedStringResource = "Registrar progreso"
  static var description = IntentDescription("Abre el progreso de lectura en Readendar.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      UIApplication.shared.open(URL(string: "readendar://progress")!)
    }
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenCalendarIntent: AppIntent {
  static var title: LocalizedStringResource = "Qué toca leer"
  static var description = IntentDescription("Abre el calendario de lectura en Readendar.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      UIApplication.shared.open(URL(string: "readendar://calendar")!)
    }
    return .result()
  }
}

@available(iOS 16.0, *)
struct ReadendarAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenQuoteComposerIntent(),
      phrases: [
        "Nueva anotación en \(.applicationName)",
        "Añade una anotación en \(.applicationName)",
      ],
      shortTitle: "Nueva anotación",
      systemImageName: "quote.bubble"
    )
    AppShortcut(
      intent: OpenProgressIntent(),
      phrases: [
        "Registrar progreso en \(.applicationName)",
        "Actualiza tu lectura en \(.applicationName)",
      ],
      shortTitle: "Registrar progreso",
      systemImageName: "book"
    )
    AppShortcut(
      intent: OpenCalendarIntent(),
      phrases: [
        "Qué toca leer en \(.applicationName)",
        "Muestra mi calendario de lectura en \(.applicationName)",
      ],
      shortTitle: "Qué toca leer",
      systemImageName: "calendar"
    )
  }
}
