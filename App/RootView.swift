import SwiftUI
import BloxKit

enum MainTab: String, CaseIterable { case home = "Home", moments = "Moments", chat = "Chat", me = "Me" }

enum Page: String, Identifiable {
    case profile, favorites, friends, inventory
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = MainTab.home
    @State private var menu = false
    @State private var page: Page?
    @GestureState private var menuPull: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                ZStack {
                    kept(.home) { HomeView(openMenu: openMenu, open: { page = $0 }) }
                    kept(.moments) { MomentsView() }
                    kept(.chat) { ChatView() }
                    kept(.me) { AppearanceView(openMenu: openMenu, openProfile: { page = .profile }) }
                }
                .frame(maxHeight: .infinity)
                bar
            }
            if menu {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeMenu)
                    .transition(.opacity)
                    .accessibilityIdentifier("menuShade")
                MenuView { p in
                    closeMenu()
                    page = p
                }
                .offset(x: min(menuPull, 0))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .updating($menuPull) { g, pull, _ in
                            pull = abs(g.translation.width) > abs(g.translation.height) ? g.translation.width : 0
                        }
                        .onEnded { g in
                            if abs(g.translation.width) > abs(g.translation.height), g.predictedEndTranslation.width < -90 { closeMenu() }
                        }
                )
                .transition(.move(edge: .leading))
            }
        }
        .background(Color.bg)
        .fullScreenCover(item: $page) { p in
            NavigationStack {
                switch p {
                case .profile: ProfileView()
                case .inventory: FullProfileView().closeButton()
                case .favorites: FavoritesView().closeButton()
                case .friends: FriendsListView().closeButton()
                }
            }
            .environmentObject(store)
        }
    }

    private func openMenu() { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { menu = true } }
    private func closeMenu() { withAnimation(.spring(response: 0.3, dampingFraction: 0.92)) { menu = false } }

    private func kept<V: View>(_ t: MainTab, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .opacity(tab == t ? 1 : 0)
            .allowsHitTesting(tab == t)
            .accessibilityHidden(tab != t)
    }

    private var bar: some View {
        HStack {
            ForEach(MainTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 5) {
                        icon(t).frame(height: 30)
                        Text(t.rawValue).font(.builder(14, .medium))
                    }
                    .foregroundStyle(tab == t ? Color.white : Color.faint)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("tab-\(t.rawValue)")
            }
        }
        .padding(.top, 8)
        .background(Color.bg)
    }

    @ViewBuilder
    private func icon(_ t: MainTab) -> some View {
        switch t {
        case .home: Icon("house", size: 28, filled: tab == t)
        case .moments: Icon("moments", size: 28, filled: tab == t)
        case .chat: Icon("speech-bubble-align-center", size: 28, filled: tab == t)
        case .me: Headshot(image: store.avatar, crop: store.profile.crop, size: 30)
        }
    }
}

extension View {
    func closeButton() -> some View { modifier(CloseButton()) }
}

struct CloseButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityIdentifier("closePage")
            }
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var store: Store
    let openMenu: () -> Void
    let open: (Page) -> Void
    @State private var charts = false
    @State private var rows: [(title: String, games: [Game])] = []
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabs
            ScrollView {
                if charts { chartsList } else { forYou }
            }
            .refreshable { await load() }
        }
        .background(Color.bg)
        .task { if rows.isEmpty { await load() } }
    }

    private var topBar: some View {
        HStack(spacing: 22) {
            Button(action: openMenu) {
                Icon("three-bars-horizontal", size: 28)
                    .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 9, height: 9).offset(x: 5, y: -4) }
            }
            .accessibilityIdentifier("menuButton")
            Wordmark(size: 20).padding(.leading, -8)
            Spacer()
            Icon("magnifying-glass", size: 26)
            RobuxIcon(size: 22)
            Icon("bell", size: 26)
                .overlay(alignment: .topTrailing) { CountBubble(n: store.profile.notifications, size: 19).offset(x: 10, y: -10) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 14)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["For you", "Charts"], id: \.self) { t in
                let on = (t == "Charts") == charts
                Button { charts = t == "Charts" } label: {
                    VStack(spacing: 12) {
                        Text(t).font(.builder(16)).foregroundStyle(on ? .white : Color.faint)
                        Rectangle().fill(on ? Color.white : Color(white: 0.25)).frame(height: on ? 1.5 : 1)
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
                HStack(spacing: 14) {
                    Headshot(image: store.avatar, crop: store.profile.crop, size: 38)
                    Text(store.profile.displayName).font(.builder(21, .bold))
                }
            }
            .accessibilityIdentifier("homeName")
            .padding(.top, 22)
            friends.padding(.top, 22)
            section("Recommended For You") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 20) {
                    ForEach(recommended) { WideGameCard(game: $0).accessibilityIdentifier("homeGame") }
                }
            }
            if let failure { Text(failure).foregroundStyle(Color.faint).padding(.top, 12) }
            if !continueGames.isEmpty {
                section("Continue  ›") { row(continueGames) }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    private var friends: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                Button { open(.friends) } label: {
                    VStack(spacing: 8) {
                        Circle().fill(Color.field).frame(width: 112, height: 112)
                            .overlay(Icon("person-plus", size: 46))
                            .overlay(alignment: .topTrailing) { CountBubble(n: store.profile.requests, size: 22).offset(x: -4, y: 6) }
                        Text("Add Friends").font(.builder(14, .semibold))
                    }
                    .frame(width: 114)
                }
                ForEach(store.profile.friendList) { f in
                    VStack(spacing: 2) {
                        RemoteCircle(url: f.headshot, size: 112)
                            .overlay(alignment: .bottomTrailing) {
                                if f.online {
                                    Circle().fill(Color.green).frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(Color.bg, lineWidth: 3)).offset(x: -6, y: -6)
                                }
                            }
                        Text(f.displayName).font(.builder(14, .semibold)).lineLimit(1).padding(.top, 6)
                        if !f.status.isEmpty { Text(f.status).font(.builder(13)).foregroundStyle(Color.faint).lineLimit(1) }
                    }
                    .frame(width: 114)
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
            if let failure { Text(failure).foregroundStyle(Color.faint).padding(.top, 20) }
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    private func row(_ games: [Game]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) { ForEach(games) { WideGameCard(game: $0).frame(width: 180) } }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.builder(22, .bold))
            content()
        }
        .padding(.top, 30)
    }

    private var recommended: [Game] {
        Array((rows.first { $0.title == "Top Playing Now" } ?? rows.first)?.games.prefix(6) ?? [])
    }
    private var continueGames: [Game] {
        store.profile.games.isEmpty ? Array(rows.first { $0.title == "Top Revisited" }?.games.prefix(8) ?? []) : store.profile.games
    }

    private func load() async {
        failure = nil
        do {
            rows = try await Roblox.home()
            if rows.isEmpty { failure = "Roblox sent nothing to show." }
        } catch {
            failure = error.localizedDescription
        }
    }
}

// MARK: - Menu

struct MenuView: View {
    @EnvironmentObject var store: Store
    let open: (Page?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button { open(.profile) } label: {
                    HStack(spacing: 18) {
                        Headshot(image: store.avatar, crop: store.profile.crop, size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.profile.displayName).font(.builder(17, .bold))
                            Text("@\(store.profile.username)").font(.builder(16)).foregroundStyle(Color(white: 0.85))
                        }
                    }
                }
                .accessibilityIdentifier("menuProfile")
                .padding(.top, 10)
                robuxCard.padding(.top, 14)
                VStack(alignment: .leading, spacing: 0) {
                    row("bookmark", "Favorites", page: .favorites)
                    row("clock-spin-reverse", "Continue Playing")
                    row("two-people", "Friends", count: store.profile.friendsBadge, page: .friends)
                    row("three-people", "Communities")
                    row("backpack", "Inventory", page: .inventory)
                    row("hand-two-arrows-horizontal", "Trades")
                    row("envelope", "Messages", count: store.profile.messages)
                    row("roblox-plus", "Roblox Plus")
                    row("gear", "Settings")
                    row("shield-lock", "Help & Safety")
                    Divider().overlay(Color(white: 0.25)).padding(.vertical, 8)
                    row("moments", "Moments")
                    row("person-graduate", "Learn")
                    row("studio", "Create")
                }
                .padding(.top, 14)
                Text("Switch Accounts").font(.builder(17)).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 14).padding(.bottom, 20)
            }
            .padding(.horizontal, 18)
        }
        .containerRelativeFrame(.horizontal) { w, _ in w * 0.8 }
        .background(Color(red: 0.06, green: 0.065, blue: 0.08).ignoresSafeArea())
        .foregroundStyle(.white)
    }

    private var robuxCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RobuxIcon(size: 20)
                Text(grouped(store.profile.robux)).font(.builder(17, .bold)).accessibilityIdentifier("menuRobux")
                Spacer()
                Text("Buy Robux").font(.builder(14)).padding(.horizontal, 10).frame(height: 36)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 14).frame(height: 66)
            Divider().overlay(Color(white: 0.25))
            HStack(spacing: 18) {
                Icon("roblox-plus", size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("More fun for less Robux.")
                    Text("Subscribe to Roblox Plus.")
                }
                .font(.builder(13))
                Spacer()
                Icon("chevron-large-right", size: 20)
            }
            .padding(.horizontal, 14).frame(height: 64)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.25), lineWidth: 1))
    }

    private func row(_ icon: String, _ title: String, count: Int = 0, page: Page? = nil) -> some View {
        Button { if page != nil { open(page) } } label: {
            HStack(spacing: 22) {
                Icon(icon, size: 24).frame(width: 26)
                Text(title).font(.builder(17, .bold))
                Spacer()
                CountBubble(n: count, size: 22)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("menu-\(title)")
    }
}

// MARK: - Simple pages

struct MomentsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Icon("moments", size: 60)
            Text("Moments").font(.builder(22, .bold))
            Text("Short clips from experiences show up here.").foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}

struct ChatView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        NavigationStack {
            List {
                if store.profile.friendList.isEmpty {
                    Text("Add friends in Edit profile and they show up here.").foregroundStyle(Color.faint)
                }
                ForEach(store.profile.friendList) { f in
                    HStack(spacing: 14) {
                        RemoteCircle(url: f.headshot, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.displayName).font(.builder(17, .semibold))
                            Text(f.status.isEmpty ? (f.online ? "Online" : "Offline") : f.status)
                                .font(.builder(14)).foregroundStyle(Color.faint).lineLimit(1)
                        }
                    }
                    .listRowBackground(Color.bg)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Chat")
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView {
            if store.profile.games.isEmpty {
                Text("No favorites yet. Add games in Edit profile.").foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 20) {
                ForEach(store.profile.games) { WideGameCard(game: $0) }
            }
            .padding(20)
        }
        .background(Color.bg)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FriendsListView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        List {
            Section { Text("\(grouped(store.profile.friends)) Friends").font(.builder(17, .semibold)) }
            ForEach(store.profile.friendList) { f in
                HStack(spacing: 14) {
                    RemoteCircle(url: f.headshot, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.displayName).font(.builder(17, .semibold))
                        Text("@\(f.name)").font(.builder(14)).foregroundStyle(Color.faint)
                    }
                    Spacer()
                    if f.online { Circle().fill(Color.green).frame(width: 12, height: 12) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
}
