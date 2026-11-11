import Foundation

struct FeedItem: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let link: URL
    let source: String
    let published: Date?
}

struct FeedSource: Identifiable {
    let id: String
    let name: String
    let url: URL
    let category: String
}

enum ObservatoryTab: String, CaseIterable, Identifiable {
    case watch = "Watch"
    case supernovae = "Supernovae"
    case discoveries = "Discoveries"
    case sources = "Sources"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .watch: return "sparkles"
        case .supernovae: return "sun.max.trianglebadge.exclamationmark"
        case .discoveries: return "scope"
        case .sources: return "checkmark.seal"
        }
    }
}

enum ObservatorySources {
    static let all: [FeedSource] = [
        FeedSource(
            id: "nasa-science",
            name: "NASA Science",
            url: URL(string: "https://science.nasa.gov/feed/")!,
            category: "Space science"
        ),
        FeedSource(
            id: "nasa-news",
            name: "NASA News",
            url: URL(string: "https://www.nasa.gov/news-release/feed/")!,
            category: "Agency news"
        ),
        FeedSource(
            id: "esa-space",
            name: "ESA Space News",
            url: URL(string: "https://www.esa.int/rssfeed/Our_Activities/Space_News")!,
            category: "European space science"
        )
    ]

    static let specialist = [
        ("Transient Name Server", "https://www.wis-tns.org/", "Professional supernova and transient reporting"),
        ("AAVSO", "https://www.aavso.org/", "Variable-star observations and community photometry"),
        ("NASA ADS", "https://ui.adsabs.harvard.edu/", "Peer-reviewed astronomy literature")
    ]
}
