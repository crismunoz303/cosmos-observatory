# Supernova Watch

A native SwiftUI iPhone app for monitoring verified supernova-related reporting and broader space discoveries.

## Scope
- Betelgeuse watch page: scientific context and clear separation between published observations and unconnected monitoring.
- Supernova feed: keyword-filtered items from configured astronomy news sources.
- Space discoveries: broader astronomy and space-science updates.
- Source transparency: each feed item links to its publisher.
- No fabricated alerts, predictions, photometry, or live status claims.

## Build
This repository uses XcodeGen. Install it, then run:

```sh
xcodegen generate
xcodebuild -project SupernovaWatch.xcodeproj -scheme SupernovaWatch -destination 'generic/platform=iOS' build
```

## Unsigned IPA
GitHub Actions builds an unsigned IPA on a macOS runner and uploads it as the `SupernovaWatch-unsigned-ipa` workflow artifact. The IPA is not signed for direct installation; use your sideloading tool to sign/install it.

## Data sources
- NASA RSS feeds (official): https://www.nasa.gov/rss-feeds/
- ESA RSS feeds (official): https://www.esa.int/Services/RSS_Feeds
- Transient Name Server: https://www.wis-tns.org/
- AAVSO: https://www.aavso.org/

The initial build consumes NASA and ESA public RSS feeds. TNS and AAVSO are listed as authoritative specialist sources but are not represented as live-integrated services yet.
