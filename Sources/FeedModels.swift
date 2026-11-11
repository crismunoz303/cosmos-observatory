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
            url: URL(string: "https://science.nasa.gov/feed/?science_org=19791%2C22453")!,
            category: "Official science results"
        ),
        FeedSource(
            id: "esa-science",
            name: "ESA Science",
            url: URL(string: "https://www.esa.int/rss/science.rss")!,
            category: "Official European space-science results"
        ),
        FeedSource(
            id: "arxiv-he",
            name: "arXiv · High-Energy Astrophysics",
            url: URL(string: "https://export.arxiv.org/rss/astro-ph.HE")!,
            category: "Research preprints"
        ),
        FeedSource(
            id: "arxiv-sr",
            name: "arXiv · Solar & Stellar Physics",
            url: URL(string: "https://export.arxiv.org/rss/astro-ph.SR")!,
            category: "Research preprints"
        ),
        FeedSource(
            id: "arxiv-ep",
            name: "arXiv · Exoplanets & Planetary Science",
            url: URL(string: "https://export.arxiv.org/rss/astro-ph.EP")!,
            category: "Research preprints"
        ),
        FeedSource(
            id: "arxiv-ga",
            name: "arXiv · Galaxies",
            url: URL(string: "https://export.arxiv.org/rss/astro-ph.GA")!,
            category: "Research preprints"
        ),
        FeedSource(
            id: "arxiv-co",
            name: "arXiv · Cosmology",
            url: URL(string: "https://export.arxiv.org/rss/astro-ph.CO")!,
            category: "Research preprints"
        )
    ]

    static let specialist = [
        ("Transient Name Server", "https://www.wis-tns.org/", "Professional supernova and transient reporting"),
        ("AAVSO", "https://www.aavso.org/", "Variable-star observations and community photometry"),
        ("NASA ADS", "https://ui.adsabs.harvard.edu/", "Peer-reviewed astronomy literature"),
        ("AAS Nova", "https://aasnova.org/", "Highlights of research published in AAS journals")
    ]
}
