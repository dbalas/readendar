// Readendar QUOTES home-screen widget (iOS 17+).
//
// Second widget in the ReadendarWidgetBundle (same extension target as the
// events widget — no new target, same App Group). Renders ONE saved quote
// (serif-italic passage + book footer + favorite star) from the shared
// wdg_quotes_cache snapshot, refreshed via WidgetAPI.loadQuotes()
// (App Group cache written by the Flutter app).
//
// Configuration is APP-OWNED: the widget uses a StaticConfiguration and reads
// its config (mode: all / favorites / one book / one fixed quote + rotation
// cadence) from the App Group (QuotesConfig, key wdg_quotes_config), NOT a
// system AppIntent. So tapping the widget opens the in-app editor and saving
// updates the widget immediately (WidgetCenter reload). One shared config per
// app on iOS — the deliberate trade-off for app-side editing; Android keeps
// true per-instance config.
//
// Rotation is DETERMINISTIC and stateless — `localTimeBucket % candidates` on
// the snapshot's stable newest-first order, the exact same formula as the
// Android provider (QuotesRotation) and the in-app preview/daily notification,
// so every surface shows the same quote at the same time. The timeline
// pre-schedules entries at upcoming bucket boundaries so the quote flips
// without waking the network.

import SwiftUI
import WidgetKit

// MARK: - Shared config (app-owned)

/// The quotes widget's configuration, read from the App Group (StaticConfiguration)
/// instead of a system AppIntent — so the app owns it and tap-to-edit + instant
/// updates work. Mirrors the Dart `QuotesWidgetConfig` JSON contract
/// (widget_models.dart): mode `all/favorites/book/fixed`, cadence `1h/6h/daily`.
struct QuotesConfig {
    enum Mode: String { case all, favorites, book, fixed }
    enum Cadence: String {
        case hourly = "1h"
        case sixHourly = "6h"
        case daily

        var periodMillis: Int64 {
            switch self {
            case .hourly: return 3_600_000
            case .sixHourly: return 21_600_000
            case .daily: return 86_400_000
            }
        }
    }

    /// The widget's appearance. `auto` follows the app theme (wdg_theme); every
    /// other value is a fixed brand palette matching the share card
    /// (QuoteWidgetStyle / QuoteCardStyle in Dart). Raw values match the wire.
    enum Style: String {
        case auto
        case lightElegant, minimal, dark, coverGradient
        case gradientSunset, gradientForest, gradientOcean, gradientDusk
        case parchment, mist, pine, honey, noirGold
    }

    var mode: Mode = .all
    var quoteId: String?
    var bookId: String?
    var cadence: Cadence = .daily
    var style: Style = .auto

    /// When true, a shown quote's private note is rendered on the widget. Off by
    /// default — mirrors the share-time opt-in.
    var showNote: Bool = false

    /// Shared-store key the app writes on add / tap-to-edit (kWidgetKeyQuotesConfig).
    static let key = "wdg_quotes_config"

    static func load() -> QuotesConfig {
        guard let raw = widgetSharedString(key),
              let data = raw.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return QuotesConfig() }
        var c = QuotesConfig()
        if let m = o["mode"] as? String {
            if m == "favorites" || m == "pinned" { c.mode = .favorites }
            else if let mode = Mode(rawValue: m) { c.mode = mode }
        }
        if let cad = o["cadence"] as? String, let cadence = Cadence(rawValue: cad) { c.cadence = cadence }
        if let st = o["style"] as? String, let style = Style(rawValue: st) { c.style = style }
        c.quoteId = o["quoteId"] as? String
        c.bookId = o["bookId"] as? String
        c.showNote = o["showNote"] as? Bool ?? false
        return c
    }

    /// The deep-link path opening the in-app editor pre-filled with this config
    /// (readendar://widget-quotes-config?...). No appWidgetId on iOS — a save
    /// targets the single shared config.
    func editDeepLinkPath() -> String {
        var items = ["mode=\(mode.rawValue)", "cadence=\(cadence.rawValue)", "style=\(style.rawValue)", "showNote=\(showNote)"]
        if mode == .fixed, let quoteId,
           let e = quoteId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            items.append("quoteId=\(e)")
        }
        if mode == .book, let bookId,
           let e = bookId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            items.append("bookId=\(e)")
        }
        return "widget-quotes-config?\(items.joined(separator: "&"))"
    }
}

// MARK: - Deterministic rotation (same bucket formula as Android)

@available(iOSApplicationExtension 17.0, *)
enum QuotesRotation {
    /// Local-time bucket: epoch hour / 6-hour block / day, in the device zone.
    static func bucket(_ cadence: QuotesConfig.Cadence, at date: Date, zone: TimeZone = .current) -> Int64 {
        let millis = Int64(date.timeIntervalSince1970 * 1000)
        let local = millis + Int64(zone.secondsFromGMT(for: date)) * 1000
        return local / cadence.periodMillis
    }

    /// The instant the current bucket rolls over (next quote flip).
    static func nextBoundary(_ cadence: QuotesConfig.Cadence, after date: Date, zone: TimeZone = .current) -> Date {
        let millis = Int64(date.timeIntervalSince1970 * 1000)
        let offset = Int64(zone.secondsFromGMT(for: date)) * 1000
        let local = millis + offset
        let nextLocal = (local / cadence.periodMillis + 1) * cadence.periodMillis
        return Date(timeIntervalSince1970: TimeInterval(nextLocal - offset) / 1000)
    }

    static func candidates(_ quotes: [WQuote], config: QuotesConfig) -> [WQuote] {
        if config.mode == .fixed {
            if let picked = quotes.first(where: { $0.id == config.quoteId }) { return [picked] }
            return Array(quotes.prefix(1))
        }
        let filtered: [WQuote]
        switch config.mode {
        case .favorites: filtered = quotes.filter { $0.isFavorite }
        case .book: filtered = quotes.filter { $0.bookId == config.bookId }
        default: filtered = quotes
        }
        return filtered.isEmpty ? quotes : filtered
    }

    static func pick(_ candidates: [WQuote], config: QuotesConfig, at date: Date) -> WQuote? {
        guard !candidates.isEmpty else { return nil }
        if config.mode == .fixed { return candidates[0] }
        // Non-negative modulo (Swift % keeps the dividend's sign): guards the
        // index against a misconfigured pre-1970 device clock making bucket < 0.
        let n = Int64(candidates.count)
        let idx = Int(((bucket(config.cadence, at: date) % n) + n) % n)
        return candidates[idx]
    }
}

// MARK: - Timeline

@available(iOSApplicationExtension 17.0, *)
struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: WQuote?
    var covers: [String: Data] = [:]
    var config = QuotesConfig()
}

@available(iOSApplicationExtension 17.0, *)
struct QuotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: WQuote(
            id: "placeholder",
            text: "El mundo era tan reciente, que muchas cosas carecían de nombre.",
            page: 9, favorite: true, bookId: "b",
            bookTitle: "Cien años de soledad",
            bookAuthor: "Gabriel García Márquez",
            bookCoverUrl: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        let config = QuotesConfig.load()
        let payload = WidgetAPI.cachedQuotes()
        let candidates = QuotesRotation.candidates(payload.quotes, config: config)
        let covers = WidgetAPI.cachedQuoteCovers(candidates)
        completion(QuoteEntry(
            date: Date(),
            quote: QuotesRotation.pick(candidates, config: config, at: Date()),
            covers: covers,
            config: config
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        Task {
            let config = QuotesConfig.load()
            let payload = await freshPayload()
            let candidates = QuotesRotation.candidates(payload.quotes, config: config)
            let now = Date()

            if config.mode == .fixed {
                let quote = QuotesRotation.pick(candidates, config: config, at: now)
                let covers = await WidgetAPI.preloadQuoteCovers(quote.map { [$0] } ?? [])
                let entry = QuoteEntry(date: now, quote: quote, covers: covers, config: config)
                // Data can still change (edit/delete) — refresh lazily.
                completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(6 * 3600))))
                return
            }

            // One entry per upcoming bucket boundary so the quote flips exactly on
            // schedule without a network wake: 12 hourly / 4 six-hourly / 2 daily.
            let boundaryCount: Int
            switch config.cadence {
            case .hourly: boundaryCount = 12
            case .sixHourly: boundaryCount = 4
            case .daily: boundaryCount = 2
            }

            // Resolve the quote SHOWN at each boundary first, then preload exactly
            // those covers — `pick` uses `bucket % count` over the whole list, so a
            // boundary can land past any fixed prefix; preloading e.g. the first N
            // candidates would leave later entries (esp. the coverGradient
            // background) with no artwork.
            var picks: [(date: Date, quote: WQuote?)] = [
                (now, QuotesRotation.pick(candidates, config: config, at: now))
            ]
            var cursor = now
            for _ in 0..<boundaryCount {
                cursor = QuotesRotation.nextBoundary(config.cadence, after: cursor)
                picks.append((cursor, QuotesRotation.pick(candidates, config: config, at: cursor)))
            }
            let covers = await WidgetAPI.preloadQuoteCovers(picks.compactMap { $0.quote })
            let entries = picks.map {
                QuoteEntry(date: $0.date, quote: $0.quote, covers: covers, config: config)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    /// Cache-first: a snapshot pushed by the app moments ago should win; only
    /// refetch when the cache is missing or stale (> ~6 h old).
    private func freshPayload() async -> WidgetQuotesPayload {
        let cached = WidgetAPI.cachedQuotes()
        if !cached.quotes.isEmpty, let stamp = cached.fetchedAt,
           let fetched = parseISO8601(stamp),
           Date().timeIntervalSince(fetched) < 6 * 3600 {
            return cached
        }
        return await WidgetAPI.loadQuotes()
    }

    /// Parses both stamp shapes we write: the Dart app-push uses
    /// `toIso8601String()` (fractional seconds, e.g. '...:30.123456Z'), the
    /// native fetch uses a plain `ISO8601DateFormatter` (no fraction). A single
    /// default formatter can't parse both — it silently returns nil for the
    /// fractional case, which is exactly the app-pushed cache the fast path
    /// exists to trust — so try with fractional seconds first, then without.
    private func parseISO8601(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        return ISO8601DateFormatter().date(from: s)
    }
}

// MARK: - Views

@available(iOSApplicationExtension 17.0, *)
struct QuotesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    var entry: QuoteEntry

    private var isAuto: Bool { entry.config.style == .auto }
    private var palette: QuotePalette? {
        guard isAuto else { return QuotePalette.resolve(entry.config.style) }
        let app = WidgetAppPalette.current(scheme)
        return QuotePalette(background: app.background, gradient: nil, coverBlur: false,
                            text: app.primary, meta: app.secondary,
                            wordmarkRead: app.accent, wordmarkEndar: app.secondary,
                            star: quotesStar)
    }

    var body: some View {
        Group {
            if let quote = entry.quote {
                // Tap → open the in-app editor for this widget's config.
                QuoteView(quote: quote, covers: entry.covers, palette: palette, showNote: entry.config.showNote)
                    .widgetURL(quoteDeepLink(entry.config.editDeepLinkPath()))
            } else {
                // No quotes yet — tap adds the first one.
                QuotesEmptyState(palette: palette)
                    .widgetURL(quoteDeepLink("quote/new"))
            }
        }
        .containerBackground(for: .widget) { background }
        // The theme override only applies to `auto`; presets are fixed palettes.
        .modifier(QuotesPreferredSchemeModifier(active: isAuto))
    }

    @ViewBuilder private var background: some View {
        if isAuto {
            widgetCanvas(scheme)
        } else if let palette {
            if palette.coverBlur {
                QuotesCoverBackground(
                    coverUrl: entry.quote?.bookCoverUrl ?? "",
                    covers: entry.covers,
                    fallback: palette.background
                )
            } else if let gradient = palette.gradient {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                palette.background
            }
        } else {
            Color(.systemBackground)
        }
    }
}

/// The blurred-cover background for the `coverGradient` style: the current
/// quote's cover, blurred, under a dark scrim so paper-tone text clears it.
/// Falls back to the solid palette colour when the cover isn't available.
@available(iOSApplicationExtension 17.0, *)
struct QuotesCoverBackground: View {
    let coverUrl: String
    let covers: [String: Data]
    let fallback: Color

    var body: some View {
        ZStack {
            fallback
            if let img = quoteCoverImage(coverUrl, covers: covers) {
                Image(uiImage: img).resizable().scaledToFill().blur(radius: 20)
                Color(rgb: 0x141326).opacity(0.70)
            }
        }
    }
}

/// Decodes a cover to a UIImage ONCE per url (backed by an NSCache), so the
/// coverGradient style doesn't decode the same bytes twice in one render (the
/// blurred background + the footer thumbnail both need it). Resolves the bytes
/// from the preloaded `covers` map, else the on-disk cover cache; nil for an
/// empty url or undecodable data.
private let quoteCoverImageCache = NSCache<NSString, UIImage>()

func quoteCoverImage(_ url: String, covers: [String: Data]) -> UIImage? {
    guard !url.isEmpty else { return nil }
    if let cached = quoteCoverImageCache.object(forKey: url as NSString) { return cached }
    guard let data = covers[url] ?? CoverDiskCache.read(url),
          let img = UIImage(data: data) else { return nil }
    quoteCoverImageCache.setObject(img, forKey: url as NSString)
    return img
}

/// Explicit light/dark override from the app's theme choice (wdg_theme),
/// mirroring the events widget; "system"/absent no-ops. Skipped entirely for
/// preset styles ([active] false), which carry their own fixed colours.
@available(iOSApplicationExtension 17.0, *)
private struct QuotesPreferredSchemeModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        guard active else { return AnyView(content) }
        switch widgetSharedString("wdg_theme") {
        case "light": return AnyView(content.preferredColorScheme(.light))
        case "dark": return AnyView(content.preferredColorScheme(.dark))
        default: return AnyView(content)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private func quoteDeepLink(_ path: String) -> URL? {
    let s = widgetSharedString("wdg_scheme") ?? ""
    return URL(string: "\(s.isEmpty ? "readendar" : s)://\(path)")
}

private let quotesBrand = Color(red: 0x74/255, green: 0x79/255, blue: 0xD6/255)
private let quotesStar = Color(red: 0xDD/255, green: 0x9D/255, blue: 0x2B/255)

private extension Color {
    /// 0xRRGGBB literal → Color (matches the Dart token hex values).
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// MARK: - Style palette (mirrors Dart paletteFor + QuoteWidgetStyle)

/// The fixed colours a preset style renders with. `nil` (returned for `.auto`)
/// means "follow the app theme" — the view falls back to the semantic
/// `.primary`/`.secondary`/`systemBackground` colours + the wdg_theme override.
@available(iOSApplicationExtension 17.0, *)
struct QuotePalette {
    var background: Color
    var gradient: [Color]?
    var coverBlur: Bool
    var text: Color
    var meta: Color
    var wordmarkRead: Color
    var wordmarkEndar: Color
    var star: Color

    static func resolve(_ style: QuotesConfig.Style) -> QuotePalette? {
        switch style {
        case .auto:
            return nil
        case .lightElegant:
            return QuotePalette(background: Color(rgb: 0xF7F7F5), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0x0F1014), meta: Color(rgb: 0x525250),
                                wordmarkRead: Color(rgb: 0x5A5FBC), wordmarkEndar: Color(rgb: 0x1F1F1F), star: quotesStar)
        case .minimal:
            return QuotePalette(background: Color(rgb: 0xFFFFFF), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0x0F1014), meta: Color(rgb: 0x7A7A74),
                                wordmarkRead: Color(rgb: 0x5A5FBC), wordmarkEndar: Color(rgb: 0x1F1F1F), star: quotesStar)
        case .dark:
            return QuotePalette(background: Color(rgb: 0x0F1014), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0xF7F7F5), meta: Color(rgb: 0xA3A39C),
                                wordmarkRead: Color(rgb: 0x8E94D3), wordmarkEndar: Color(rgb: 0xE5E5E0), star: quotesStar)
        case .coverGradient:
            return QuotePalette(background: Color(rgb: 0x1B1E48), gradient: nil, coverBlur: true,
                                text: Color(rgb: 0xFFFFFF), meta: Color(rgb: 0xE5E5E0),
                                wordmarkRead: Color(rgb: 0xFFFFFF), wordmarkEndar: Color(rgb: 0xEFEFEC), star: quotesStar)
        case .gradientSunset:
            return gradientPalette([Color(rgb: 0xB23F45), Color(rgb: 0xE0A03A)])
        case .gradientForest:
            return gradientPalette([Color(rgb: 0x2A8F7D), Color(rgb: 0x5B924C)])
        case .gradientOcean:
            return gradientPalette([Color(rgb: 0x7479D6), Color(rgb: 0x2A8F7D)])
        case .gradientDusk:
            return gradientPalette([Color(rgb: 0x7479D6), Color(rgb: 0xB23F45)])
        case .parchment:
            return QuotePalette(background: Color(rgb: 0xFAF5EF), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0x0F1014), meta: Color(rgb: 0x5E5E5B),
                                wordmarkRead: Color(rgb: 0x8F2F35), wordmarkEndar: Color(rgb: 0x2A2A2A), star: quotesStar)
        case .mist:
            return QuotePalette(background: Color(rgb: 0xE2E4F4), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0x161617), meta: Color(rgb: 0x44489A),
                                wordmarkRead: Color(rgb: 0x44489A), wordmarkEndar: Color(rgb: 0x2A2A2A), star: quotesStar)
        case .pine:
            return QuotePalette(background: Color(rgb: 0x103D35), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0xFFFFFF), meta: Color(rgb: 0x97D6C8),
                                wordmarkRead: Color(rgb: 0xFFFFFF), wordmarkEndar: Color(rgb: 0xC9E9E0), star: quotesStar)
        case .honey:
            return QuotePalette(background: Color(rgb: 0xF7E2B5), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0x0F1014), meta: Color(rgb: 0x644111),
                                wordmarkRead: Color(rgb: 0x644111), wordmarkEndar: Color(rgb: 0x1F1F1F), star: quotesStar)
        case .noirGold:
            return QuotePalette(background: Color(rgb: 0x28090B), gradient: nil, coverBlur: false,
                                text: Color(rgb: 0xF7F7F5), meta: Color(rgb: 0xC9C9C2),
                                wordmarkRead: Color(rgb: 0xDD9D2B), wordmarkEndar: Color(rgb: 0xE5E5E0), star: quotesStar)
        }
    }

    /// Shared white-on-saturated palette for the brand gradients.
    private static func gradientPalette(_ colors: [Color]) -> QuotePalette {
        QuotePalette(background: colors.first ?? quotesBrand, gradient: colors, coverBlur: false,
                     text: Color(rgb: 0xFFFFFF), meta: Color(rgb: 0xEFEFEC),
                     wordmarkRead: Color(rgb: 0xFFFFFF), wordmarkEndar: Color(rgb: 0xEFEFEC), star: quotesStar)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct QuoteView: View {
    let quote: WQuote
    let covers: [String: Data]
    var palette: QuotePalette?
    var showNote: Bool = false
    @Environment(\.widgetFamily) private var family

    /// The trimmed note to render, or nil when there's none / the config opts out.
    private var noteText: String? {
        guard showNote, let n = quote.note?.trimmingCharacters(in: .whitespacesAndNewlines),
              !n.isEmpty else { return nil }
        return n
    }

    /// Family-aware caps so medium/large can show the full quote. Android medium
    /// uses maxLines=5 with layout_weight=1; Large gets more room for long quotes.
    private var quoteLineLimit: Int {
        switch family {
        case .systemLarge:
            return noteText == nil ? 14 : 10
        case .systemMedium:
            return noteText == nil ? 6 : 4
        default:
            return noteText == nil ? 5 : 3
        }
    }

    private var quoteFont: Font {
        switch family {
        case .systemLarge:
            return .system(.body, design: .serif)
        case .systemSmall:
            return .system(size: 13, design: .serif)
        default:
            return .system(.subheadline, design: .serif)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack {
                QuotesBrandWordmark(palette: palette, size: family == .systemSmall ? 11 : 15)
                Spacer(minLength: 8)
            }
            .layoutPriority(2)

            // Fills leftover height (Android qwdg_text layout_weight=1).
            // Alignment.leading = horizontal leading + vertical center (Android
            // gravity=center_vertical).
            Text("«\(quote.text)»")
                .font(quoteFont)
                .italic()
                .lineLimit(quoteLineLimit)
                .minimumScaleFactor(0.7)
                .foregroundColor(palette?.text ?? .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if let noteText {
                Text(noteText)
                    .font(.system(size: 11))
                    .lineLimit(family == .systemLarge ? 3 : 2)
                    .foregroundColor(palette?.meta ?? .secondary)
                    .layoutPriority(1)
            }

            HStack(spacing: 8) {
                QuoteCoverThumb(title: quote.bookTitle, coverUrl: quote.bookCoverUrl ?? "", covers: covers)
                VStack(alignment: .leading, spacing: 1) {
                    Text(quote.bookTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette?.text ?? .primary)
                        .lineLimit(1)
                    Text(footerMeta)
                        .font(.system(size: 10))
                        .foregroundColor(palette?.meta ?? .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if quote.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(palette?.star ?? quotesStar)
                }
            }
            .layoutPriority(2)
        }
        .padding(family == .systemSmall ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footerMeta: String {
        var parts: [String] = []
        if !quote.bookAuthor.isEmpty { parts.append(quote.bookAuthor) }
        if let page = quote.page { parts.append(String(format: quotesLoc("page"), page)) }
        return parts.joined(separator: " · ")
    }
}

@available(iOSApplicationExtension 17.0, *)
struct QuoteCoverThumb: View {
    let title: String
    let coverUrl: String
    let covers: [String: Data]

    var body: some View {
        Group {
            if let img = quoteCoverImage(coverUrl, covers: covers) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    quotesBrand
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 22, height: 31)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

@available(iOSApplicationExtension 17.0, *)
struct QuotesEmptyState: View {
    var palette: QuotePalette?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                QuotesBrandWordmark(palette: palette, size: family == .systemSmall ? 11 : 15)
                Spacer()
            }
            Spacer(minLength: 0)
            Image(systemName: "quote.opening")
                .font(.system(size: family == .systemSmall ? 16 : 20))
                .foregroundColor(palette?.meta ?? .secondary)
            Text(quotesLoc("empty"))
                .font(.system(size: family == .systemSmall ? 11 : 12, weight: .bold))
                .foregroundColor(palette?.meta ?? .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(family == .systemSmall ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// The "READENDAR" wordmark, identical to the events widget's BrandWordmark
// (size 15, "READ" tinted accent) so all Readendar widgets share one brand mark.
@available(iOSApplicationExtension 17.0, *)
struct QuotesBrandWordmark: View {
    var palette: QuotePalette?
    var size: CGFloat = 15

    var body: some View {
        var s = AttributedString("READENDAR")
        s.tracking = size < 13 ? 0.9 : 1.1
        s.foregroundColor = palette?.wordmarkEndar ?? .secondary
        if let r = s.range(of: "READ") { s[r].foregroundColor = palette?.wordmarkRead ?? quotesBrand }
        return Text(s).font(.system(size: size, weight: .bold))
    }
}

// Native chrome strings, keyed by wdg_locale (same approach as the events widget).
private func quotesLoc(_ key: String) -> String {
    let l = String((widgetSharedString("wdg_locale") ?? "es").prefix(2))
    let table: [String: [String: String]] = [
        "quotes_widget_name": ["es": "Citas"],
        "empty": ["es": "Añade tu primera cita"],
        "page": ["es": "p. %d"],
    ]
    return table[key]?[l] ?? table[key]?["es"] ?? key
}

// MARK: - Widget definition

@available(iOSApplicationExtension 17.0, *)
struct ReadendarQuotesWidget: Widget {
    let kind = "ReadendarQuotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotesProvider()) { entry in
            QuotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Text(quotesLoc("quotes_widget_name")))
        .description("Una cita de tu biblioteca: una que elijas, o una rotación.")
        // Medium first (gallery default); Large for long quotes; Small kept.
        .supportedFamilies([.systemMedium, .systemLarge, .systemSmall])
    }
}
