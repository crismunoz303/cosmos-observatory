import Foundation

@MainActor
final class ObservatoryStore: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errors: [String] = []

    private let service = RSSFeedService()

    // Supernovae are separated from general astronomy discoveries.
    var supernovaItems: [FeedItem] {
        items.filter {
            let text = ($0.title + " " + $0.summary).lowercased()
            return ["supernova", "super-nova", "type ia", "type ii", "type ib", "type ic",
                    "stellar explosion", "core-collapse", "kilonova", "superluminous"]
                .contains(where: text.contains)
        }
    }

    // Only retain stories with an actual science/astronomy subject.
    // Routine agency announcements and unrelated Earth/administrative news are excluded.
    var discoveryItems: [FeedItem] {
        let scienceTerms = [
            "exoplanet", "planet", "black hole", "neutron star", "pulsar", "magnetar",
            "supernova", "super-nova", "star", "stellar", "galaxy", "galaxies",
            "nebula", "cosmic", "universe", "dark matter", "dark energy", "gravitational wave",
            "gravitational lens", "quasar", "asteroid", "comet", "meteor", "moon",
            "mars", "jupiter", "saturn", "uranus", "neptune", "telescope", "jwst",
            "james webb", "hubble", "chandra", "euclid", "ariel", "planetary science",
            "solar system", "interstellar", "milky way", "cosmology", "astronomer"
        ]
        let announcementTerms = [
            "invites media", "welcome home", "welcomes home", "join us", "public event",
            "media event", "watch live", "launch coverage", "launching today",
            "press conference", "administrator", "headquarters", "job opening",
            "procurement", "contract award", "student challenge", "application deadline",
            "registration open", "celebration", "commemorate", "anniversary"
        ]

        return items.filter { item in
            let title = item.title.lowercased()
            let text = (item.title + " " + item.summary).lowercased()
            guard scienceTerms.contains(where: text.contains) else { return false }
            // A science keyword in boilerplate copy is not enough: reject obvious event/admin headlines.
            if announcementTerms.contains(where: title.contains) { return false }
            if item.summary.lowercased().contains("today's apod archive submissions index") { return false }
            return true
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errors = []
        defer { isLoading = false }

        var collected: [FeedItem] = []
        for source in ObservatorySources.all {
            do {
                collected.append(contentsOf: try await service.load(source))
            } catch {
                errors.append("\(source.name): \(error.localizedDescription)")
            }
        }

        var seen = Set<String>()
        items = collected
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
            .filter { seen.insert($0.id).inserted }
        lastUpdated = Date()
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
        request.timeoutInterval = 18
        request.setValue("SupernovaWatch/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return parse(data, source: source)
    }

    private func parse(_ data: Data, source: FeedSource) -> [FeedItem] {
        currentSource = source
        parsed = []
        let parser = XMLParser(data: data)
        parser.delegate = self
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
            link = href
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
            // RSS descriptions sometimes contain site navigation, archive links, and footer copy.
            // Do not show those fragments as if they were article summaries.
            let boilerplate = ["archive submissions index", "search calendar rss", "education about discuss",
                               "astronomy picture of the day", "subscribe to our newsletter"]
            let usefulSummary = boilerplate.contains(where: cleanSummary.lowercased().contains) ? "" : cleanSummary
            let rawDate = pubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = ISO8601DateFormatter().date(from: rawDate)
                ?? DateFormatter.rssDate.date(from: rawDate)
            let identity = guid.isEmpty ? url.absoluteString : guid
            parsed.append(FeedItem(
                id: identity,
                title: cleanTitle,
                summary: String(usefulSummary.prefix(420)),
                link: url,
                source: source.name,
                published: date
            ))
        }
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
