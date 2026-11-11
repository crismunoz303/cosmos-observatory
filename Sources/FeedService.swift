import Foundation

@MainActor
final class ObservatoryStore: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errors: [String] = []
    @Published private(set) var successfulSources: [String] = []

    private let service = RSSFeedService()

    var supernovaItems: [FeedItem] {
        items.filter {
            let text = ($0.title + " " + $0.summary).lowercased()
            return ["supernova", "super-nova", "type ia", "type ii", "type ib", "type ic",
                    "stellar explosion", "core-collapse", "kilonova", "superluminous",
                    "sn 20", "sn20"].contains(where: text.contains)
        }
    }

    // arXiv astrophysics category feeds are already scoped to astronomy research.
    // Agency/journal stories must earn inclusion through their headline, not boilerplate abstracts.
    var discoveryItems: [FeedItem] {
        let terms = [
            "exoplanet", "planet", "black hole", "neutron star", "pulsar", "magnetar",
            "supernova", "super-nova", "stellar", "star ", "stars", "galaxy", "galaxies",
            "nebula", "cosmic", "universe", "dark matter", "dark energy", "gravitational",
            "quasar", "asteroid", "comet", "meteor", "moon", "mars", "jupiter", "saturn",
            "uranus", "neptune", "telescope", "jwst", "james webb", "hubble", "chandra",
            "euclid", "solar system", "interstellar", "milky way", "cosmology", "astronomy",
            "planetary", "solar flare", "solar wind", "gamma-ray", "fast radio burst"
        ]
        let excluded = [
            "invites media", "welcome home", "welcomes home", "join us", "public event",
            "media event", "watch live", "launch coverage", "press conference", "job opening",
            "procurement", "contract award", "student challenge", "application deadline",
            "registration open", "anniversary", "meeting of", "statement on"
        ]

        return items.filter { item in
            let headline = item.title.lowercased()
            if excluded.contains(where: headline.contains) { return false }
            if item.source.hasPrefix("arXiv") { return true }
            return terms.contains(where: headline.contains)
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errors = []
        successfulSources = []
        defer { isLoading = false }

        var collected: [FeedItem] = []
        for source in ObservatorySources.all {
            do {
                let loaded = try await service.load(source)
                collected.append(contentsOf: loaded)
                successfulSources.append("\(source.name) (\(loaded.count))")
            } catch {
                errors.append("\(source.name): \(error.localizedDescription)")
            }
        }

        // Never erase a previously loaded feed just because every publisher is temporarily down.
        if !successfulSources.isEmpty {
            var seen = Set<String>()
            items = collected
                .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
                .filter { seen.insert($0.id).inserted }
            lastUpdated = Date()
        }
    }
}

private final class RSSFeedService: NSObject, XMLParserDelegate {
    private var currentSource: FeedSource?
    private var parsed: [FeedItem] = []
    private var currentElement = ""
    private var title = ""
    private var summary = ""
    private var link = ""
    private var guid = ""
    private var pubDate = ""
    private var insideItem = false

    func load(_ source: FeedSource) async throws -> [FeedItem] {
        var request = URLRequest(url: source.url)
        request.timeoutInterval = 22
        request.setValue("SupernovaWatch/1.1 (iOS; astronomy research reader)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let first = data.first, first == 60 || first == 239 else {
            throw URLError(.cannotParseResponse)
        }
        let result = parse(data, source: source)
        guard !result.isEmpty else { throw URLError(.cannotParseResponse) }
        return result
    }

    private func parse(_ data: Data, source: FeedSource) -> [FeedItem] {
        currentSource = source
        parsed = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return parsed
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = (qName ?? elementName).lowercased()
        if currentElement == "item" || currentElement == "entry" {
            insideItem = true
            title = ""; summary = ""; link = ""; guid = ""; pubDate = ""
        }
        if currentElement == "link", let href = attributeDict["href"], !href.isEmpty {
            let rel = attributeDict["rel"]?.lowercased() ?? "alternate"
            if rel == "alternate" || link.isEmpty { link = href }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title": title += string
        case "description", "summary", "content:encoded", "content": summary += string
        case "link": link += string
        case "guid", "id": guid += string
        case "pubdate", "published", "updated", "dc:date": pubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = (qName ?? elementName).lowercased()
        if name == "item" || name == "entry" {
            insideItem = false
            guard let source = currentSource,
                  let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let cleanTitle = title.cleanedFeedText
            let cleanSummary = summary.cleanedFeedText
            let boilerplate = ["archive submissions index", "search calendar rss", "education about discuss",
                               "subscribe to our newsletter", "skip to main content"]
            let usefulSummary = boilerplate.contains(where: cleanSummary.lowercased().contains) ? "" : cleanSummary
            let rawDate = pubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = FeedDateParser.parse(rawDate)
            let identity = guid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? url.absoluteString : guid
            parsed.append(FeedItem(
                id: identity,
                title: cleanTitle,
                summary: String(usefulSummary.prefix(600)),
                link: url,
                source: source.name,
                published: date
            ))
        }
    }
}

private enum FeedDateParser {
    static func parse(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        return DateFormatter.rssDate.date(from: value)
    }
}

private extension DateFormatter {
    static let rssDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

private extension String {
    var cleanedFeedText: String {
        let noTags = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = noTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
