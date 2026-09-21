import UIKit
import UniformTypeIdentifiers

/// Share Extension: text/URLs → quote composer.
/// Payload lives in the App Group; `readendar://share/quote` is a nudge.
/// Opening the host is best-effort; the app also drains on cold start and resume.
class ShareViewController: UIViewController {
  private let appGroupId = "group.com.readendar.readendar"
  private let pendingQuoteKey = "share.pendingQuoteText"

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.startAnimating()
    view.addSubview(spinner)
    NSLayoutConstraint.activate([
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    Task { await routeIncoming() }
  }

  @MainActor
  private func routeIncoming() async {
    let text = await resolvedShareText()
    guard !text.isEmpty else {
      completeWithoutHost()
      return
    }
    stageQuote(text: text)
    openHost(url: shareURL(path: "/quote")) { self.completeWithoutHost() }
  }

  private func shareURL(path: String) -> URL? {
    var components = URLComponents()
    components.scheme = "readendar"
    components.host = "share"
    components.path = path
    return components.url
  }

  private func stageQuote(text: String) {
    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.set(text, forKey: pendingQuoteKey)
    defaults?.synchronize()
  }

  private func completeWithoutHost() {
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }

  private func openHost(url: URL?, completion: @escaping () -> Void) {
    guard let url else {
      completion()
      return
    }
    var finished = false
    let finish: () -> Void = {
      guard !finished else { return }
      finished = true
      completion()
    }

    extensionContext?.open(url) { success in
      if success { finish() }
    }

    var responder: UIResponder? = self
    let openSel = NSSelectorFromString("openURL:")
    while let current = responder {
      if let application = current as? UIApplication {
        application.open(url, options: [:]) { _ in finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: finish)
        return
      }
      if current.responds(to: openSel) {
        _ = current.perform(openSel, with: url as NSURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: finish)
        return
      }
      responder = current.next
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: finish)
  }

  private func resolvedShareText() async -> String {
    if let item = extensionContext?.inputItems.first as? NSExtensionItem {
      let attributed = item.attributedContentText?.string
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !attributed.isEmpty { return attributed }
    }

    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let providers = item.attachments
    else { return "" }

    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        if let url = await loadURL(from: provider), isWebURL(url) {
          return url.absoluteString
        }
      }
      if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        if let text = await loadString(from: provider, type: UTType.plainText.identifier) {
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty { return trimmed }
        }
      }
    }
    return ""
  }

  private func isWebURL(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased() ?? ""
    return scheme == "http" || scheme == "https"
  }

  private func loadString(from provider: NSItemProvider, type: String) async -> String? {
    await withCheckedContinuation { cont in
      provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
        if let s = item as? String {
          cont.resume(returning: s)
        } else if let data = item as? Data {
          cont.resume(returning: String(data: data, encoding: .utf8))
        } else {
          cont.resume(returning: nil)
        }
      }
    }
  }

  private func loadURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { cont in
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
        if let url = item as? URL {
          cont.resume(returning: url)
        } else if let s = item as? String {
          cont.resume(returning: URL(string: s))
        } else {
          cont.resume(returning: nil)
        }
      }
    }
  }
}
