import SwiftUI
import BloxKit

enum MainTab: String, CaseIterable { case home = "Home", moments = "Moments", chat = "Chat", me = "Me" }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = MainTab.home
    @State private var menu = false
    @State private var path: [Page] = []        // pages pushed over the tabs
    @State private var profileOpen = false
    @State private var profileFull = false      // dragged up to fill the screen
    @State private var profileAtTop = true
    @GestureState private var profilePull: CGFloat = 0
    static let profileHalfTop: CGFloat = 311
    @GestureState private var menuPull: CGFloat = 0

    var body: some View {
        NavigationStack(path: $path) {
            tabs
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Page.self, destination: destination)
        }
    }

    @ViewBuilder
    private func destination(_ p: Page) -> some View {
        switch p {
        case .profile: EmptyView()
        case .fullProfile: FullProfileView(open: { open($0) }) { path.removeAll(); tab = .me }
        case .inventory: InventoryPage(open: { open($0) })
        case .favorites: FavoritesView(open: { open($0) })
        case .friends: FriendsListView()
        case .robux: RobuxPage(open: { open($0) })
        case .transactions: TransactionsPage()
        case .notifications: NotificationsPage()
        case .trades: TradesPage(open: { open($0) })
        case .trade(let id): TradePage(id: id)
        case .game(let game): GamePage(game: game)
        case .item(let item): ItemPage(item: item)
        case .chat(let friend): ChatPage(friendId: friend)
        }
    }

    private var tabs: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                ZStack {
                    kept(.home) { HomeView(openMenu: openMenu, open: { open($0) }) }
                    kept(.moments) { MomentsView() }
                    kept(.chat) { ChatList(open: { open($0) }) }
                    kept(.me) { AppearanceView(openMenu: openMenu, open: { open($0) }) }
                }
                .frame(maxHeight: .infinity)
                bar
            }
            if profileOpen {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeProfile)
                    .transition(.identity)
                profileSheet.transition(.move(edge: .bottom)).zIndex(1)
            }
            if menu {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeMenu)
                    .transition(.opacity)
                    .accessibilityIdentifier("menuShade")
                MenuView { p in
                    closeMenu()
                    open(p)
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
    }

    private func open(_ p: Page?) {
        guard let p else { return }
        if p == .profile {
            profileFull = false
            profileAtTop = true
            withAnimation(Self.sheetRise) { profileOpen = true }
        } else {
            if profileOpen { profileOpen = false }
            path.append(p)
        }
    }

    static let sheetRise = Animation.timingCurve(0.15, 0.85, 0.3, 1, duration: 0.22)
    static let sheetSettle = Animation.spring(response: 0.28, dampingFraction: 0.92)

    private func closeProfile() { withAnimation(.easeIn(duration: 0.18)) { profileOpen = false } }

    private var profileSheet: some View {
        GeometryReader { geo in
            let rest = profileFull ? 0 : geo.safeAreaInsets.top + Self.profileHalfTop
            ProfileView(full: profileFull, atTop: $profileAtTop, pulling: profilePull != 0, close: closeProfile, open: { open($0) }) {
                closeProfile()
                tab = .me
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            .padding(.top, max(rest + profilePull, 0))
            .ignoresSafeArea()
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .updating($profilePull) { g, pull, _ in
                        let down = g.translation.height > 0, vertical = abs(g.translation.height) > abs(g.translation.width)
                        if !profileFull { pull = vertical ? g.translation.height : 0 }
                        else if profileAtTop, down, vertical { pull = g.translation.height }
                    }
                    .onEnded { g in
                        guard abs(g.translation.height) > abs(g.translation.width) else { return }
                        let flick = g.predictedEndTranslation.height
                        if !profileFull {
                            if flick < -80 { withAnimation(Self.sheetSettle) { profileFull = true } }
                            else if flick > 140 { closeProfile() }
                        } else if profileAtTop, flick > 500 {
                            closeProfile()
                        } else if profileAtTop, flick > 120 {
                            withAnimation(Self.sheetSettle) { profileFull = false }
                        }
                    }
            )
            .animation(Self.sheetSettle, value: profilePull == 0)
        }
        .environmentObject(store)
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
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 5) {
                        icon(t).frame(height: 24)
                        Text(t.rawValue).font(.builder(10.5, .medium)).frame(height: 13)
                    }
                    .foregroundStyle(tab == t ? Color.ink : Color.faint)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tab-\(t.rawValue)")
            }
        }
        .padding(.horizontal, 5.5).padding(.top, 10).padding(.bottom, 0.5)
        .background(Color.bg)
    }

    @ViewBuilder
    private func icon(_ t: MainTab) -> some View {
        switch t {
        case .home: Icon("house", size: 24, filled: tab == t)
        case .moments: Icon("moments", size: 24, filled: tab == t)
        case .chat: Icon("speech-bubble-align-center", size: 24, filled: tab == t)
        case .me: Headshot(image: store.avatar, crop: store.profile.crop, size: 28)
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
        HStack(spacing: 0) {
            Button(action: openMenu) {
                Icon("three-bars-horizontal", size: 25)
                    .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
            }
            .accessibilityIdentifier("menuButton")
            Wordmark(size: 19.2).padding(.leading, 11)
            Spacer()
            Icon("magnifying-glass", size: 25).frame(width: 26)
            Button { open(.robux) } label: { Icon("robux", size: 26).frame(width: 26) }
                .accessibilityIdentifier("homeRobux").padding(.leading, 18.5)
            Button { open(.notifications) } label: {
                Icon("bell", size: 24).frame(width: 26)
                    .overlay(alignment: .topTrailing) { CountBubble(n: store.profile.notifications, size: 17).offset(x: 3, y: -4.5) }
            }
            .accessibilityIdentifier("homeBell").padding(.leading, 18.5)
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
                    Text(store.profile.displayName).font(.builder(20, .bold))
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
            if let failure { Text(failure).foregroundStyle(Color.faint).padding(.top, 12) }
            if !continueGames.isEmpty {
                section("Continue", chevron: true) { row(continueGames) }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
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
                ForEach(store.profile.friendList) { f in
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
            HStack(alignment: .top, spacing: 12) {
                ForEach(games) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g).frame(width: 194) }.buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
    }

    private func section<C: View>(_ title: String, chevron: Bool = false, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(title).font(.builder(20, .bold))
                if chevron { Icon("chevron-large-right", size: 20) }
            }
            .frame(height: 24)
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
                    row("hand-two-arrows-horizontal", "Trades", page: .trades)
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
            Button { open(.robux) } label: {
                HStack(spacing: 12) {
                    RobuxIcon(size: 20)
                    Text(grouped(store.profile.robux)).font(.builder(17, .bold)).accessibilityIdentifier("menuRobux")
                    Spacer()
                    Text("Buy Robux").font(.builder(14)).padding(.horizontal, 10).frame(height: 36)
                        .background(Color.field, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 14).frame(height: 66).contentShape(Rectangle())
            }
            .accessibilityIdentifier("menuBuyRobux")
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

struct FavoritesView: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    var body: some View {
        ScrollView {
            if store.profile.games.isEmpty {
                Text("No favorites yet. Open a game and tap Favorite.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(store.profile.games) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g) }.buttonStyle(PressStyle())
                }
            }
            .padding(20)
        }
        .page("Favorites")
    }
}

struct InventoryPage: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    var body: some View {
        ScrollView {
            if store.profile.items.isEmpty {
                Text("Your inventory is empty. Get items in the Marketplace.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top),
                                GridItem(.flexible(), alignment: .top)], spacing: 20) {
                ForEach(store.profile.items) { item in
                    Button { open(.item(item)) } label: { ItemCard(item: item) }
                        .buttonStyle(PressStyle()).accessibilityIdentifier("inventoryPageItem")
                }
            }
            .padding(.leading, 15).padding(.trailing, 14).padding(.top, 12)
        }
        .page("Inventory")
    }
}

struct FriendsListView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Friends (\(grouped(store.profile.friends)))").font(.builder(20, .bold)).padding(.vertical, 12)
                ForEach(store.profile.friendList) { f in
                    HStack(spacing: 12) {
                        RemoteCircle(url: f.headshot, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.displayName).font(.builder(16, .bold))
                            Text("@\(f.name)").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        Spacer()
                        if f.online { Circle().fill(Color.online).frame(width: 12, height: 12) }
                    }
                    .frame(height: 68)
                    Divider().overlay(Color.tile)
                }
            }
            .padding(.horizontal, 20)
        }
        .page("Friends")
    }
}
