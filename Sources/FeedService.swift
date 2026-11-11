import Foundation
import Combine

@MainActor
final class ObservatoryStore: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errors: [String] = []

    private let service = RSSFeedService()

    var supernovaItems: [FeedItem] {
        items.filter {
            let text = ($0.title + " " + $0.summary).lowercased()
            return ["supernova", "super-nova", "type ia", "type ii", "transient", "stellar explosion", "kilonova"]
                .contains(where: text.contains)
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
        currentElement = elementName.lowercased()
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
        case "description", "summary", "content:encoded": summary += string
        case "link": link += string
        case "guid", "id": guid += string
        case "pubdate", "published", "updated", "dc:date": pubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            insideItem = false
            guard let source = currentSource,
                  let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let rawDate = pubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = ISO8601DateFormatter().date(from: rawDate)
                ?? DateFormatter.rssDate.date(from: rawDate)
            let identity = guid.isEmpty ? url.absoluteString : guid
            parsed.append(FeedItem(
                id: identity,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: summary.strippingHTML,
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
    var strippingHTML: String {
        let noTags = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return noTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
