import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ObservatoryStore
    @State private var selected: ObservatoryTab = .watch

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch selected {
                    case .watch: WatchScreen()
                    case .supernovae: FeedScreen(title: "Supernova Watch", subtitle: "Reported supernovae and stellar transients", items: store.supernovaItems, empty: "No matching supernova reports in the connected feeds yet.")
                    case .discoveries: FeedScreen(title: "Space Discoveries", subtitle: "New science from NASA and ESA", items: store.items, empty: "No feed items loaded. Pull to refresh.")
                    case .sources: SourcesScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }
        }
        .task { await store.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SUPERNOVA").font(.system(size: 11, weight: .black, design: .rounded)).tracking(3).foregroundStyle(Color.red.opacity(0.95))
                Text("WATCH").font(.system(size: 27, weight: .bold, design: .rounded)).tracking(1.2)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .disabled(store.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ObservatoryTab.allCases) { tab in
                Button { selected = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol).font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selected == tab ? Color.red : Color.white.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
            }
        }
        .background(Color(red: 0.055, green: 0.07, blue: 0.10))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }
}

struct WatchScreen: View {
    @EnvironmentObject private var store: ObservatoryStore
    @State private var selectedLayer = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(
                        RadialGradient(colors: [Color.red.opacity(0.30), Color(red: 0.10, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.06, blue: 0.09)], center: .center, startRadius: 8, endRadius: 250)
                    )
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Label("PRIMARY WATCH", systemImage: "scope")
                                .font(.system(size: 10, weight: .bold)).tracking(1.8).foregroundStyle(.red.opacity(0.95))
                            Spacer()
                            Text("ALPHA ORIONIS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                        }
                        HStack(alignment: .center, spacing: 18) {
                            ZStack {
                                Circle().fill(Color.orange.opacity(0.12)).frame(width: 112, height: 112)
                                Circle().fill(RadialGradient(colors: [.yellow.opacity(0.95), .orange, .red.opacity(0.7), .clear], center: .center, startRadius: 3, endRadius: 55)).frame(width: 88, height: 88).blur(radius: 1)
                                Circle().stroke(Color.orange.opacity(0.35), lineWidth: 1).frame(width: 108, height: 108)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("BETELGEUSE").font(.system(size: 21, weight: .black, design: .rounded)).tracking(0.5)
                                Text("Red supergiant • Orion").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                                Text("~550 light-years").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.orange.opacity(0.9))
                            }
                        }
                        Text("A nearby massive star in a late evolutionary phase. Its exact remaining lifetime is not predictable from current observations.")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                }
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.red.opacity(0.22), lineWidth: 1))

                HStack(spacing: 10) {
                    StatusTile(label: "LIVE ALERTS", value: "NOT CONNECTED", color: .orange)
                    StatusTile(label: "FEED ITEMS", value: "\(store.items.count)", color: .cyan)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "WHAT WE KNOW", caption: "FACTS VS. OPEN QUESTIONS")
                    Text("Betelgeuse is a variable red supergiant. Its brightness changes naturally. A sudden change in brightness alone would not prove an imminent supernova.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.78))
                    Picker("Star layers", selection: $selectedLayer) {
                        Text("Core").tag(0)
                        Text("Envelope").tag(1)
                        Text("Future").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Group {
                        if selectedLayer == 0 {
                            LayerDetail(title: "FUSION CORE", detail: "The star's deep interior is inaccessible to direct optical observation. Late-stage nuclear burning models inform what astronomers expect, but the core is not continuously imaged.")
                        } else if selectedLayer == 1 {
                            LayerDetail(title: "EXTENDED ENVELOPE", detail: "Betelgeuse has a vast, dynamic atmosphere with convection, pulsation, and mass loss. These processes contribute to its changing appearance and brightness.")
                        } else {
                            LayerDetail(title: "SUPERNOVA", detail: "When Betelgeuse eventually undergoes core collapse, it will become a supernova. No reliable countdown or precise date is known.")
                        }
                    }
                }
                .padding(16).cardStyle()

                VStack(alignment: .leading, spacing: 9) {
                    SectionHeading(title: "LATEST SUPERNOVA REPORTS", caption: "FILTERED FROM CONNECTED PUBLISHERS")
                    if store.supernovaItems.isEmpty {
                        Text("No matching reports in the currently connected feeds. This is not evidence that no supernovae have occurred.")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.62))
                    } else {
                        ForEach(store.supernovaItems.prefix(3)) { item in
                            FeedRow(item: item)
                        }
                    }
                }
                .padding(16).cardStyle()

                if let date = store.lastUpdated {
                    Text("Feeds last checked \(date.formatted(date: .omitted, time: .shortened)). RSS updates are publisher-dependent.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(16)
        }
        .refreshable { await store.refresh() }
    }
}

struct FeedScreen: View {
    let title: String
    let subtitle: String
    let items: [FeedItem]
    let empty: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
                if items.isEmpty {
                    Text(empty).font(.system(size: 13)).foregroundStyle(.white.opacity(0.62)).padding(16).cardStyle()
                } else {
                    ForEach(items) { item in FeedRow(item: item) }
                }
            }
            .padding(16)
        }
    }
}

struct SourcesScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SOURCE REGISTER").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Feeds are distinguished from specialist databases. A source being listed does not mean its data is integrated.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.62))
                ForEach(ObservatorySources.all) { source in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.name).font(.system(size: 15, weight: .bold))
                        Text(source.category).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        Text(source.url.absoluteString).font(.system(size: 9, design: .monospaced)).foregroundStyle(.cyan)
                    }.padding(14).cardStyle()
                }
                SectionHeading(title: "SPECIALIST REFERENCE PORTALS", caption: "NOT YET API-INTEGRATED")
                ForEach(ObservatorySources.specialist, id: \.0) { source in
                    Link(destination: URL(string: source.1)!) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(source.0).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            Text(source.2).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).cardStyle()
                    }
                }
            }.padding(16)
        }
    }
}

struct FeedRow: View {
    let item: FeedItem
    var body: some View {
        Link(destination: item.link) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.source.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.red)
                    Spacer()
                    if let date = item.published {
                        Text(date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.42))
                    }
                }
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                if !item.summary.isEmpty {
                    Text(item.summary).font(.system(size: 11)).foregroundStyle(.white.opacity(0.58)).lineLimit(3)
                }
                HStack {
                    Text("OPEN ORIGINAL SOURCE").font(.system(size: 9, weight: .bold)).tracking(0.8)
                    Image(systemName: "arrow.up.right").font(.system(size: 9))
                }.foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).cardStyle()
        }
    }
}

struct StatusTile: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(13).cardStyle()
    }
}

struct SectionHeading: View {
    let title: String
    let caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .black, design: .rounded)).tracking(1)
            Text(caption).font(.system(size: 9, weight: .medium)).tracking(1.1).foregroundStyle(.white.opacity(0.42))
        }
    }
}

struct LayerDetail: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)
            Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    func cardStyle() -> some View {
        self.background(Color(red: 0.065, green: 0.08, blue: 0.11), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.075), lineWidth: 1))
    }
}
