import SwiftUI
import SalBloxKit

struct HomeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var phase
    let openMenu: () -> Void
    let open: (Page) -> Void
    @State private var charts = false
    @State private var rows: [(title: String, games: [Game])] = []
    @State private var failure: String?
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabs
            ScrollView {
                if charts { chartsList } else { forYou }
            }
            .refreshable { await load(tries: 1) }
        }
        .background(Color.bg)
        .task { if rows.isEmpty { await load() } }
        .onChange(of: phase) { _, now in
            if now == .active, rows.isEmpty, !loading { Task { await load() } }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: openMenu) {
                Icon("three-bars-horizontal", size: 25)
                    .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
            }
            .accessibilityIdentifier("menuButton").accessibilityLabel("Menu")
            Wordmark(size: 19.2).padding(.leading, 11)
            Spacer()
            Button { open(.search) } label: { Icon("magnifying-glass", size: 25).frame(width: 26) }
                .accessibilityIdentifier("homeSearch").accessibilityLabel("Search")
            Button { open(.robux) } label: { Icon("robux", size: 26).frame(width: 26) }
                .accessibilityIdentifier("homeRobux").accessibilityLabel("Robux").padding(.leading, 18.5)
            Button { open(.notifications) } label: {
                Icon("bell", size: 24).frame(width: 26)
                    .overlay(alignment: .topLeading) { CountBubble(n: store.profile.notifications, size: 17).fixedSize().offset(x: 11.5, y: -4.5) }
            }
            .accessibilityIdentifier("homeBell").accessibilityLabel("Notifications, \(store.profile.notifications) new")
            .padding(.leading, 18.5)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 28)
        .padding(.leading, 20).padding(.trailing, 22).padding(.top, 6).padding(.bottom, 29)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["For you", "Charts"], id: \.self) { t in
                let on = (t == "Charts") == charts
                Button { charts = t == "Charts" } label: {
                    VStack(spacing: 14) {
                        Text(t).font(.builder(14.5)).frame(height: 18).foregroundStyle(Color.faint)
                        Rectangle().fill(on ? Color.ink : Color.tile).frame(height: 1)
                    }
                }
                .accessibilityIdentifier("home-\(t)")
            }
        }
        .padding(.horizontal, 20)
    }

    private var forYou: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { open(.profile) } label: {
                HStack(spacing: 12) {
                    Headshot(image: store.avatar, crop: store.profile.crop, size: 36)
                    Text(store.profile.shownName).font(.builder(20, .bold)).lineLimit(1)
                }
            }
            .accessibilityIdentifier("homeName")
            .padding(.top, 24)
            friends.padding(.top, 25).padding(.bottom, 3.5)
            section("Recommended For You") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                    ForEach(recommended) { g in
                        Button { open(.game(g)) } label: { WideGameCard(game: g) }
                            .buttonStyle(PressStyle()).accessibilityIdentifier("homeGame")
                    }
                }
            }
            status
            if !continueGames.isEmpty {
                section("Continue", page: .continuePlaying) { row(continueGames) }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    @ViewBuilder
    private var status: some View {
        if rows.isEmpty, loading {
            ProgressView().tint(Color.faint).frame(maxWidth: .infinity).padding(.top, 20)
        } else if rows.isEmpty, let failure {
            Text(failure).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 12).accessibilityIdentifier("homeFailure")
        }
    }

    private var friends: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10.5) {
                Button { open(.friends) } label: {
                    VStack(spacing: 0) {
                        Circle().fill(Color.tile).frame(width: 113, height: 113)
                            .overlay(Icon("person-plus", size: 46))
                            .overlay(alignment: .topTrailing) { CountBubble(n: store.profile.requests, size: 16).offset(x: -4, y: 8) }
                        Text("Add Friends").font(.builder(12, .bold)).frame(height: 15).padding(.top, 8.5)
                        Text(" ").font(.builder(12)).frame(height: 15)
                    }
                    .foregroundStyle(Color.faint)
                    .frame(width: 113)
                }
                .accessibilityIdentifier("homeAddFriends")
                ForEach(store.profile.friendList) { f in
                    Button { open(.friend(f.id)) } label: {
                        VStack(spacing: 0) {
                            RemoteCircle(url: f.headshot, size: 113)
                                .overlay(alignment: .bottomTrailing) {
                                    if f.online {
                                        Circle().fill(Color.bg).frame(width: 23, height: 23)
                                            .overlay(Circle().fill(Color.online).frame(width: 17, height: 17)).offset(x: -2.5, y: -2.5)
                                    }
                                }
                            Text(f.displayName).font(.builder(12, .bold)).lineLimit(1).frame(height: 15).padding(.top, 8.5)
                            Text(f.status.isEmpty ? " " : f.status).font(.builder(12)).lineLimit(1).frame(height: 15)
                        }
                        .foregroundStyle(Color.faint)
                        .frame(width: 113)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("homeFriend")
                }
            }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
    }

    private var chartsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                section(rows[i].title) { row(rows[i].games) }
            }
            status
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    private func row(_ games: [Game]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(games) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g).frame(width: 194) }.buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
    }

    private func section<C: View>(_ title: String, page: Page? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { if let page { open(page) } } label: {
                HStack(spacing: 8) {
                    Text(title).font(.builder(20, .bold))
                    if page != nil { Icon("chevron-large-right", size: 20) }
                }
                .frame(height: 24)
            }
            .buttonStyle(PressStyle())
            .allowsHitTesting(page != nil)
            content()
        }
        .padding(.top, 27)
    }

    private var recommended: [Game] {
        Array((rows.first { $0.title == "Top Playing Now" } ?? rows.first)?.games.prefix(4) ?? [])
    }
    private var continueGames: [Game] {
        store.profile.games.isEmpty ? Array(rows.first { $0.title == "Top Revisited" }?.games.prefix(8) ?? []) : store.profile.games
    }

    private func load(tries: Int = 4) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        for (attempt, pause) in [0, 2, 5, 10].prefix(tries).enumerated() {
            if attempt > 0 { try? await Task.sleep(for: .seconds(pause)) }
            do {
                let got = try await Roblox.home()
                if !got.isEmpty {
                    rows = got
                    failure = nil
                    return
                }
                failure = "Roblox sent nothing to show."
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

// MARK: - Menu
