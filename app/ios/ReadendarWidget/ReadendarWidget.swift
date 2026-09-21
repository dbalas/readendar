// Readendar home-screen widget (iOS / WidgetKit).
//
// Product data is local. The app writes `wdg_cached_summary` and
// `wdg_quotes_cache`; timelines render that cache. Taps enqueue
// `wdg_pending_ops` so the next app open applies them to SQLite.
// Per-element taps open readendar://book/{id} and readendar://event/{id}.

import WidgetKit
import SwiftUI
import UIKit
import CryptoKit
import AppIntents

// MARK: - Shared storage (App Group)

private let appGroupId = "group.com.readendar.readendar"

private enum Keys {
    static let access = "wdg_access"
    static let refresh = "wdg_refresh"
    static let userId = "wdg_user"
    static let baseUrl = "wdg_base_url"
    static let locale = "wdg_locale"
    static let theme = "wdg_theme"
    static let appTheme = "wdg_app_theme"
    static let scheme = "wdg_scheme"
    static let cachedSummary = "wdg_cached_summary" // last-known JSON
    static let quotesCache = "wdg_quotes_cache" // quotes widget snapshot
    static let pendingOps = "wdg_pending_ops"
}

private func defaults() -> UserDefaults {
    // home_widget 0.9.3 writes unprefixed App Group keys. Read the plain key
    // first, then the legacy `flutter.` prefix from older plugin builds.
    UserDefaults(suiteName: appGroupId) ?? .standard
}

private func shared(_ key: String) -> String? {
    let d = defaults()
    return d.string(forKey: key) ?? d.string(forKey: "flutter.\(key)")
}

private func setShared(_ key: String, _ value: String) {
    let d = defaults()
    d.set(value, forKey: key)
    // Do not write `flutter.` keys. iOS deletes via native removeObject on
    // both the unprefixed key and this legacy prefix.
    d.synchronize()
}

private func removeShared(_ key: String) {
    let d = defaults()
    d.removeObject(forKey: key)
    d.removeObject(forKey: "flutter.\(key)")
    d.synchronize()
}

// MARK: - Persistent cover cache (last-known-good bytes, survives fetch failures)

/// Disk cache for cover bytes, keyed by a SHA-256 of the URL (stable across
/// process relaunches — WidgetKit extensions are re-spawned per timeline
/// refresh, so an in-memory-only cache buys nothing here). Every timeline
/// refresh (~30 min) re-fetches every cover with no retry; without a
/// persistent fallback, a transient network failure would silently drop a
/// cover that was already showing fine. Trimmed to `maxEntries` by oldest
/// modification date so it can't grow unbounded.
enum CoverDiskCache {
    private static let dirName = "widget_covers"
    private static let maxEntries = 60

    private static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(dirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func key(for url: String) -> String {
        SHA256.hash(data: Data(url.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func localFileURL(_ url: String) -> URL? {
        if url.hasPrefix("file:") { return URL(string: url) }
        if url.hasPrefix("/") { return URL(fileURLWithPath: url) }
        return nil
    }

    static func read(_ url: String) -> Data? {
        if let local = localFileURL(url), let data = try? Data(contentsOf: local) {
            return data
        }
        return try? Data(contentsOf: directory.appendingPathComponent(key(for: url)))
    }

    static func write(_ url: String, _ data: Data) {
        // .atomic writes to a temp file and renames, so a concurrent read (the
        // preload TaskGroup fetches covers in parallel) never sees a torn file.
        try? data.write(to: directory.appendingPathComponent(key(for: url)), options: .atomic)
        trim()
    }

    private static func trim() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ), files.count > maxEntries else { return }
        let sorted = files.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d0 < d1
        }
        for f in sorted.prefix(files.count - maxEntries) { try? FileManager.default.removeItem(at: f) }
    }
}

private func coverResourceURL(_ raw: String) -> URL? {
    if raw.hasPrefix("file:") { return URL(string: raw) }
    if raw.hasPrefix("/") { return URL(fileURLWithPath: raw) }
    return URL(string: raw)
}

// MARK: - Model (mirrors the app-pushed wdg_cached_summary JSON)

/// Drops a single malformed array element instead of failing the whole payload.
/// Native JSONDecoder otherwise treats one null `coverUrl` as "couldn't update".
private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct WidgetSummary: Codable {
    var readingBooks: [WBook]
    var events: [WEvent]
    // Optional so a snapshot cached by an older build still decodes.
    var hasMore: Bool?
    static let empty = WidgetSummary(readingBooks: [], events: [], hasMore: false)
    static let progressPreview = WidgetSummary(
        readingBooks: [
            WBook(
                id: "preview",
                title: "The Hobbit",
                author: "J. R. R. Tolkien",
                coverUrl: "",
                progressPct: 40,
                currentPage: 120,
                pageCount: 300,
                currentChapter: 7,
                chapterCount: 20
            ),
            WBook(
                id: "preview-2",
                title: "Dune",
                author: "Frank Herbert",
                coverUrl: "",
                progressPct: 10,
                currentPage: 41,
                pageCount: 412,
                currentChapter: 3,
                chapterCount: 22
            ),
        ],
        events: [],
        hasMore: false
    )

    enum CodingKeys: String, CodingKey { case readingBooks, events, hasMore }

    init(readingBooks: [WBook], events: [WEvent], hasMore: Bool?) {
        self.readingBooks = readingBooks
        self.events = events
        self.hasMore = hasMore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        readingBooks = (try? c.decode([Lossy<WBook>].self, forKey: .readingBooks))?.compactMap(\.value) ?? []
        events = (try? c.decode([Lossy<WEvent>].self, forKey: .events))?.compactMap(\.value) ?? []
        hasMore = try? c.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}

/// Whether an entry's summary is a genuine "nothing to show" state (fetch
/// succeeded, or a valid cache exists, but there's really no reading book and
/// no event) vs. a fetch failure with no usable cache at all — those need a
/// visually distinct state so the widget doesn't claim "you have nothing
/// going on" when it actually just couldn't reach the server.
enum WidgetDataState {
    case ok
    /// Last-known snapshot after a failed refresh. Show it, but do not treat
    /// it as live server truth (retry stays available when the payload is empty).
    case stale
    case error
}

struct WBook: Codable, Identifiable {
    var id: String
    var title: String
    var author: String
    var coverUrl: String
    var progressPct: Int?
    var currentPage: Int?
    var pageCount: Int?
    var currentChapter: Int?
    var chapterCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, author, coverUrl, progressPct, currentPage, pageCount, currentChapter, chapterCount
    }

    init(
        id: String,
        title: String,
        author: String,
        coverUrl: String,
        progressPct: Int? = nil,
        currentPage: Int? = nil,
        pageCount: Int? = nil,
        currentChapter: Int? = nil,
        chapterCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.progressPct = progressPct
        self.currentPage = currentPage
        self.pageCount = pageCount
        self.currentChapter = currentChapter
        self.chapterCount = chapterCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        author = (try? c.decodeIfPresent(String.self, forKey: .author)) ?? ""
        coverUrl = (try? c.decodeIfPresent(String.self, forKey: .coverUrl)) ?? ""
        progressPct = try? c.decodeIfPresent(Int.self, forKey: .progressPct)
        currentPage = try? c.decodeIfPresent(Int.self, forKey: .currentPage)
        pageCount = try? c.decodeIfPresent(Int.self, forKey: .pageCount)
        currentChapter = try? c.decodeIfPresent(Int.self, forKey: .currentChapter)
        chapterCount = try? c.decodeIfPresent(Int.self, forKey: .chapterCount)
    }
}

struct WProgressUpdate: Codable {
    var currentPage: Int?
    var currentChapter: Int?
    var currentPercentage: Int?
}

struct WEvent: Codable, Identifiable {
    var id: String
    var bookId: String?
    var bookTitle: String?
    /// The event book's author + cover (personal library), so a row can match
    /// the app's event card. Empty when the book isn't resolvable.
    var bookAuthor: String?
    var bookCoverUrl: String?
    var type: String
    /// The event's own persisted title (e.g. "Página 143"), independent of
    /// `bookTitle` — the fallback when a book title can't be resolved.
    var title: String?
    /// "active" | "completed" (optional so an older cached snapshot decodes).
    var status: String?
    var dateLocal: String    // "YYYY-MM-DD"
    var timeLocal: String?   // "HH:MM"
    var tz: String?

    var isCompleted: Bool { status == "completed" }
    /// start/finish/abandoned are informational and can't be ticked off.
    var isCompletable: Bool { !["start", "finish", "abandoned"].contains(type) }

    enum CodingKeys: String, CodingKey {
        case id, bookId, bookTitle, bookAuthor, bookCoverUrl, type, title, status, dateLocal, timeLocal, tz
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        bookId = try? c.decodeIfPresent(String.self, forKey: .bookId)
        bookTitle = try? c.decodeIfPresent(String.self, forKey: .bookTitle)
        bookAuthor = try? c.decodeIfPresent(String.self, forKey: .bookAuthor)
        bookCoverUrl = try? c.decodeIfPresent(String.self, forKey: .bookCoverUrl)
        type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        dateLocal = (try? c.decodeIfPresent(String.self, forKey: .dateLocal)) ?? ""
        timeLocal = try? c.decodeIfPresent(String.self, forKey: .timeLocal)
        tz = try? c.decodeIfPresent(String.self, forKey: .tz)
    }
}

// MARK: - Local snapshot (app writes wdg_cached_summary)

enum WidgetAPI {
    private static func enqueuePendingOp(_ op: [String: Any]) {
        var items: [[String: Any]] = []
        if let raw = shared(Keys.pendingOps),
           let data = raw.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            items = parsed
        }
        items.append(op)
        if let data = try? JSONSerialization.data(withJSONObject: items),
           let json = String(data: data, encoding: .utf8) {
            setShared(Keys.pendingOps, json)
        }
    }

    private static func localProgressUpdate(
        bookID: String,
        field: String,
        value: Int
    ) -> WProgressUpdate {
        let book = cachedBook(bookID)
        var page = book?.currentPage
        var chapter = book?.currentChapter
        var pct = book?.progressPct
        if field == "chapter" {
            chapter = value
        } else {
            page = value
            if let pages = book?.pageCount, pages > 0 {
                pct = min(100, (value * 100) / pages)
            }
        }
        return WProgressUpdate(
            currentPage: page,
            currentChapter: chapter,
            currentPercentage: pct
        )
    }

    /// Renders the App Group cache the Flutter app writes. Snapshots must not
    /// call this.
    static func loadSummary() async -> (summary: WidgetSummary, state: WidgetDataState) {
        return cachedOrError()
    }

    private static func cachedOrError() -> (summary: WidgetSummary, state: WidgetDataState) {
        if hasCache() { return (cached(), .stale) }
        return (.empty, .error)
    }

    private static func coverURLs(
        for s: WidgetSummary,
        prioritizedBookID: String? = nil
    ) -> [String] {
        var urls: [String] = []
        var seen = Set<String>()
        func append(_ url: String) {
            guard !url.isEmpty, seen.insert(url).inserted else { return }
            urls.append(url)
        }
        if let prioritizedBookID,
           let selected = s.readingBooks.first(where: { $0.id == prioritizedBookID }) {
            append(selected.coverUrl)
        }
        if prioritizedBookID == nil {
            // The events widget needs event artwork first. A large reading list
            // must not consume the whole preload budget and blank its rows.
            for e in s.events {
                if let url = e.bookCoverUrl { append(url) }
            }
            for b in s.readingBooks { append(b.coverUrl) }
        } else {
            for b in s.readingBooks { append(b.coverUrl) }
            for e in s.events {
                if let url = e.bookCoverUrl { append(url) }
            }
        }
        return Array(urls.prefix(20))
    }

    /// Returns disk-cached cover bytes without making a network request. Used
    /// for interactive keypad refreshes and book switches, where the widget
    /// must never wait on artwork.
    static func cachedCovers(
        for s: WidgetSummary,
        prioritizedBookID: String? = nil
    ) -> [String: Data] {
        var out: [String: Data] = [:]
        for url in coverURLs(for: s, prioritizedBookID: prioritizedBookID) {
            if let data = CoverDiskCache.read(url) { out[url] = data }
        }
        return out
    }

    /// Preloads cover bytes for the reading strip + event books into a URL→Data
    /// map (deduped, capped). WidgetKit can't fetch images inside the view, so
    /// the provider does it here and passes the bytes into the timeline entry.
    /// On a successful fetch the bytes are persisted to [CoverDiskCache]; on
    /// failure it falls back to the last successfully-fetched bytes on disk.
    static func preloadCovers(
        for s: WidgetSummary,
        prioritizedBookID: String? = nil
    ) async -> [String: Data] {
        var out: [String: Data] = [:]
        await withTaskGroup(of: (String, Data?).self) { group in
            for u in coverURLs(for: s, prioritizedBookID: prioritizedBookID) {
                group.addTask {
                    if let local = CoverDiskCache.read(u), !u.hasPrefix("http") {
                        return (u, local)
                    }
                    guard let url = coverResourceURL(u) else { return (u, CoverDiskCache.read(u)) }
                    if let data = try? await URLSession.shared.data(from: url).0 {
                        CoverDiskCache.write(u, data)
                        return (u, data)
                    }
                    return (u, CoverDiskCache.read(u))
                }
            }
            for await (u, data) in group { if let data { out[u] = data } }
        }
        return out
    }

    @discardableResult
    static func toggleComplete(eventID: String, complete: Bool) async -> Bool {
        enqueuePendingOp([
            "op": "complete",
            "eventId": eventID,
            "complete": complete,
        ])
        return true
    }

    static func updateProgress(
        bookID: String,
        field: String,
        value: Int
    ) async -> WProgressUpdate {
        enqueuePendingOp([
            "op": "progress",
            "bookId": bookID,
            "field": field,
            "value": value,
        ])
        return localProgressUpdate(bookID: bookID, field: field, value: value)
    }

    static func cachedBook(_ bookID: String) -> WBook? {
        cached().readingBooks.first { $0.id == bookID }
    }

    /// Patches both progress and event widget cache for optimistic, rollback,
    /// or durable rendering. A later summary fetch remains authoritative.
    static func setCachedProgress(bookID: String, update: WProgressUpdate) {
        var summary = cached()
        summary.readingBooks = summary.readingBooks.map { book in
            guard book.id == bookID else { return book }
            var copy = book
            copy.currentPage = update.currentPage
            copy.currentChapter = update.currentChapter
            copy.progressPct = update.currentPercentage
            return copy
        }
        cache(summary)
    }

    static func cachedSummary() -> (summary: WidgetSummary, state: WidgetDataState) {
        hasCache() ? (cached(), .ok) : (.empty, .error)
    }

    /// Optimistically flip a cached event's status for instant widget feedback.
    /// The next timeline reload overwrites it with server truth on success, or
    /// keeps it on failure — so the caller reverts on a failed toggle.
    static func setCachedStatus(eventID: String, completed: Bool) {
        var s = cached()
        s.events = s.events.map { e in
            var e = e
            if e.id == eventID { e.status = completed ? "completed" : "active" }
            return e
        }
        cache(s)
    }

    private static func cache(_ s: WidgetSummary) {
        if let data = try? JSONEncoder().encode(s), let json = String(data: data, encoding: .utf8) {
            setShared(Keys.cachedSummary, json)
        }
    }

    private static func cached() -> WidgetSummary {
        guard let json = shared(Keys.cachedSummary), let data = json.data(using: .utf8),
              let s = try? JSONDecoder().decode(WidgetSummary.self, from: data) else {
            return .empty
        }
        return s
    }

    /// Whether a previously-cached snapshot exists (even an empty one from a
    /// successful fetch) — used to tell "genuinely empty" apart from "never
    /// fetched successfully / no cache to fall back to".
    private static func hasCache() -> Bool {
        guard let json = shared(Keys.cachedSummary),
              let data = json.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode(WidgetSummary.self, from: data)) != nil
    }

    // MARK: Quotes widget (ReadendarQuotesWidget.swift)

    /// Quotes snapshot the Flutter app writes to wdg_quotes_cache.
    static func loadQuotes() async -> WidgetQuotesPayload {
        return cachedQuotes()
    }

    static func cachedQuotes() -> WidgetQuotesPayload {
        guard let json = shared(Keys.quotesCache), let data = json.data(using: .utf8),
              let p = try? JSONDecoder().decode(WidgetQuotesPayload.self, from: data) else {
            return .empty
        }
        return p
    }

    private static func cacheQuotes(_ p: WidgetQuotesPayload) {
        if let data = try? JSONEncoder().encode(p), let json = String(data: data, encoding: .utf8) {
            setShared(Keys.quotesCache, json)
        }
    }

    /// Disk-only quote covers for WidgetKit snapshots (no network).
    static func cachedQuoteCovers(_ quotes: [WQuote]) -> [String: Data] {
        var urls = Set<String>()
        for q in quotes { if let u = q.bookCoverUrl, !u.isEmpty { urls.insert(u) } }
        var out: [String: Data] = [:]
        for u in urls.prefix(20) {
            if let data = CoverDiskCache.read(u) { out[u] = data }
        }
        return out
    }

    /// Preloads the cover bytes for a set of quotes (URL→Data, deduped +
    /// capped) with the same disk-cache fallback the summary covers use.
    static func preloadQuoteCovers(_ quotes: [WQuote]) async -> [String: Data] {
        var urls = Set<String>()
        for q in quotes { if let u = q.bookCoverUrl, !u.isEmpty { urls.insert(u) } }
        let capped = Array(urls.prefix(20))
        var out: [String: Data] = [:]
        await withTaskGroup(of: (String, Data?).self) { group in
            for u in capped {
                group.addTask {
                    // Cache-first: a cover URL maps to stable bytes, so once on
                    // disk there's no need to re-download it on every timeline
                    // rebuild (each cadence wake + every app push). Only misses
                    // hit the network.
                    if let cached = CoverDiskCache.read(u) { return (u, cached) }
                    guard let url = coverResourceURL(u) else { return (u, nil) }
                    if let data = try? await URLSession.shared.data(from: url).0 {
                        CoverDiskCache.write(u, data)
                        return (u, data)
                    }
                    return (u, nil)
                }
            }
            for await (u, data) in group { if let data { out[u] = data } }
        }
        return out
    }
}

// MARK: - Quotes model (wdg_quotes_cache contract — see widget_models.dart)

struct WidgetQuotesPayload: Codable {
    var fetchedAt: String?
    var quotes: [WQuote]
    static let empty = WidgetQuotesPayload(fetchedAt: nil, quotes: [])

    enum CodingKeys: String, CodingKey { case fetchedAt, quotes, annotations }

    init(fetchedAt: String?, quotes: [WQuote]) {
        self.fetchedAt = fetchedAt
        self.quotes = quotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try c.decodeIfPresent(String.self, forKey: .fetchedAt)
        let rows: [WQuote]
        if let annotations = try c.decodeIfPresent([WQuote].self, forKey: .annotations) {
            rows = annotations
        } else {
            rows = try c.decodeIfPresent([WQuote].self, forKey: .quotes) ?? []
        }
        quotes = rows.filter { $0.category == nil || $0.category == "quote" }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(fetchedAt, forKey: .fetchedAt)
        try c.encode(quotes, forKey: .quotes)
    }
}

struct WQuote: Codable, Identifiable {
    var id: String
    var text: String
    var page: Int?
    var favorite: Bool?
    var note: String? = nil
    var bookId: String
    var bookTitle: String
    var bookAuthor: String
    var bookCoverUrl: String?
    var category: String? = nil

    var isFavorite: Bool { favorite ?? false }

    enum CodingKeys: String, CodingKey {
        case id, text, body, page, favorite, note, commentary, bookId, bookTitle, bookAuthor, bookCoverUrl, category
    }

    init(id: String, text: String, page: Int?, favorite: Bool?, note: String? = nil, bookId: String, bookTitle: String, bookAuthor: String, bookCoverUrl: String?) {
        self.id = id
        self.text = text
        self.page = page
        self.favorite = favorite
        self.note = note
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.bookCoverUrl = bookCoverUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .body) ?? c.decodeIfPresent(String.self, forKey: .text) ?? ""
        page = try c.decodeIfPresent(Int.self, forKey: .page)
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite)
        note = try c.decodeIfPresent(String.self, forKey: .commentary) ?? c.decodeIfPresent(String.self, forKey: .note)
        bookId = try c.decodeIfPresent(String.self, forKey: .bookId) ?? ""
        bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
        bookAuthor = try c.decodeIfPresent(String.self, forKey: .bookAuthor) ?? ""
        bookCoverUrl = try c.decodeIfPresent(String.self, forKey: .bookCoverUrl)
        category = try c.decodeIfPresent(String.self, forKey: .category)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(page, forKey: .page)
        try c.encodeIfPresent(favorite, forKey: .favorite)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(bookId, forKey: .bookId)
        try c.encode(bookTitle, forKey: .bookTitle)
        try c.encode(bookAuthor, forKey: .bookAuthor)
        try c.encodeIfPresent(bookCoverUrl, forKey: .bookCoverUrl)
    }
}

// MARK: - Cross-file shims (the store helpers above are file-private; the
// quotes widget lives in ReadendarQuotesWidget.swift and reads through these).

func widgetSharedString(_ key: String) -> String? { shared(key) }

// MARK: - Interactive complete/uncomplete (iOS 17 AppIntent)

/// Ticks an event off (or back on) straight from a widget row. WidgetKit runs
/// `perform()` in-process and reloads the timeline afterwards, so the row
/// re-renders with the fresh status without opening the app.
@available(iOS 17.0, *)
struct ToggleEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle reading event completion"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Event ID") var eventID: String
    @Parameter(title: "Complete") var complete: Bool

    init() {}
    init(eventID: String, complete: Bool) {
        self.eventID = eventID
        self.complete = complete
    }

    func perform() async throws -> some IntentResult {
        // Optimistically flip the cached status and return IMMEDIATELY so WidgetKit
        // reloads the timeline right away and the row updates instantly — matching
        // Android. Awaiting the network here would delay the reload until the
        // round-trip finished (the "sometimes lags" symptom), because WidgetKit
        // only re-renders once perform() returns.
        WidgetAPI.setCachedStatus(eventID: eventID, completed: complete)
        let eventID = self.eventID
        let complete = self.complete
        // Fire-and-forget the write. If it fails we revert the cache and reload so
        // the row can't stick in a false state. In the rare case the extension is
        // suspended before this finishes, the missed toggle self-heals on the next
        // syncWidget()/summary refresh (the server summary is authoritative).
        Task.detached(priority: .userInitiated) {
            let ok = await WidgetAPI.toggleComplete(eventID: eventID, complete: complete)
            if !ok {
                WidgetAPI.setCachedStatus(eventID: eventID, completed: !complete)
                WidgetCenter.shared.reloadTimelines(ofKind: "ReadendarWidget")
            }
        }
        return .result()
    }
}

// MARK: - Timeline

struct WidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
    var state: WidgetDataState = .ok
    /// Cover bytes keyed by URL, preloaded in the provider — WidgetKit can't
    /// load remote images inside the view, so rows decode UIImage from these.
    var covers: [String: Data] = [:]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), summary: .empty, state: .ok)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let (s, state) = WidgetAPI.cachedSummary()
        let covers = WidgetAPI.cachedCovers(for: s)
        completion(WidgetEntry(date: Date(), summary: s, state: state, covers: covers))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let (s, state) = await WidgetAPI.loadSummary()
            let covers = await WidgetAPI.preloadCovers(for: s)
            let now = Date()
            let entry = WidgetEntry(date: now, summary: s, state: state, covers: covers)
            let regular = Calendar.current.date(byAdding: .minute, value: 30, to: now)
                ?? now.addingTimeInterval(1800)
            var next = regular
            for e in s.events.prefix(4) {
                if let d = eventInstant(e), d > now, d < next { next = d }
            }
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Views

struct ReadendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallView(summary: entry.summary, state: entry.state)
            case .accessoryRectangular, .accessoryCircular, .accessoryInline:
                AccessoryView(summary: entry.summary, state: entry.state)
            default: MediumView(summary: entry.summary, state: entry.state, covers: entry.covers)
            }
        }
        // Explicit light/dark override from the app's in-app theme choice
        // (wdg_theme). "system"/absent leaves WidgetKit's default
        // system-adaptive behavior (Color(.systemBackground) etc.) untouched.
        .modifier(PreferredColorSchemeModifier(scheme: preferredWidgetScheme()))
    }
}

private func preferredWidgetScheme() -> ColorScheme? {
    switch shared(Keys.theme) {
    case "light": return .light
    case "dark": return .dark
    default: return nil
    }
}

/// `.preferredColorScheme(_:)` is available on widget-hosted SwiftUI views
/// since iOS 14 (WidgetKit renders entry views through the normal SwiftUI
/// view tree, and this modifier — unlike some UIKit-era APIs — works there).
/// Wrapped in its own modifier so the `nil` ("system") case cleanly no-ops
/// via `Optional` conditional application instead of branching the whole view.
private struct PreferredColorSchemeModifier: ViewModifier {
    let scheme: ColorScheme?
    func body(content: Content) -> some View {
        if let scheme {
            content.preferredColorScheme(scheme)
        } else {
            content
        }
    }
}

struct WidgetAppPalette {
    let background: Color
    let backgroundStops: [Color]
    let backgroundKind: String
    let surface: Color
    let surface2: Color
    let primary: Color
    let secondary: Color
    let line: Color
    let lineStrong: Color
    let accent: Color
    let accent2: Color
    let onAccent: Color
    let controlRadius: Double
    let cardRadius: Double
    let borderWidth: Double

    private struct Values {
        let background: [UInt32]
        let backgroundKind: String
        let surface: UInt32
        let surface2: UInt32
        let primary: UInt32
        let secondary: UInt32
        let line: UInt32
        let lineStrong: UInt32
        let accent: UInt32
        let accent2: UInt32
        let onAccent: UInt32
        let controlRadius: Double
        let cardRadius: Double
        let borderWidth: Double
    }

    static func current(_ scheme: ColorScheme) -> WidgetAppPalette {
        let dark = scheme == .dark
        let id = widgetSharedString("wdg_app_theme") ?? "original"
        // GENERATED_WIDGET_THEME_VALUES_START
        let values: Values = switch (id, dark) {
        case ("original", false): Values(background: [0xFAF5EF], backgroundKind: "solid", surface: 0xFFFFFF, surface2: 0xF7F7F5, primary: 0x0F1014, secondary: 0x5E5E5B, line: 0xE5E5E0, lineStrong: 0xC9C9C2, accent: 0x7479D6, accent2: 0x2A8F7D, onAccent: 0xFFFFFF, controlRadius: 8, cardRadius: 12, borderWidth: 1)
        case ("original", true): Values(background: [0x0E1018], backgroundKind: "solid", surface: 0x161A26, surface2: 0x1F2433, primary: 0xF2F2F5, secondary: 0x808290, line: 0xF2F2F5, lineStrong: 0xF2F2F5, accent: 0xA8ADDD, accent2: 0x64BCAC, onAccent: 0x0F1014, controlRadius: 8, cardRadius: 12, borderWidth: 1)
        case ("jade", false): Values(background: [0xF1F7F3, 0xDDEDE5, 0xF7EBCF], backgroundKind: "radial", surface: 0xFCFDFC, surface2: 0xDDECE4, primary: 0x11261D, secondary: 0x577065, line: 0xC4D9CE, lineStrong: 0x8FAD9E, accent: 0x12614A, accent2: 0xA06A1B, onAccent: 0xFFFFFF, controlRadius: 14, cardRadius: 20, borderWidth: 1)
        case ("jade", true): Values(background: [0x12382B, 0x071410, 0x2A2314], backgroundKind: "radial", surface: 0x0E211A, surface2: 0x173328, primary: 0xEEF8F2, secondary: 0x839F91, line: 0x29483B, lineStrong: 0x3F6754, accent: 0x8DD9B7, accent2: 0xE2B865, onAccent: 0x0B2418, controlRadius: 14, cardRadius: 20, borderWidth: 1)
        case ("celestial", false): Values(background: [0xF3F4FC, 0xE2E8FA, 0xF5E9CE], backgroundKind: "radial", surface: 0xFCFCFF, surface2: 0xE4E8F8, primary: 0x111A3B, secondary: 0x5F6988, line: 0xC9CFE6, lineStrong: 0x939DC4, accent: 0x263E91, accent2: 0x9C6A19, onAccent: 0xFFFFFF, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("celestial", true): Values(background: [0x162758, 0x070B1C, 0x2A1F36], backgroundKind: "radial", surface: 0x10162C, surface2: 0x192344, primary: 0xF3F4FF, secondary: 0x8C94B5, line: 0x2D385C, lineStrong: 0x46537B, accent: 0xE5C276, accent2: 0x7EA6FF, onAccent: 0x241A06, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("ocean", false): Values(background: [0xEDF6F8, 0xDDECF5], backgroundKind: "linear", surface: 0xFBFEFF, surface2: 0xDDEDF1, primary: 0x10242A, secondary: 0x5B747B, line: 0xC4DCE1, lineStrong: 0x9EC3CC, accent: 0x1F7666, accent2: 0x5A5FBC, onAccent: 0xFFFFFF, controlRadius: 12, cardRadius: 20, borderWidth: 1)
        case ("ocean", true): Values(background: [0x081419, 0x102938], backgroundKind: "linear", surface: 0x102128, surface2: 0x17313A, primary: 0xEAF5F7, secondary: 0x7F9AA1, line: 0x27444D, lineStrong: 0x3A5D67, accent: 0x64BCAC, accent2: 0xA8ADDD, onAccent: 0x081419, controlRadius: 12, cardRadius: 20, borderWidth: 1)
        case ("noir", false): Values(background: [0xF1F1EE], backgroundKind: "solid", surface: 0xFFFFFF, surface2: 0xE4E4E0, primary: 0x0A0A0A, secondary: 0x626262, line: 0xC7C7C2, lineStrong: 0x18181A, accent: 0x18181A, accent2: 0x5E5E5B, onAccent: 0xFFFFFF, controlRadius: 4, cardRadius: 4, borderWidth: 1.5)
        case ("noir", true): Values(background: [0x050506], backgroundKind: "solid", surface: 0x121214, surface2: 0x1D1D20, primary: 0xF7F7F5, secondary: 0x92928D, line: 0x343438, lineStrong: 0xEFEFEC, accent: 0xF2F2F2, accent2: 0xA3A39C, onAccent: 0x0A0A0A, controlRadius: 4, cardRadius: 4, borderWidth: 1.5)
        case ("sapphire", false): Values(background: [0xF0F4FF, 0xDCE8FF, 0xFFE8DE], backgroundKind: "linear", surface: 0xFCFDFF, surface2: 0xDFE7FB, primary: 0x111B3D, secondary: 0x61719D, line: 0xC8D3EF, lineStrong: 0x8FA3D8, accent: 0x2454C7, accent2: 0xC4512C, onAccent: 0xFFFFFF, controlRadius: 14, cardRadius: 20, borderWidth: 1)
        case ("sapphire", true): Values(background: [0x102B62, 0x070C1B, 0x3B1714], backgroundKind: "radial", surface: 0x10182D, surface2: 0x192643, primary: 0xF4F7FF, secondary: 0x8999C3, line: 0x2B3A60, lineStrong: 0x435A8D, accent: 0x8CB4FF, accent2: 0xFF8D68, onAccent: 0x0A1734, controlRadius: 14, cardRadius: 20, borderWidth: 1)
        case ("velvet", false): Values(background: [0xF8F1F5, 0xF1DDE8, 0xF6E8D0], backgroundKind: "radial", surface: 0xFFFBFD, surface2: 0xF0DEE8, primary: 0x2C1321, secondary: 0x7B5B6D, line: 0xE1C6D4, lineStrong: 0xC49BAD, accent: 0x7B244D, accent2: 0x9C672D, onAccent: 0xFFFFFF, controlRadius: 16, cardRadius: 22, borderWidth: 1)
        case ("velvet", true): Values(background: [0x49152F, 0x160911, 0x2B1428], backgroundKind: "radial", surface: 0x25101B, surface2: 0x381829, primary: 0xFFF0F7, secondary: 0xA98296, line: 0x53243C, lineStrong: 0x773454, accent: 0xE8A6C5, accent2: 0xF0C77F, onAccent: 0x321020, controlRadius: 16, cardRadius: 22, borderWidth: 1)
        case ("aurora", false): Values(background: [0xF3F0FF, 0xE5F8F7, 0xE9DFFF], backgroundKind: "linear", surface: 0xFCFBFF, surface2: 0xE8E2FF, primary: 0x1E1738, secondary: 0x71658E, line: 0xD2C8F3, lineStrong: 0xB2A4E2, accent: 0x6346C7, accent2: 0x168B91, onAccent: 0xFFFFFF, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("aurora", true): Values(background: [0x0C0B1D, 0x162F3C, 0x2B1643], backgroundKind: "linear", surface: 0x15142B, surface2: 0x222044, primary: 0xF2F0FF, secondary: 0x938DBA, line: 0x39365F, lineStrong: 0x555184, accent: 0xA995FF, accent2: 0x62D5D1, onAccent: 0x1E1738, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("arcade", false): Values(background: [0xF4FFD6, 0xFFE0F2], backgroundKind: "linear", surface: 0xFFFFFF, surface2: 0xE5FF7A, primary: 0x11110E, secondary: 0x5A5C3D, line: 0xB7CC4B, lineStrong: 0x748300, accent: 0x4B008F, accent2: 0xB80065, onAccent: 0xFFFFFF, controlRadius: 0, cardRadius: 0, borderWidth: 2)
        case ("arcade", true): Values(background: [0x08080B, 0x260037], backgroundKind: "linear", surface: 0x111116, surface2: 0x1D1D23, primary: 0xF5FFE0, secondary: 0x909B80, line: 0x3A3A42, lineStrong: 0x60606B, accent: 0xC8FF00, accent2: 0xFF3BBA, onAccent: 0x101200, controlRadius: 0, cardRadius: 0, borderWidth: 2)
        case ("pop", false): Values(background: [0xFFF4B8, 0xFFD8E2, 0xCDEBFF], backgroundKind: "radial", surface: 0xFFFDF4, surface2: 0xBFE8FF, primary: 0x17143A, secondary: 0x5C5679, line: 0xD8A92E, lineStrong: 0x7B5C00, accent: 0x2447C6, accent2: 0xB72E47, onAccent: 0xFFFFFF, controlRadius: 24, cardRadius: 30, borderWidth: 1.5)
        case ("pop", true): Values(background: [0x3B285D, 0x211D3B, 0x17142B], backgroundKind: "radial", surface: 0x211D3B, surface2: 0x332B57, primary: 0xFFF6C7, secondary: 0xA79CC9, line: 0x48416A, lineStrong: 0x6C628F, accent: 0xFFD84D, accent2: 0xFF6B78, onAccent: 0x241800, controlRadius: 24, cardRadius: 30, borderWidth: 1.5)
        case ("ethereal", false): Values(background: [0xF4F1FF, 0xDDF8FF, 0xFFE7F4, 0xFFF2CD], backgroundKind: "radial", surface: 0xFDFCFF, surface2: 0xEAE4FF, primary: 0x18122F, secondary: 0x70668D, line: 0xD8CEF2, lineStrong: 0xAA9ACF, accent: 0x5A3FC0, accent2: 0x9A650E, onAccent: 0xFFFFFF, controlRadius: 18, cardRadius: 24, borderWidth: 1)
        case ("ethereal", true): Values(background: [0x171044, 0x071A2E, 0x2C0F33, 0x070815], backgroundKind: "radial", surface: 0x111326, surface2: 0x1C203A, primary: 0xF8F5FF, secondary: 0x9B90BA, line: 0x343956, lineStrong: 0x555E86, accent: 0xB6A2FF, accent2: 0xF2CA72, onAccent: 0x1A1238, controlRadius: 18, cardRadius: 24, borderWidth: 1)
        case ("stormbound", false): Values(background: [0xF3EFEA, 0xE5DDD8, 0xE7E1F5], backgroundKind: "linear", surface: 0xFFFCF8, surface2: 0xE4DDD5, primary: 0x1D1718, secondary: 0x6E6062, line: 0xCFC3BB, lineStrong: 0x9D8B83, accent: 0x6D1A2A, accent2: 0x5C47B7, onAccent: 0xFFFFFF, controlRadius: 8, cardRadius: 14, borderWidth: 1)
        case ("stormbound", true): Values(background: [0x1B1F2B, 0x090A0D, 0x26101B], backgroundKind: "radial", surface: 0x15171C, surface2: 0x242832, primary: 0xF5F2F3, secondary: 0x9C9195, line: 0x383B44, lineStrong: 0x5A5E69, accent: 0xC5B6FF, accent2: 0xE06672, onAccent: 0x151020, controlRadius: 8, cardRadius: 14, borderWidth: 1)
        case ("evercourt", false): Values(background: [0xF6F2F7, 0xE4E8F7, 0xF4E8D2, 0xECE0E8], backgroundKind: "radial", surface: 0xFFFCFF, surface2: 0xE9E1EF, primary: 0x21182C, secondary: 0x74667F, line: 0xD3C6DA, lineStrong: 0xA794B2, accent: 0x463087, accent2: 0x8B5812, onAccent: 0xFFFFFF, controlRadius: 16, cardRadius: 22, borderWidth: 1)
        case ("evercourt", true): Values(background: [0x242358, 0x080B19, 0x321A2D, 0x0B1720], backgroundKind: "radial", surface: 0x14182A, surface2: 0x242A46, primary: 0xF8F4FF, secondary: 0x9E94B2, line: 0x373E5E, lineStrong: 0x596283, accent: 0xE5C76B, accent2: 0x9D86FF, onAccent: 0x221A08, controlRadius: 16, cardRadius: 22, borderWidth: 1)
        case ("neon_moon", false): Values(background: [0xF1F3F8, 0xE5F4F7, 0xF5E5EF], backgroundKind: "linear", surface: 0xFCFDFF, surface2: 0xE0E6F1, primary: 0x171A2A, secondary: 0x687088, line: 0xC6CEDD, lineStrong: 0x929CB2, accent: 0x8A1954, accent2: 0x08788D, onAccent: 0xFFFFFF, controlRadius: 14, cardRadius: 18, borderWidth: 1)
        case ("neon_moon", true): Values(background: [0x101F3D, 0x070914, 0x35102B, 0x081A22], backgroundKind: "radial", surface: 0x11182A, surface2: 0x1A2942, primary: 0xF4F7FF, secondary: 0x8998B5, line: 0x2A3B58, lineStrong: 0x425E82, accent: 0x44D9F2, accent2: 0xFF5BA6, onAccent: 0x061A20, controlRadius: 14, cardRadius: 18, borderWidth: 1)
        case ("trail", false): Values(background: [0xF5F1E8, 0xE8E0D2, 0xE4EFF0, 0xF5E3CD], backgroundKind: "linear", surface: 0xFFFDF8, surface2: 0xE8E0D2, primary: 0x261D15, secondary: 0x79695A, line: 0xD8CABA, lineStrong: 0xAA9580, accent: 0x7B3F18, accent2: 0x2D6A75, onAccent: 0xFFFFFF, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("trail", true): Values(background: [0x372215, 0x100C09, 0x10292B, 0x20150D], backgroundKind: "radial", surface: 0x1F1711, surface2: 0x35271D, primary: 0xFBF5EC, secondary: 0xA89582, line: 0x4B382A, lineStrong: 0x74543D, accent: 0xE9A65D, accent2: 0x72CAD0, onAccent: 0x2A1404, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("serpents", false): Values(background: [0xF2F3ED, 0xE3E8DB, 0xF4E9CF, 0xE0E8E5], backgroundKind: "radial", surface: 0xFDFEF9, surface2: 0xE1E5D7, primary: 0x18201B, secondary: 0x687469, line: 0xC7D0C2, lineStrong: 0x91A18F, accent: 0x175D4D, accent2: 0x8B6418, onAccent: 0xFFFFFF, controlRadius: 20, cardRadius: 24, borderWidth: 1)
        case ("serpents", true): Values(background: [0x143629, 0x050A08, 0x2B240D, 0x071B17], backgroundKind: "radial", surface: 0x0E1813, surface2: 0x192A21, primary: 0xF1F8F3, secondary: 0x879A8D, line: 0x2B4135, lineStrong: 0x476352, accent: 0xD6BE6B, accent2: 0x5ED6A2, onAccent: 0x201A05, controlRadius: 20, cardRadius: 24, borderWidth: 1)
        case ("thorn_crown", false): Values(background: [0xF3F2E9, 0xE5E9DA, 0xF0E4DE], backgroundKind: "linear", surface: 0xFFFEF8, surface2: 0xE2E4D3, primary: 0x1C2419, secondary: 0x697363, line: 0xC9CDBA, lineStrong: 0x989E84, accent: 0x3E5B2D, accent2: 0x7D2D46, onAccent: 0xFFFFFF, controlRadius: 10, cardRadius: 16, borderWidth: 1)
        case ("thorn_crown", true): Values(background: [0x1A3521, 0x08110B, 0x2A101A], backgroundKind: "radial", surface: 0x121E15, surface2: 0x203024, primary: 0xF3F6EA, secondary: 0x909D84, line: 0x334438, lineStrong: 0x506352, accent: 0xC5D98F, accent2: 0xE586A0, onAccent: 0x14200D, controlRadius: 10, cardRadius: 16, borderWidth: 1)
        case ("iridescent", false): Values(background: [0xF0F3F4, 0xE4F5F4, 0xF7E6F2, 0xEAE4F8], backgroundKind: "linear", surface: 0xFCFEFF, surface2: 0xDFE5E8, primary: 0x15191D, secondary: 0x657078, line: 0xC6CFD4, lineStrong: 0x929FA7, accent: 0x45318D, accent2: 0x087C83, onAccent: 0xFFFFFF, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("iridescent", true): Values(background: [0x050609, 0x102A2D, 0x301127, 0x17112F, 0x050609], backgroundKind: "linear", surface: 0x101216, surface2: 0x1B1F26, primary: 0xF5F7FA, secondary: 0x909BA6, line: 0x303640, lineStrong: 0x4D5663, accent: 0x70E6E0, accent2: 0xFF71C8, onAccent: 0x071A1C, controlRadius: 12, cardRadius: 18, borderWidth: 1)
        case ("last_light", false): Values(background: [0xFFFFFF, 0xE6EEF1, 0xF5E8DE], backgroundKind: "radial", surface: 0xFFFFFF, surface2: 0xDCE5E8, primary: 0x142027, secondary: 0x637681, line: 0xC2D0D6, lineStrong: 0x8EA5AF, accent: 0x1E4D73, accent2: 0x9A421D, onAccent: 0xFFFFFF, controlRadius: 6, cardRadius: 12, borderWidth: 1)
        case ("last_light", true): Values(background: [0x172939, 0x05080C, 0x35120E], backgroundKind: "radial", surface: 0x10161C, surface2: 0x1B252E, primary: 0xF3F7F9, secondary: 0x8B9DA6, line: 0x2B3942, lineStrong: 0x465C67, accent: 0xFF735E, accent2: 0xF4BF55, onAccent: 0x240702, controlRadius: 6, cardRadius: 12, borderWidth: 1)
        default: Values(background: [0xFAF5EF], backgroundKind: "solid", surface: 0xFFFFFF, surface2: 0xF7F7F5, primary: 0x0F1014, secondary: 0x5E5E5B, line: 0xE5E5E0, lineStrong: 0xC9C9C2, accent: 0x7479D6, accent2: 0x2A8F7D, onAccent: 0xFFFFFF, controlRadius: 8, cardRadius: 12, borderWidth: 1)
        }
// GENERATED_WIDGET_THEME_VALUES_END
        func color(_ rgb: UInt32) -> Color {
            Color(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
        }
        return WidgetAppPalette(
            background: color(values.background.first!),
            backgroundStops: values.background.map(color),
            backgroundKind: values.backgroundKind,
            surface: color(values.surface),
            surface2: color(values.surface2),
            primary: color(values.primary),
            secondary: color(values.secondary),
            line: color(values.line),
            lineStrong: color(values.lineStrong),
            accent: color(values.accent),
            accent2: color(values.accent2),
            onAccent: color(values.onAccent),
            controlRadius: values.controlRadius,
            cardRadius: values.cardRadius,
            borderWidth: values.borderWidth
        )
    }
}

@ViewBuilder func widgetCanvas(_ scheme: ColorScheme) -> some View {
    let palette = WidgetAppPalette.current(scheme)
    ZStack {
        if palette.backgroundKind == "radial" {
            RadialGradient(
                colors: palette.backgroundStops,
                center: UnitPoint(x: 0.45, y: 0.25),
                startRadius: 0,
                endRadius: 420
            )
        } else if palette.backgroundKind == "linear" {
            LinearGradient(
                colors: palette.backgroundStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            palette.background
        }
        if shared(Keys.appTheme) == "ethereal" {
            EtherealWidgetArtwork(accent: palette.accent, gold: palette.accent2)
        } else if let identity = shared(Keys.appTheme), [
            "stormbound", "evercourt", "neon_moon", "trail", "serpents",
            "thorn_crown", "iridescent", "last_light",
        ].contains(identity) {
            PremiumWidgetArtwork(
                identity: identity,
                primary: palette.accent,
                secondary: palette.accent2
            )
        }
    }
}

private struct PremiumWidgetArtwork: View {
    let identity: String
    let primary: Color
    let secondary: Color

    var body: some View {
        Canvas { context, size in
            if identity == "trail" {
                let count = 6
                let radius: CGFloat = 3.6
                for index in 0..<count {
                    let t = CGFloat(index) / CGFloat(count - 1)
                    let center = CGPoint(
                        x: size.width * (0.08 + t * 0.84),
                        y: size.height * (0.82 - t * 0.62 + CGFloat(sin(Double(t) * .pi * 3)) * 0.05)
                    )
                    let color = (index.isMultiple(of: 2) ? primary : secondary).opacity(0.38)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius * 0.25,
                            width: radius * 2,
                            height: radius * 1.55
                        )),
                        with: .color(color)
                    )
                    for toe in 0..<4 {
                        let toeX = center.x + (CGFloat(toe) - 1.5) * radius * 0.72
                        let toeY = center.y - radius * (0.68 + ((toe == 1 || toe == 2) ? 0.18 : 0))
                        let toeRadius = radius * 0.3
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: toeX - toeRadius,
                                y: toeY - toeRadius,
                                width: toeRadius * 2,
                                height: toeRadius * 2
                            )),
                            with: .color(color)
                        )
                        var claw = Path()
                        claw.move(to: CGPoint(x: toeX, y: toeY - toeRadius * 1.2))
                        claw.addLine(to: CGPoint(x: toeX, y: toeY - toeRadius * 2.0))
                        context.stroke(claw, with: .color(color), lineWidth: 0.65)
                    }
                }
                return
            }
            if identity == "evercourt" {
                let summit = CGPoint(x: size.width * 0.5, y: size.height * 0.4)
                let stars = [
                    CGPoint(x: size.width * 0.5, y: size.height * 0.23),
                    CGPoint(x: size.width * 0.39, y: size.height * 0.31),
                    CGPoint(x: size.width * 0.61, y: size.height * 0.31),
                ]

                var mountain = Path()
                mountain.move(to: CGPoint(x: -size.width * 0.06, y: size.height * 0.96))
                mountain.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.7))
                mountain.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.8))
                mountain.addLine(to: summit)
                mountain.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.7))
                mountain.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.59))
                mountain.addLine(to: CGPoint(x: size.width * 1.06, y: size.height * 0.9))
                mountain.addLine(to: CGPoint(x: size.width * 1.06, y: size.height * 1.06))
                mountain.addLine(to: CGPoint(x: -size.width * 0.06, y: size.height * 1.06))
                mountain.closeSubpath()
                context.fill(
                    mountain,
                    with: .linearGradient(
                        Gradient(colors: [primary.opacity(0.2), secondary.opacity(0.07)]),
                        startPoint: summit,
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)
                    )
                )

                var ridge = Path()
                ridge.move(to: CGPoint(x: -size.width * 0.06, y: size.height * 0.96))
                ridge.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.7))
                ridge.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.8))
                ridge.addLine(to: summit)
                ridge.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.7))
                ridge.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.59))
                ridge.addLine(to: CGPoint(x: size.width * 1.06, y: size.height * 0.9))
                context.stroke(
                    ridge,
                    with: .color(primary.opacity(0.42)),
                    style: StrokeStyle(lineWidth: 1, lineJoin: .bevel)
                )

                for (index, center) in stars.enumerated() {
                    let radius = size.width * (index == 0 ? 0.028 : 0.023)
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: center.x, y: center.y - radius * 1.8))
                    vertical.addLine(to: CGPoint(x: center.x + radius * 0.34, y: center.y))
                    vertical.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.8))
                    vertical.addLine(to: CGPoint(x: center.x - radius * 0.34, y: center.y))
                    vertical.closeSubpath()
                    context.fill(vertical, with: .color((index == 0 ? secondary : primary).opacity(0.76)))

                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: center.x - radius, y: center.y))
                    horizontal.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.26))
                    horizontal.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    horizontal.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.26))
                    horizontal.closeSubpath()
                    context.fill(horizontal, with: .color((index == 0 ? secondary : primary).opacity(0.76)))
                }
                return
            }
            let points: [CGPoint] = switch identity {
            case "stormbound": [
                CGPoint(x: 0.64, y: -0.04), CGPoint(x: 0.59, y: 0.18),
                CGPoint(x: 0.62, y: 0.21), CGPoint(x: 0.53, y: 0.42),
                CGPoint(x: 0.56, y: 0.45), CGPoint(x: 0.44, y: 0.72),
                CGPoint(x: 0.47, y: 0.75), CGPoint(x: 0.34, y: 1.02),
            ]
            case "neon_moon": [
                CGPoint(x: 0.18, y: 0.82), CGPoint(x: 0.18, y: 0.42),
                CGPoint(x: 0.34, y: 0.18), CGPoint(x: 0.5, y: 0.42),
                CGPoint(x: 0.5, y: 0.82), CGPoint(x: 0.78, y: 0.82),
            ]
            case "serpents": (0..<18).map { index in
                let x = Double(index) / 17
                return CGPoint(x: x, y: 0.5 + sin(Double(index) * 0.95) * 0.22)
            }
            case "thorn_crown": (0..<10).map { index in
                let x = Double(index) / 9
                return CGPoint(x: x, y: 0.62 + sin(Double(index) * 0.9) * 0.16)
            }
            case "iridescent": [
                CGPoint(x: 0.12, y: 1), CGPoint(x: 0.42, y: 0),
                CGPoint(x: 0.38, y: 1), CGPoint(x: 0.68, y: 0),
                CGPoint(x: 0.64, y: 1), CGPoint(x: 0.94, y: 0),
            ]
            case "last_light": [
                CGPoint(x: 0.08, y: 0.76), CGPoint(x: 0.24, y: 0.76),
                CGPoint(x: 0.3, y: 0.56), CGPoint(x: 0.38, y: 0.9),
                CGPoint(x: 0.46, y: 0.76), CGPoint(x: 0.76, y: 0.22),
            ]
            default: []
            }
            guard !points.isEmpty else { return }
            var path = Path()
            path.move(to: CGPoint(x: points[0].x * size.width, y: points[0].y * size.height))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [primary.opacity(0.22), secondary.opacity(0.34)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                lineWidth: identity == "iridescent" ? 1.5 : 0.9
            )
            for (index, point) in points.enumerated() where index.isMultiple(of: 2) {
                let p = CGPoint(x: point.x * size.width, y: point.y * size.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - 1.7, y: p.y - 1.7, width: 3.4, height: 3.4)),
                    with: .color((index.isMultiple(of: 4) ? primary : secondary).opacity(0.42))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EtherealWidgetArtwork: View {
    let accent: Color
    let gold: Color

    var body: some View {
        Canvas { context, size in
            let points = [
                CGPoint(x: size.width * 0.08, y: size.height * 0.22),
                CGPoint(x: size.width * 0.24, y: size.height * 0.11),
                CGPoint(x: size.width * 0.38, y: size.height * 0.28),
                CGPoint(x: size.width * 0.62, y: size.height * 0.14),
                CGPoint(x: size.width * 0.84, y: size.height * 0.34),
                CGPoint(x: size.width * 0.68, y: size.height * 0.78),
                CGPoint(x: size.width * 0.36, y: size.height * 0.72),
                CGPoint(x: size.width * 0.12, y: size.height * 0.86),
            ]
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(path, with: .color(accent.opacity(0.16)), lineWidth: 0.8)
            for (index, point) in points.enumerated() {
                let radius = index.isMultiple(of: 3) ? 2.1 : 1.2
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - radius,
                        y: point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color((index.isMultiple(of: 3) ? gold : accent).opacity(0.38))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// The deep-link scheme for per-element taps, read from the shared App Group
/// (wdg_scheme) with the same fallback the Android side uses.
private func deepLinkScheme() -> String {
    let s = shared(Keys.scheme) ?? ""
    return s.isEmpty ? "readendar" : s
}

private func deepLinkURL(_ path: String) -> URL? {
    URL(string: "\(deepLinkScheme())://\(path)")
}

// Event-list medium/large: fixed wordmark + reading-strip header, then a
// family-sized event prefix. Home Screen widgets cannot scroll; the OS owns
// the swipe, so a scroll view here becomes a giant prohibited placeholder.
struct MediumView: View {
    let summary: WidgetSummary
    let state: WidgetDataState
    let covers: [String: Data]

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var family

    /// Home Screen widgets cannot scroll (the OS owns the swipe). A vertical
    /// scroll view here is replaced by a giant prohibited placeholder. Show a
    /// family-sized prefix and send overflow to the calendar, like the in-app
    /// preview. Android still uses a real ListView.
    ///
    /// Caps are the rows that fit under the wordmark (and optional cover strip)
    /// with the see-more footer still visible. Six large rows overflowed both.
    private var visibleEventLimit: Int { family == .systemLarge ? 4 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header stays outside the list so the logo + cover strip never clip.
            WidgetHeader {
                // Strip only with 2+ books — a lone book here is just noise.
                if summary.readingBooks.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(summary.readingBooks.prefix(4)) { b in
                            if let url = deepLinkURL("book/\(b.id)") {
                                Link(destination: url) {
                                    CoverThumb(title: b.title, coverUrl: b.coverUrl, covers: covers, width: 22, height: 31)
                                }
                            }
                        }
                    }
                }
            }
            .layoutPriority(2)
            .fixedSize(horizontal: false, vertical: true)

            if (state == .error || state == .stale) && summary.events.isEmpty && summary.readingBooks.isEmpty {
                ErrorState()
                Spacer(minLength: 0)
            } else if summary.events.isEmpty {
                EmptyState()
                Spacer(minLength: 0)
            } else {
                let visible = Array(summary.events.prefix(visibleEventLimit))
                let clipped = summary.events.count > visible.count || (summary.hasMore ?? false)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visible) { e in
                        EventRow(event: e, covers: covers)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                if clipped {
                    MoreFooter()
                        .layoutPriority(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(WidgetAppPalette.current(scheme).primary)
        .containerBackground(for: .widget) { widgetCanvas(scheme) }
    }
}

/// "See more in calendar" footer, deep-linking the calendar tab.
struct MoreFooter: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if let url = deepLinkURL("calendar") {
            Link(destination: url) {
                Text(loc("see_more"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(WidgetAppPalette.current(scheme).accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }
}

/// One event row, matching the app's EventCardCompact: cover + title/author on
/// the left, event type (icon + label) with a time/relative-day subtitle right.
struct EventRow: View {
    let event: WEvent
    let covers: [String: Data]
    @Environment(\.colorScheme) private var scheme

    private var hasBook: Bool { !(event.bookTitle ?? "").isEmpty }

    var body: some View {
        let typeColor = eventColor(event.type, scheme)
        // Line 1: book title (else the event's own title / type label).
        let leftTitle = hasBook ? event.bookTitle! : (event.title?.isEmpty == false ? event.title! : typeLabel(event.type))
        // Line 2: the event's progress/milestone (e.g. "Página 143"), else the
        // author. Never repeats line 1 (when no book, line 1 IS the milestone).
        let secondary: String? = {
            if let t = event.title, !t.isEmpty, t != leftTitle, t != typeLabel(event.type) { return t }
            if hasBook, let a = event.bookAuthor, !a.isEmpty { return a }
            return nil
        }()
        let sub = [relativeDay(event.dateLocal), event.timeLocal].compactMap { $0 }.joined(separator: " · ")
        let done = event.isCompleted

        HStack(spacing: 8) {
            completeToggle
            content(leftTitle: leftTitle, secondary: secondary, sub: sub, typeColor: typeColor, done: done)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: WidgetAppPalette.current(scheme).cardRadius)
                .fill(WidgetAppPalette.current(scheme).surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WidgetAppPalette.current(scheme).cardRadius)
                        .stroke(WidgetAppPalette.current(scheme).line,
                                lineWidth: WidgetAppPalette.current(scheme).borderWidth)
                )
        )
    }

    /// The check toggle (iOS 17 interactive AppIntent). Hidden for informational
    /// types that can't be completed. Kept as a sibling of the row Link (not
    /// nested) so the tap target stays independent of the event deep link.
    @ViewBuilder private var completeToggle: some View {
        if event.isCompletable, #available(iOS 17.0, *) {
            Button(intent: ToggleEventIntent(eventID: event.id, complete: !event.isCompleted)) {
                // 22pt glyph in a 36x36 tap area so a near-miss still completes
                // instead of opening the row Link.
                Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(event.isCompleted ? successColor : .secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 36)
        } else {
            // Keep the row aligned with the toggled rows.
            Color.clear.frame(width: 36, height: 36)
        }
    }

    /// Row content (cover + title/progress + type), a tap-target Link to the
    /// event detail. Completed rows are struck-through + dimmed.
    @ViewBuilder private func content(leftTitle: String, secondary: String?, sub: String, typeColor: Color, done: Bool) -> some View {
        let inner = HStack(spacing: 8) {
            if hasBook {
                CoverThumb(title: event.bookTitle!, coverUrl: event.bookCoverUrl ?? "", covers: covers, width: 30, height: 42)
                    .opacity(done ? 0.55 : 1)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(leftTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .strikethrough(done)
                    .foregroundColor(done ? .secondary : .primary)
                    .lineLimit(1)
                if let secondary { Text(secondary).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: eventSymbol(event.type)).font(.system(size: 11)).foregroundColor(typeColor)
                    Text(typeLabel(event.type)).font(.system(size: 11)).lineLimit(1)
                }
                Text(sub).font(.system(size: 11, weight: .semibold)).foregroundColor(typeColor).lineLimit(1)
            }
        }
        if let url = deepLinkURL("event/\(event.id)") {
            Link(destination: url) { inner }
        } else {
            inner
        }
    }
}

private let successColor = Color(red: 0x3E / 255, green: 0x9B / 255, blue: 0x57 / 255)

/// A book cover thumbnail: the preloaded image if available, else a periwinkle
/// chip with the title initial (mirrors the app's BookCover fallback).
struct CoverThumb: View {
    let title: String
    let coverUrl: String
    let covers: [String: Data]
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme

    init(
        title: String,
        coverUrl: String,
        covers: [String: Data],
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 4
    ) {
        self.title = title
        self.coverUrl = coverUrl
        self.covers = covers
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let data = covers[coverUrl], let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(WidgetAppPalette.current(scheme).accent.opacity(0.85))
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(size: height * 0.42, weight: .bold))
                        .foregroundColor(WidgetAppPalette.current(scheme).onAccent)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct SmallView: View {
    let summary: WidgetSummary
    let state: WidgetDataState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Android small: compact wordmark + day/title, vertically centered, no
        // chrome that needs more than ~155pt. Avoid Spacers that collapse or
        // push content out of the clip rect.
        VStack(alignment: .leading, spacing: 4) {
            BrandWordmark(size: 11, tracking: 0.9)
                .opacity(0.85)
                .layoutPriority(1)

            if (state == .error || state == .stale) && summary.events.isEmpty && summary.readingBooks.isEmpty {
                compactMessage(symbol: "wifi.slash", text: loc("updateFailed"))
            } else if let e = summary.events.first {
                let hasBookTitle = !(e.bookTitle ?? "").isEmpty
                let label = (e.title?.isEmpty == false) ? e.title! : typeLabel(e.type)
                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeDay(e.dateLocal))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(WidgetAppPalette.current(scheme).accent)
                    Text(hasBookTitle ? e.bookTitle! : label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    if let t = e.timeLocal {
                        Text(t)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(deepLinkURL("event/\(e.id)"))
            } else if let b = summary.readingBooks.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("reading"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(b.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    ProgressBar(pct: displayProgressPercent(b))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(deepLinkURL("book/\(b.id)"))
            } else {
                compactMessage(symbol: "calendar", text: loc("empty_events"))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(WidgetAppPalette.current(scheme).primary)
        .containerBackground(for: .widget) { widgetCanvas(scheme) }
    }

    private func compactMessage(symbol: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct AccessoryView: View {
    let summary: WidgetSummary
    let state: WidgetDataState
    var body: some View {
        if (state == .error || state == .stale) && summary.events.isEmpty && summary.readingBooks.isEmpty {
            Text(loc("updateFailed")).lineLimit(2)
        } else if let e = summary.events.first {
            Text("\(relativeDay(e.dateLocal)) · \(e.bookTitle ?? typeLabel(e.type))").lineLimit(2)
        } else if let b = summary.readingBooks.first {
            Text(b.title).lineLimit(2)
        } else {
            Text("Readendar")
        }
    }
}

struct ProgressBar: View {
    let pct: Int?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(WidgetAppPalette.current(scheme).accent)
                    .frame(width: geo.size.width * CGFloat(min(max(pct ?? 0, 0), 100)) / 100.0)
            }
        }
        .frame(height: 5)
    }
}

// The "READENDAR" wordmark (BrandWordmark) already renders above these states
// in MediumView/SmallView, so they only need the message itself.
struct EmptyState: View {
    var body: some View { StateMessage(symbol: "calendar", text: loc("empty_events")) }
}

/// Shown when the self-fetch failed AND there's no cached snapshot to fall
/// back to — distinct from EmptyState (which means "fetch worked, you just
/// have nothing to show"), so the user doesn't mistake a network failure for
/// "you have no books".
struct ErrorState: View {
    var body: some View { StateMessage(symbol: "wifi.slash", text: loc("updateFailed")) }
}

/// A centered SF-Symbol + message, so the empty/error states aren't a bare line
/// of text (mirrors the Android empty view + the in-app preview).
struct StateMessage: View {
    let symbol: String
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline).bold()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
    }
}

/// Small "READENDAR" wordmark rendered above the widget content in
/// MediumView/SmallView — the top-of-widget brand title (see AccessoryView,
/// which stays bare "Readendar" text since lock-screen accessories are too
/// small for a separate wordmark row).
struct BrandWordmark: View {
    var size: CGFloat = 15
    var tracking: CGFloat = 1.1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // One AttributedString so tracking is uniform across the whole word
        // (concatenating two Texts widened the D→E gap); "READ" tinted accent.
        Text(wordmark)
            .font(.system(size: size, weight: .bold))
    }

    private var wordmark: AttributedString {
        var s = AttributedString("READENDAR")
        s.tracking = tracking
        let palette = WidgetAppPalette.current(scheme)
        s.foregroundColor = palette.secondary
        if let r = s.range(of: "READ") { s[r].foregroundColor = palette.accent }
        return s
    }
}

/// Shared medium-widget header. Every home-screen widget uses this exact
/// wordmark/spacing seam and supplies only its trailing control.
private struct WidgetHeader<Trailing: View>: View {
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            BrandWordmark()
            Spacer(minLength: 8)
            trailing()
        }
    }
}

// MARK: - Localized chrome strings (native, keyed by wdg_locale)

private func loc(_ key: String) -> String {
    let locale = shared(Keys.locale) ?? Locale.preferredLanguages.first ?? "es"
    let l = String(locale.prefix(2))
    let table: [String: [String: String]] = [
        "reading":  ["es": "Leyendo"],
        "empty":    ["es": "Añade una lectura"],
        "empty_events": ["es": "No hay eventos próximos"],
        "updateFailed": ["es": "No se pudo actualizar"],
        "today":    ["es": "Hoy"],
        "tomorrow": ["es": "Mañana"],
        "see_more": ["es": "Ver más en el calendario"],
        "pages": ["es": "Páginas"],
        "percentage": ["es": "Porcentaje"],
        "chapter": ["es": "Capítulo"],
        "update_progress": ["es": "Actualizar progreso"],
        "save": ["es": "Guardar"],
        "saving": ["es": "Guardando…"],
        "updated": ["es": "Actualizado"],
        "cancel": ["es": "Cancelar"],
        "backspace": ["es": "Borrar"],
        "next_book": ["es": "Libro siguiente"],
        "go_library": ["es": "Ir a la biblioteca"],
        "retry": ["es": "Reintentar"],
        "events_widget_name": ["es": "Próximos eventos"],
        "progress_widget_name": ["es": "Progreso de lectura"],
        "progress_widget_description": ["es": "Actualiza página o capítulo con un toque."],
        // Control Center (iOS 18+) — mirrors Flutter shortcut titles.
        "control_new_quote": ["es": "Nueva anotación"],
        "control_new_quote_desc": ["es": "Captura una anotación en Readendar"],
        "control_log_progress": ["es": "Registrar progreso"],
        "control_log_progress_desc": ["es": "Actualiza el progreso de lectura"],
        "control_whats_next": ["es": "Qué toca leer"],
        "control_whats_next_desc": ["es": "Abre el calendario de lectura"],
    ]
    return table[key]?[l] ?? table[key]?["es"] ?? key
}

// Full event-type labels — mirror the app's eventType* ARB keys (event_icon.dart).
private func typeLabel(_ type: String) -> String {
    let l = String((shared(Keys.locale) ?? "es").prefix(2))
    let names: [String: [String: String]] = [
        "start":            ["es": "Inicio"],
        "finish":           ["es": "Fin"],
        "abandoned":        ["es": "Abandono"],
        "chapter_milestone":["es": "Hito de capítulo"],
        "page_milestone":   ["es": "Hito de página"],
        "deadline":         ["es": "Fecha límite"],
        "book_return":      ["es": "Devolución de libro"],
        "release":          ["es": "Lanzamiento"],
    ]
    return names[type]?[l] ?? names[type]?["es"] ?? type.capitalized
}

/// SF Symbol per event type — the closest match to the app's Lucide icons.
private func eventSymbol(_ type: String) -> String {
    switch type {
    case "start": return "play.fill"
    case "finish": return "checkmark.circle"
    case "abandoned": return "xmark"
    case "chapter_milestone": return "bookmark"
    case "page_milestone": return "doc.text"
    case "deadline": return "exclamationmark.circle"
    case "book_return": return "arrow.uturn.left"
    case "release": return "rocket"
    default: return "calendar"
    }
}

/// Event-type hue — a 1:1 port of EventType.color / _darkColor (event_icon.dart),
/// picking the light or dark variant from the row's effective color scheme.
private func eventColor(_ type: String, _ scheme: ColorScheme) -> Color {
    let dark = scheme == .dark
    let hex: String
    switch type {
    case "start": hex = dark ? "A8ADDD" : "5A5FBC"
    case "finish": hex = dark ? "82B373" : "487539"
    case "abandoned": hex = dark ? "D26669" : "8F2F35"
    case "chapter_milestone": hex = dark ? "64BCAC" : "2A8F7D"
    case "page_milestone": hex = dark ? "A8ADDD" : "7479D6"
    case "deadline": hex = dark ? "E5A848" : "B97D26"
    case "book_return": hex = dark ? "82B373" : "36572B"
    case "release": hex = dark ? "EBB35A" : "B97D26"
    default: hex = dark ? "A8ADDD" : "7479D6"
    }
    return Color(hex: hex)
}

private extension Color {
    /// "RRGGBB" hex → Color. Falls back to the periwinkle brand on a bad string.
    init(hex: String) {
        var v: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&v), hex.count == 6 else {
            self = Color(red: 0x74/255, green: 0x79/255, blue: 0xD6/255); return
        }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

// MARK: - Date helpers

private func parseDay(_ s: String) -> Date? {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
    return f.date(from: s)
}

private func eventInstant(_ e: WEvent) -> Date? {
    guard let day = parseDay(e.dateLocal) else { return nil }
    guard let t = e.timeLocal else { return day }
    let parts = t.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return day }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: e.tz ?? "UTC") ?? .current
    return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
}

private func relativeDay(_ dateLocal: String) -> String {
    guard let d = parseDay(dateLocal) else { return dateLocal }
    let cal = Calendar.current
    if cal.isDateInToday(d) { return loc("today") }
    if cal.isDateInTomorrow(d) { return loc("tomorrow") }
    let f = DateFormatter(); f.dateFormat = "d MMM"
    f.locale = Locale(identifier: shared(Keys.locale) ?? "es")
    return f.string(from: d)
}

// MARK: - Widget definition

struct ReadendarWidget: Widget {
    let kind = "ReadendarWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReadendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Text(loc("events_widget_name")))
        .description("Tus lecturas actuales y los próximos eventos.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        // Medium first: gallery default matches Android's medium/large footprint.
        // Small remains available; Large shows more event rows (Home Screen
        // widgets cannot scroll).
        if #available(iOSApplicationExtension 16.0, *) {
            return [.systemMedium, .systemLarge, .systemSmall, .accessoryRectangular, .accessoryCircular]
        }
        return [.systemMedium, .systemLarge, .systemSmall]
    }
}

// MARK: - Quick progress widget (iOS 17+)

private enum ProgressField: String, CaseIterable {
    case page
    case chapter

    var next: ProgressField {
        let fields = Self.allCases
        return fields[(fields.firstIndex(of: self)! + 1) % fields.count]
    }
}

private func progressFieldKey() -> String {
    "wdg_progress_field_\(shared(Keys.userId) ?? "anonymous")"
}

private func progressMutationKey() -> String {
    "wdg_progress_mutation_\(shared(Keys.userId) ?? "anonymous")"
}

private func progressEditingKey() -> String {
    "wdg_progress_editing_\(shared(Keys.userId) ?? "anonymous")"
}

private func progressReplaceKey() -> String {
    "wdg_progress_replace_\(shared(Keys.userId) ?? "anonymous")"
}

private func progressDraftKey(bookID: String, field: ProgressField) -> String {
    "wdg_progress_draft_\(shared(Keys.userId) ?? "anonymous")_\(bookID)_\(field.rawValue)"
}

private func progressOriginalKey(bookID: String, field: ProgressField) -> String {
    "wdg_progress_original_\(shared(Keys.userId) ?? "anonymous")_\(bookID)_\(field.rawValue)"
}

private func selectedProgressField() -> ProgressField {
    ProgressField(rawValue: shared(progressFieldKey()) ?? "") ?? .page
}

private func progressValue(_ book: WBook, field: ProgressField) -> Int {
    switch field {
    case .page: return book.currentPage ?? 0
    case .chapter: return book.currentChapter ?? 0
    }
}

/// Pages are the display source of truth when page + total are known.
/// An explicit percentage is used only when derivation is impossible;
/// a page without a total suppresses a conflicting stored percentage.
private func displayProgressPercent(_ book: WBook) -> Int? {
    if let page = book.currentPage, let total = book.pageCount, total > 0 {
        return min(max(Int((Double(page) / Double(total) * 100).rounded()), 0), 100)
    }
    if book.currentPage != nil { return nil }
    guard let pct = book.progressPct else { return nil }
    return min(max(pct, 0), 100)
}

private func progressValue(_ update: WProgressUpdate, field: ProgressField) -> Int {
    switch field {
    case .page: return update.currentPage ?? 0
    case .chapter: return update.currentChapter ?? 0
    }
}

private func progressTotal(_ book: WBook, field: ProgressField) -> Int? {
    switch field {
    case .page:
        guard let total = book.pageCount, total > 0 else { return nil }
        return total
    case .chapter:
        guard let total = book.chapterCount, total > 0 else { return nil }
        return total
    }
}

private func progressMaximum(_ book: WBook, field: ProgressField) -> Int {
    progressTotal(book, field: field) ?? 10_000_000
}

private func progressValueLabel(_ value: Int, book: WBook, field: ProgressField) -> String {
    guard let total = progressTotal(book, field: field) else { return "\(value)" }
    return "\(value)/\(total)"
}

private func progressDraft(_ book: WBook, field: ProgressField) -> Int {
    let stored = shared(progressDraftKey(bookID: book.id, field: field)).flatMap(Int.init)
    return min(
        max(stored ?? progressValue(book, field: field), 0),
        progressMaximum(book, field: field)
    )
}

private func persistProgressDrafts(bookID: String, update: WProgressUpdate) {
    for field in ProgressField.allCases {
        setShared(
            progressDraftKey(bookID: bookID, field: field),
            String(progressValue(update, field: field))
        )
    }
}

private func progressCacheDeadlineKey() -> String {
    "wdg_progress_cache_deadline_\(shared(Keys.userId) ?? "anonymous")"
}

private let progressMutationFeedbackDuration: TimeInterval = 1.5

private func progressMutationExpiryKey() -> String {
    "wdg_progress_mutation_expiry_\(shared(Keys.userId) ?? "anonymous")"
}

private func setProgressMutationFeedback(_ mutation: String) {
    setShared(progressMutationKey(), mutation)
    setShared(
        progressMutationExpiryKey(),
        String(Date().timeIntervalSince1970 + progressMutationFeedbackDuration)
    )
}

private func progressMutationFeedbackExpiry() -> Date? {
    guard let mutation = shared(progressMutationKey()),
          mutation == "saved" || mutation == "error",
          let raw = shared(progressMutationExpiryKey()),
          let timestamp = TimeInterval(raw) else {
        return nil
    }
    return Date(timeIntervalSince1970: timestamp)
}

private func progressMutationState() -> String {
    guard let mutation = shared(progressMutationKey()) else { return "idle" }
    guard let expiry = progressMutationFeedbackExpiry() else { return mutation }
    return expiry > Date() ? mutation : "idle"
}

private func preferCachedProgressTimeline() {
    setShared(progressCacheDeadlineKey(), String(Date().timeIntervalSince1970 + 5))
}

private func shouldUseCachedProgressTimeline() -> Bool {
    guard let raw = shared(progressCacheDeadlineKey()),
          let deadline = TimeInterval(raw) else {
        return false
    }
    return deadline > Date().timeIntervalSince1970
}

@available(iOSApplicationExtension 17.0, *)
struct SelectProgressBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Select reading book"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) {
        self.bookID = bookID
    }

    func perform() async throws -> some IntentResult {
        setShared(progressSelectionKey(), bookID)
        setShared(progressEditingKey(), "false")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct CycleProgressFieldIntent: AppIntent {
    static var title: LocalizedStringResource = "Change progress field"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        setShared(progressFieldKey(), selectedProgressField().next.rawValue)
        setShared(progressReplaceKey(), "true")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct OpenProgressKeypadIntent: AppIntent {
    static var title: LocalizedStringResource = "Enter exact reading progress"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        guard let book = WidgetAPI.cachedBook(bookID) else { return .result() }
        let preserveFailedDraft = shared(progressMutationKey()) == "error"
        for field in ProgressField.allCases {
            let initial = preserveFailedDraft
                ? progressDraft(book, field: field)
                : progressValue(book, field: field)
            setShared(
                progressDraftKey(bookID: bookID, field: field),
                String(min(max(initial, 0), progressMaximum(book, field: field)))
            )
            setShared(
                progressOriginalKey(bookID: bookID, field: field),
                String(min(max(initial, 0), progressMaximum(book, field: field)))
            )
        }
        setShared(progressEditingKey(), "true")
        setShared(progressReplaceKey(), "true")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ProgressDigitIntent: AppIntent {
    static var title: LocalizedStringResource = "Enter progress digit"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String
    @Parameter(title: "Digit") var digit: Int

    init() {}
    init(bookID: String, digit: Int) {
        self.bookID = bookID
        self.digit = digit
    }

    func perform() async throws -> some IntentResult {
        guard let book = WidgetAPI.cachedBook(bookID) else { return .result() }
        let field = selectedProgressField()
        let current = progressDraft(book, field: field)
        let replace = shared(progressReplaceKey()) == "true"
        let entered = min(max(digit, 0), 9)
        let raw = replace ? entered : current * 10 + entered
        let next = min(max(raw, 0), progressMaximum(book, field: field))
        setShared(progressDraftKey(bookID: bookID, field: field), String(next))
        setShared(progressReplaceKey(), "false")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct BackspaceProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete progress digit"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        guard let book = WidgetAPI.cachedBook(bookID) else { return .result() }
        let field = selectedProgressField()
        setShared(
            progressDraftKey(bookID: bookID, field: field),
            String(progressDraft(book, field: field) / 10)
        )
        setShared(progressReplaceKey(), "false")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct CancelProgressKeypadIntent: AppIntent {
    static var title: LocalizedStringResource = "Cancel progress entry"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        if let book = WidgetAPI.cachedBook(bookID) {
            for field in ProgressField.allCases {
                let original = shared(
                    progressOriginalKey(bookID: bookID, field: field)
                ).flatMap(Int.init) ?? progressValue(book, field: field)
                setShared(
                    progressDraftKey(bookID: bookID, field: field),
                    String(min(max(original, 0), progressMaximum(book, field: field)))
                )
            }
        }
        setShared(progressEditingKey(), "false")
        setShared(progressMutationKey(), "idle")
        preferCachedProgressTimeline()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct SaveProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Save reading progress"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Book ID") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        guard let book = WidgetAPI.cachedBook(bookID) else { return .result() }
        let field = selectedProgressField()
        let value = progressDraft(book, field: field)
        setShared(progressEditingKey(), "false")
        setShared(progressMutationKey(), "saving")
        preferCachedProgressTimeline()
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadendarProgressWidget")
        let update = await WidgetAPI.updateProgress(
            bookID: bookID,
            field: field.rawValue,
            value: value
        )
        WidgetAPI.setCachedProgress(bookID: bookID, update: update)
        persistProgressDrafts(bookID: bookID, update: update)
        setProgressMutationFeedback("saved")
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadendarWidget")
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct RefreshProgressWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh reading progress"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadendarProgressWidget")
        return .result()
    }
}

private func progressSelectionKey() -> String {
    "wdg_progress_selected_\(shared(Keys.userId) ?? "anonymous")"
}

/// Resolves selection by book ID. An ID that left the reading set is dropped.
/// The payload's first book is shown when nothing is stored; that default is
/// not persisted, so a later summary reorder is not pinned to an old pick.
private func resolvedProgressBookID(_ books: [WBook]) -> String? {
    let key = progressSelectionKey()
    let stored = shared(key)
    if let stored, books.contains(where: { $0.id == stored }) {
        return stored
    }
    if stored != nil { removeShared(key) }
    return books.first?.id
}

@available(iOSApplicationExtension 17.0, *)
private struct ReadendarProgressEntryView: View {
    let entry: WidgetEntry
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var family

    private var isLarge: Bool { family == .systemLarge }

    private var selectedIndex: Int {
        guard !entry.summary.readingBooks.isEmpty else { return 0 }
        let selectedID = shared(progressSelectionKey())
        return entry.summary.readingBooks.firstIndex { $0.id == selectedID } ?? 0
    }

    private var selectedBook: WBook? {
        guard entry.summary.readingBooks.indices.contains(selectedIndex) else { return nil }
        return entry.summary.readingBooks[selectedIndex]
    }

    private var headerBooks: [WBook] {
        let books = entry.summary.readingBooks
        guard books.count > 1 else { return [] }
        return (0..<min(books.count, 4)).map { books[(selectedIndex + $0) % books.count] }
    }

    private var field: ProgressField { selectedProgressField() }

    private func fieldLabel(_ field: ProgressField) -> String {
        switch field {
        case .page: return loc("pages")
        case .chapter: return loc("chapter")
        }
    }

    private var mutation: String { progressMutationState() }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 10 : 8) {
            if let book = selectedBook, shared(progressEditingKey()) == "true" {
                ProgressKeypadView(
                    book: book,
                    field: field,
                    fieldLabel: fieldLabel(field)
                )
            } else {
                WidgetHeader {
                    if !headerBooks.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(headerBooks) { book in
                                Button(intent: SelectProgressBookIntent(bookID: book.id)) {
                                    CoverThumb(
                                        title: book.title,
                                        coverUrl: book.coverUrl,
                                        covers: entry.covers,
                                        width: 22,
                                        height: 31,
                                        cornerRadius: 3
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(book.title))
                            }
                        }
                    }
                }
                .layoutPriority(1)

                if let book = selectedBook {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            CoverThumb(
                                title: book.title,
                                coverUrl: book.coverUrl,
                                covers: entry.covers,
                                width: isLarge ? 40 : 32,
                                height: isLarge ? 60 : 48,
                                cornerRadius: 3
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.system(size: isLarge ? 15 : 13, weight: .semibold))
                                    .lineLimit(isLarge ? 2 : 1)
                                if !book.author.isEmpty {
                                    Text(book.author)
                                        .font(.system(size: isLarge ? 13 : 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                ProgressMeta(book: book)
                            }
                        }
                        if let pct = effectiveProgress(book) {
                            ProgressBar(pct: pct)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, isLarge ? 14 : 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: WidgetAppPalette.current(scheme).cardRadius)
                            .fill(WidgetAppPalette.current(scheme).surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WidgetAppPalette.current(scheme).cardRadius)
                            .stroke(
                                WidgetAppPalette.current(scheme).line,
                                lineWidth: WidgetAppPalette.current(scheme).borderWidth
                            )
                    )
                    .widgetURL(deepLinkURL("book/\(book.id)"))

                    // Large: pin the update CTA to the bottom so the card doesn't
                    // float in a tall empty band.
                    if isLarge { Spacer(minLength: 8) }

                    ProgressInlineControls(
                        book: book,
                        mutation: mutation
                    )
                } else if entry.state == .error || entry.state == .stale {
                    Spacer(minLength: 0)
                    StateMessage(symbol: "wifi.slash", text: loc("updateFailed"))
                    Button(intent: RefreshProgressWidgetIntent()) {
                        Text(loc("retry"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WidgetAppPalette.current(scheme).accent)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    StateMessage(symbol: "books.vertical", text: loc("empty"))
                    if let url = deepLinkURL("library") {
                        Link(destination: url) {
                            Text(loc("go_library"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(WidgetAppPalette.current(scheme).accent)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(WidgetAppPalette.current(scheme).primary)
        .containerBackground(for: .widget) { widgetCanvas(scheme) }
        // Keep progress palette in lockstep with the app's explicit appearance,
        // matching events and auto-style quotes. System remains OS-adaptive.
        .modifier(PreferredColorSchemeModifier(scheme: preferredWidgetScheme()))
    }

    /// Pages are the display source of truth when page + total are known.
    /// An explicit percentage is used only when derivation is impossible;
    /// a page without a total suppresses a conflicting stored percentage.
    private func effectiveProgress(_ book: WBook) -> Int? {
        displayProgressPercent(book)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct ProgressKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct ProgressKeypadView: View {
    let book: WBook
    let field: ProgressField
    let fieldLabel: String

    @Environment(\.colorScheme) private var scheme

    private var draft: Int { progressDraft(book, field: field) }
    private var valueLabel: String { progressValueLabel(draft, book: book, field: field) }
    private var palette: WidgetAppPalette { WidgetAppPalette.current(scheme) }
    private var outline: Color { palette.lineStrong }
    private var surface: Color { palette.surface2 }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(valueLabel)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: Double(draft)))
                    .animation(.easeOut(duration: 0.16), value: draft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Button(intent: CycleProgressFieldIntent(bookID: book.id)) {
                    compactKeySurface(
                        HStack(spacing: 6) {
                            Image(systemName: field == .page ? "book" : "bookmark")
                                .foregroundStyle(palette.accent)
                            Text(fieldLabel)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .layoutPriority(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)
                        }
                        .padding(.horizontal, 8)
                    )
                }
                .buttonStyle(ProgressKeyButtonStyle())

                Button(intent: CancelProgressKeypadIntent(bookID: book.id)) {
                    keySurface(Text("×").font(.system(size: 18, weight: .bold)))
                        .frame(width: 32)
                }
                .buttonStyle(ProgressKeyButtonStyle())
                .accessibilityLabel(Text(loc("cancel")))
            }
            .frame(height: 32)

            HStack(spacing: 4) {
                digitButton(1)
                digitButton(2)
                digitButton(3)
                Button(intent: BackspaceProgressIntent(bookID: book.id)) {
                    keySurface(Text("⌫").font(.system(size: 15, weight: .bold)))
                }
                .buttonStyle(ProgressKeyButtonStyle())
                .accessibilityLabel(Text(loc("backspace")))
            }

            HStack(spacing: 4) {
                digitButton(4)
                digitButton(5)
                digitButton(6)
                digitButton(0)
            }

            HStack(spacing: 4) {
                digitButton(7)
                digitButton(8)
                digitButton(9)
                Button(intent: SaveProgressIntent(bookID: book.id)) {
                    Text("✓")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: palette.controlRadius)
                                .fill(palette.accent)
                        )
                }
                .buttonStyle(ProgressKeyButtonStyle())
                .accessibilityLabel(Text(loc("save")))
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func digitButton(_ digit: Int) -> some View {
        Button(intent: ProgressDigitIntent(bookID: book.id, digit: digit)) {
            keySurface(
                Text(String(digit))
                    .font(.system(size: 15, weight: .bold))
            )
        }
        .buttonStyle(ProgressKeyButtonStyle())
        .accessibilityLabel(Text(String(digit)))
    }

    private func keySurface<Content: View>(_ content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: palette.controlRadius).fill(surface))
            .overlay(RoundedRectangle(cornerRadius: palette.controlRadius).stroke(outline, lineWidth: palette.borderWidth))
    }

    private func compactKeySurface<Content: View>(_ content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: palette.controlRadius).fill(surface))
            .overlay(RoundedRectangle(cornerRadius: palette.controlRadius).stroke(outline, lineWidth: palette.borderWidth))
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct ProgressInlineControls: View {
    let book: WBook
    let mutation: String

    @Environment(\.colorScheme) private var scheme
    private var palette: WidgetAppPalette { WidgetAppPalette.current(scheme) }

    private var actionLabel: String {
        switch mutation {
        case "saving": return loc("saving")
        case "saved": return loc("updated")
        case "error": return loc("updateFailed")
        default: return loc("update_progress")
        }
    }

    var body: some View {
        Button(intent: OpenProgressKeypadIntent(bookID: book.id)) {
            Text(actionLabel)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: palette.controlRadius)
                        .fill(palette.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(mutation == "saving")
        .accessibilityLabel(Text(loc("update_progress")))
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct ProgressMeta: View {
    let book: WBook

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "book")
            Text(fraction(book.currentPage, book.pageCount))
            Text("·").foregroundStyle(.tertiary)
            Text(percentLabel)
            Text("·").foregroundStyle(.tertiary)
            Image(systemName: "bookmark")
            Text(fraction(book.currentChapter, book.chapterCount))
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var percentLabel: String {
        guard let pct = displayProgressPercent(book) else { return "—" }
        return "\(pct)%"
    }

    private func fraction(_ current: Int?, _ total: Int?) -> String {
        guard let current else { return "—" }
        guard let total else { return "\(current)" }
        return "\(current) / \(total)"
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), summary: .progressPreview, state: .ok)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(WidgetEntry(date: Date(), summary: .progressPreview, state: .ok))
            return
        }
        let (summary, state) = WidgetAPI.cachedSummary()
        let selectedID = resolvedProgressBookID(summary.readingBooks)
        let covers = WidgetAPI.cachedCovers(for: summary, prioritizedBookID: selectedID)
        completion(WidgetEntry(date: Date(), summary: summary, state: state, covers: covers))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let regularRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date)
                ?? entry.date.addingTimeInterval(1800)
            let next: Date
            if let expiry = progressMutationFeedbackExpiry(), expiry > entry.date {
                next = expiry
            } else {
                next = regularRefresh
            }
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> WidgetEntry {
        let usesCachedTimeline = shouldUseCachedProgressTimeline()
        let (summary, state) = if usesCachedTimeline {
            WidgetAPI.cachedSummary()
        } else {
            await WidgetAPI.loadSummary()
        }
        let storedID = resolvedProgressBookID(summary.readingBooks)
        let selectedID = storedID
        let covers = if usesCachedTimeline {
            WidgetAPI.cachedCovers(for: summary, prioritizedBookID: selectedID)
        } else {
            await WidgetAPI.preloadCovers(for: summary, prioritizedBookID: selectedID)
        }
        return WidgetEntry(date: Date(), summary: summary, state: state, covers: covers)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ReadendarProgressWidget: Widget {
    let kind = "ReadendarProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ReadendarProgressEntryView(entry: entry)
        }
        .configurationDisplayName(Text(loc("progress_widget_name")))
        .description(Text(loc("progress_widget_description")))
        // Medium is the compact keypad-friendly default; Large gives the
        // keypad/book card room to breathe (matches Android vertical resize).
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct ReadendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadendarWidget()
        quotesWidget
        progressWidget
        controlWidgets
    }

    // The quotes widget is gated to iOS 17+ (its provider + containerBackground
    // usage). The nested @WidgetBundleBuilder property keeps the availability
    // branch out of the main builder — the events widget stays available from
    // iOS 14. On <17 the quotes widget simply doesn't appear in the gallery.
    @WidgetBundleBuilder
    private var quotesWidget: some Widget {
        if #available(iOSApplicationExtension 17.0, *) {
            ReadendarQuotesWidget()
        }
    }

    @WidgetBundleBuilder
    private var progressWidget: some Widget {
        if #available(iOSApplicationExtension 17.0, *) {
            ReadendarProgressWidget()
        }
    }

    @WidgetBundleBuilder
    private var controlWidgets: some Widget {
        if #available(iOSApplicationExtension 18.0, *) {
            NewQuoteControlWidget()
            LogProgressControlWidget()
            WhatsNextControlWidget()
        }
    }
}

// MARK: - Control Center (iOS 18+)

@available(iOSApplicationExtension 18.0, *)
struct NewQuoteControlWidget: ControlWidget {
    static let kind = "com.readendar.readendar.control.newQuote"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(URL(string: "readendar://quote/new")!)
            ) {
                Label(loc("control_new_quote"), systemImage: "quote.bubble")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: loc("control_new_quote")))
        .description(LocalizedStringResource(stringLiteral: loc("control_new_quote_desc")))
    }
}

@available(iOSApplicationExtension 18.0, *)
struct LogProgressControlWidget: ControlWidget {
    static let kind = "com.readendar.readendar.control.progress"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(URL(string: "readendar://progress")!)
            ) {
                Label(loc("control_log_progress"), systemImage: "book")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: loc("control_log_progress")))
        .description(LocalizedStringResource(stringLiteral: loc("control_log_progress_desc")))
    }
}

@available(iOSApplicationExtension 18.0, *)
struct WhatsNextControlWidget: ControlWidget {
    static let kind = "com.readendar.readendar.control.calendar"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(URL(string: "readendar://calendar")!)
            ) {
                Label(loc("control_whats_next"), systemImage: "calendar")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: loc("control_whats_next")))
        .description(LocalizedStringResource(stringLiteral: loc("control_whats_next_desc")))
    }
}
