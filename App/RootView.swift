import SwiftUI
import BloxKit

enum MainTab: String, CaseIterable { case home = "Home", moments = "Moments", chat = "Chat", me = "Me" }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = MainTab.home
    @State private var menu = false
    @State private var path: [Page] = []        // pages pushed over the tabs
    @State private var settings = false
    @State private var robux = false
    @State private var game: Game?
    @State private var item: Item?
    @State private var friend: Int64?
    static let friendTop: CGFloat = 353
    @State private var profileOpen = false
    @State private var profileFull = false      // dragged up to fill the screen
    @State private var profileAtTop = true
    @GestureState private var profilePull: CGFloat = 0
    static let profileHalfTop: CGFloat = 311
    @GestureState private var menuPull: CGFloat = 0

    static let gameTop: CGFloat = 335

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                tabs
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Page.self, destination: destination)
            }
            if let g = game {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeGame)
                    .transition(.identity)
                    .accessibilityIdentifier("closeGame").accessibilityLabel("Close game").accessibilityAddTraits(.isButton)
                GamePage(game: g, close: closeGame, open: { open($0) })
                    .id(g.id)
                    .padding(.top, Self.gameTop)
                    .transition(.move(edge: .bottom)).zIndex(1)
            }
        }
        .sheet(isPresented: $settings) { EditProfileView() }
        .fullScreenCover(isPresented: $robux) { NavigationStack { RobuxPage { robux = false } } }
        .fullScreenCover(item: $item) { it in
            NavigationStack {
                ItemPage(item: it, close: { item = nil }, open: openAfterItem)
                    .navigationDestination(for: Item.self) { ItemPage(item: $0, close: { item = nil }, isRoot: false, open: openAfterItem) }
            }
        }
        .task { await store.refreshSaved() }
    }

    @ViewBuilder
    private func destination(_ p: Page) -> some View {
        switch p {
        case .profile, .settings, .momentsTab, .robux, .game, .item: EmptyView()
        case .fullProfile: FullProfileView(open: { open($0) }) { path.removeAll(); profileOpen = false; tab = .me }
        case .inventory: InventoryPage(open: { open($0) })
        case .favorites: GamesPage(title: "Favorites", games: store.profile.games, empty: "No favorites yet. Open a game and tap Favorite.", open: { open($0) })
        case .continuePlaying: GamesPage(title: "Continue Playing", games: store.profile.games, empty: "Games you favorite show up here.", open: { open($0) })
        case .friends: FriendsListView(open: { open($0) })
        case .friend(let id), .person(let id): FriendPage(id: id, open: { open($0) })
        case .transactions: TransactionsPage()
        case .notifications: NotificationsPage()
        case .trades: TradesPage(open: { open($0) })
        case .trade(let id): TradePage(id: id)
        case .chat(let friend): ChatPage(friendId: friend)
        case .search: SearchPage(open: { open($0) })
        case .info(let kind): InfoPage(kind: kind)
        }
    }

    private var tabs: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                ZStack {
                    kept(.home) { HomeView(openMenu: openMenu, open: { open($0) }) }
                    kept(.moments) { MomentsView() }
                    kept(.chat) { ChatList(openMenu: openMenu, open: { open($0) }) }
                    kept(.me) { AppearanceView(active: tab == .me, openMenu: openMenu, open: { open($0) }) }
                }
                .frame(maxHeight: .infinity)
                bar
            }
            if let id = friend {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeFriend)
                    .transition(.identity)
                    .accessibilityIdentifier("closeFriend").accessibilityLabel("Close").accessibilityAddTraits(.isButton)
                    .zIndex(1.5)
                FriendSheet(id: id, close: closeFriend, open: { open($0) })
                    .id(id)
                    .padding(.top, Self.friendTop)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom)).zIndex(1.6)
            }
            if profileOpen {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeProfile)
                    .transition(.identity)
                    .accessibilityLabel("Close profile")
                profileSheet.transition(.move(edge: .bottom)).zIndex(1)
            }
            if menu {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: closeMenu)
                    .transition(.opacity)
                    .accessibilityIdentifier("menuShade")
                    .accessibilityLabel("Close menu")
                MenuView { p in
                    closeMenu()
                    open(p)
                }
                .offset(x: min(menuPull, 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: menuPull == 0)   // a short drag springs back
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
                .zIndex(2)
            }
        }
        .background(Color.bg)
    }

    private func open(_ p: Page?) {
        guard let p else { return }
        switch p {
        case .profile:
            profileFull = false
            profileAtTop = true
            withAnimation(Self.sheetRise) { profileOpen = true }
        case .settings:
            settings = true
        case .robux:
            robux = true
        case .game(let g):
            withAnimation(Self.sheetRise) { game = g }
        case .item(let i):
            item = i
        case .friend(let id) where path.isEmpty:
            withAnimation(Self.sheetRise) { friend = id }
        case .friend(let id):
            path.append(.person(id))
        case .momentsTab:
            profileOpen = false
            tab = .moments
        default:
            path.append(p)
        }
    }

    static let sheetRise = Animation.timingCurve(0.15, 0.85, 0.3, 1, duration: 0.22)
    static let sheetSettle = Animation.spring(response: 0.28, dampingFraction: 0.92)

    private func openAfterItem(_ p: Page) {
        item = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            open(p)
        }
    }

    private func closeFriend() { withAnimation(.easeIn(duration: 0.18)) { friend = nil } }

    private func closeGame() { withAnimation(.easeIn(duration: 0.18)) { game = nil } }

    private func closeProfile() { withAnimation(.easeIn(duration: 0.18)) { profileOpen = false } }

    private var profileSheet: some View {
        GeometryReader { geo in
            let rest = profileFull ? 0 : geo.safeAreaInsets.top + Self.profileHalfTop
            ProfileView(full: profileFull, statusBar: geo.safeAreaInsets.top, atTop: $profileAtTop, pulling: profilePull != 0,
                        close: closeProfile, open: { open($0) }) {
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
                .accessibilityLabel(t.rawValue)
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
                            Text(store.profile.shownName).font(.builder(14.6, .bold)).lineLimit(1)
                            Text("@\(store.profile.shownUsername)").font(.builder(14.4)).foregroundStyle(Color(white: 0.85)).lineLimit(1)
                        }
                    }
                }
                .accessibilityIdentifier("menuProfile")
                .padding(.top, 10)
                robuxCard.padding(.top, 14)
                VStack(alignment: .leading, spacing: 0) {
                    row("bookmark", "Favorites", page: .favorites)
                    row("clock-spin-reverse", "Continue Playing", page: .continuePlaying)
                    row("two-people", "Friends", count: store.profile.friendsBadge, page: .friends)
                    row("three-people", "Communities", page: .info(.communities))
                    row("backpack", "Inventory", page: .inventory)
                    row("hand-two-arrows-horizontal", "Trades", page: .trades)
                    row("envelope", "Messages", count: store.profile.messages, page: .info(.messages))
                    row("roblox-plus", "Roblox Plus", page: .info(.plus))
                    row("gear", "Settings", page: .settings)
                    row("shield-lock", "Help & Safety", page: .info(.help))
                    Divider().overlay(Color(white: 0.25)).padding(.vertical, 8)
                    row("moments", "Moments", page: .momentsTab)
                    row("person-graduate", "Learn", page: .info(.learn))
                    row("studio", "Create", page: .info(.create))
                }
                .padding(.top, 14)
                Button { open(.info(.accounts)) } label: {
                    Text("Switch Accounts").font(.builder(16)).frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("menu-Switch Accounts")
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
                    Text(grouped(store.profile.robux)).font(.builder(15, .bold)).accessibilityIdentifier("menuRobux")
                    Spacer()
                    Text("Buy Robux").font(.builder(14)).padding(.horizontal, 10).frame(height: 36)
                        .background(Color.field, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 14).frame(height: 56).contentShape(Rectangle())     // measured from Sal's screenshot
            }
            .accessibilityIdentifier("menuBuyRobux")
            Divider().overlay(Color(white: 0.25))
            Button { open(.info(.plus)) } label: {
                HStack(spacing: 18) {
                    Icon("roblox-plus", size: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("More fun for less Robux.")
                        Text("Subscribe to Roblox Plus.")
                    }
                    .font(.builder(12.1))
                    Spacer()
                    Icon("chevron-large-right", size: 20)
                }
                .padding(.horizontal, 14).frame(height: 58).contentShape(Rectangle())
            }
            .accessibilityIdentifier("menuPlus")
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.25), lineWidth: 1))
    }

    private func row(_ icon: String, _ title: String, count: Int = 0, page: Page? = nil) -> some View {
        Button { if page != nil { open(page) } } label: {
            HStack(spacing: 22) {
                Icon(icon, size: 21).frame(width: 26)
                Text(title).font(.builder(16, .bold))
                Spacer()
                CountBubble(n: count, size: 17)
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
            Text("Short clips from experiences show up here.").font(.builder(14.5)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}

struct GamesPage: View {
    let title: String
    let games: [Game]
    let empty: String
    let open: (Page) -> Void
    var body: some View {
        ScrollView {
            if games.isEmpty {
                Text(empty).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(games) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g) }.buttonStyle(PressStyle())
                }
            }
            .padding(20)
        }
        .page(title)
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
    let open: (Page) -> Void
    @State private var name = ""
    @State private var adding = false
    @State private var note = ""

    var body: some View {
        let listed = store.profile.friendList.count, more = store.profile.friends - listed
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Add a friend by Roblox username", text: $name).font(.builder(14.5))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go).onSubmit(add)
                        .padding(.horizontal, 12).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("friendsAddField")
                    Button(action: add) {
                        Group { if adding { ProgressView().tint(.white) } else { Text("Add").font(.builder(14.5, .bold)) } }
                            .frame(width: 64, height: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
                    }
                    .disabled(adding || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("friendsAddButton")
                }
                .padding(.top, 12)
                if !note.isEmpty { Text(note).font(.builder(12)).foregroundStyle(Color.faint).padding(.top, 8).accessibilityIdentifier("friendsAddNote") }
                Text("Friends (\(grouped(max(store.profile.friends, listed))))").font(.builder(20, .bold)).padding(.top, 20).padding(.bottom, 8)
                ForEach(store.profile.friendList) { f in
                    Button { open(.friend(f.id)) } label: {
                        HStack(spacing: 12) {
                            RemoteCircle(url: f.headshot, size: 48)
                                .overlay(alignment: .bottomTrailing) {
                                    if f.online {
                                        Circle().fill(Color.bg).frame(width: 16, height: 16)
                                            .overlay(Circle().fill(Color.online).frame(width: 11, height: 11))
                                    }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.displayName).font(.builder(16, .bold)).lineLimit(1)
                                Text(f.status.isEmpty ? (f.online ? "Online" : "Offline") : f.status)
                                    .font(.builder(14.5)).foregroundStyle(f.online && !f.status.isEmpty ? Color.online : Color.faint).lineLimit(1)
                            }
                            Spacer()
                            Icon("chevron-large-right", size: 18).foregroundStyle(Color.faint)
                        }
                        .frame(height: 68).contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("friendRowPage")
                    Divider().overlay(Color.tile)
                }
                if more > 0 {
                    Text("and \(grouped(more)) more").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 20)
        }
        .page("Friends")
    }

    private func add() {
        let who = name.trimmingCharacters(in: .whitespaces)
        guard !who.isEmpty, !adding else { return }
        adding = true
        note = ""
        Task {
            do {
                note = try await store.addFriend(who) ? "Added \(who)." : "\(who) is already in your friends."
                name = ""
            } catch {
                note = error.localizedDescription
            }
            adding = false
        }
    }
}

private func personName(_ store: Store, _ id: Int64, _ person: Parse.Person?) -> (display: String, user: String, face: String?, online: Bool, status: String) {
    if let f = store.profile.friendList.first(where: { $0.id == id }) { return (f.displayName, f.name, f.headshot, f.online, f.status) }
    return (person?.displayName ?? "", person?.name ?? "", nil, false, "")
}

struct FriendSheet: View {
    @EnvironmentObject var store: Store
    let id: Int64
    let close: () -> Void
    let open: (Page) -> Void
    @State private var them: Roblox.Someone?
    @State private var face: String?
    @State private var trusted = false
    @GestureState private var pull: CGFloat = 0

    var body: some View {
        let who = personName(store, id, them?.person)
        VStack(spacing: 0) {
            Capsule().fill(Color.rgb(58, 59, 66)).frame(width: 39, height: 4).frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        if let picture = them?.picture { RemoteImage(url: picture, fill: false) } else if them == nil { ProgressView().tint(Color.faint) }
                    }
                    .frame(height: 236).frame(maxWidth: .infinity)
                    HStack(alignment: .center, spacing: 12) {
                        RemoteCircle(url: who.face ?? face, size: 88)
                            .overlay(alignment: .bottomTrailing) {
                                if who.online { Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.online).frame(width: 14, height: 14)).offset(x: -4, y: -4) }
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(who.display).font(.builder(20, .bold)).lineLimit(1).accessibilityIdentifier("friendName")
                                if them?.person?.verified == true { VerifiedBadge(size: 15).fixedSize() }
                            }
                            Text("@\(who.user)").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                        }
                    }
                    .padding(.top, 6)
                    counts(them).padding(.top, 16)
                    HStack(spacing: 8) {
                        grey("Chat") { close(); open(.chat(id)) }.accessibilityIdentifier("friendChat")
                        grey(trusted ? "Trusted friend" : "Add trusted friend") { trusted.toggle() }
                        moreMenu(store: store, id: id, close: close)
                    }
                    .padding(.top, 20)
                    if let worn = them?.wearing, !worn.isEmpty {
                        Text("Currently Wearing").font(.builder(20, .bold)).padding(.top, 28).padding(.bottom, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(worn) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 136) }.buttonStyle(PressStyle()) }
                            }
                        }
                        .padding(.horizontal, -24).contentMargins(.horizontal, 24)
                    }
                    Button { open(.person(id)) } label: {
                        Text("View full profile").font(.builder(16, .medium)).frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ink, lineWidth: 1))
                    }
                    .accessibilityIdentifier("friendFullProfile")
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
        .foregroundStyle(Color.ink)
        .background(LinearGradient(colors: [Color.rgb(41, 40, 44), Color.rgb(77, 87, 100), Color.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)),
                    in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .offset(y: max(pull, 0))
        .gesture(DragGesture(minimumDistance: 6).updating($pull) { g, p, _ in p = g.translation.height }
            .onEnded { g in if g.predictedEndTranslation.height > 140 { close() } }, including: .gesture)
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: pull == 0)
        .task {
            async let t = Roblox.someone(id)
            async let f = Roblox.headshots([id])
            them = await t
            face = await f[id]
        }
    }

    private func grey(_ title: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            Text(title).font(.builder(14.5, .medium)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).frame(height: 40)
                .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressStyle())
    }
}

private func counts(_ them: Roblox.Someone?) -> some View {
    func chip(_ n: Int, _ what: String) -> some View {
        Text("\(short(n)) \(what)").font(.builder(14.5)).lineLimit(1).fixedSize().padding(.horizontal, 12).frame(height: 31)
            .background(Color.tile.opacity(n == 0 ? 0.6 : 1), in: Capsule())
            .foregroundStyle(n == 0 ? Color.dim.opacity(0.6) : Color.ink)
    }
    return ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            if let n = them?.friends { chip(n, "Friends") }
            if let n = them?.followers { chip(n, "Followers") }
            if let n = them?.following { chip(n, "Following") }
        }
    }
}

private func moreMenu(store: Store, id: Int64, close: @escaping () -> Void) -> some View {
    Menu {
        if store.profile.friendList.contains(where: { $0.id == id }) {
            Button("Unfriend", role: .destructive) {
                store.profile.removeFriend(id)
                close()
            }
        } else {
            Button("Add Friend") {
                Task { _ = try? await store.addFriendById(id) }
            }
        }
    } label: {
        Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityIdentifier("friendMore").accessibilityLabel("More")
}

struct FriendPage: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: Int64
    let open: (Page) -> Void
    @State private var them: Roblox.Someone?
    @State private var more: Roblox.More?
    @State private var face: String?
    @State private var wholeBio = false
    @State private var creations = false

    var body: some View {
        let who = personName(store, id, them?.person)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 8).fill(Color.rgb(25, 26, 30))
                    .overlay {
                        if let picture = them?.picture { RemoteImage(url: picture, fill: false).padding(.vertical, 10) }
                        else if them == nil { ProgressView().tint(Color.faint) }
                    }
                    .frame(height: 300)
                HStack(alignment: .top, spacing: 13) {
                    RemoteCircle(url: who.face ?? face, size: 88)
                        .overlay(alignment: .bottomTrailing) {
                            if who.online { Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.online).frame(width: 14, height: 14)).offset(x: -4, y: -4) }
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(who.display).font(.builder(26, .bold)).lineLimit(1).minimumScaleFactor(0.75).accessibilityIdentifier("personName")
                            if them?.person?.verified == true { VerifiedBadge(size: 19.5).fixedSize() }
                        }
                        Text("@\(who.user)").font(.builder(12)).foregroundStyle(Color.faint).lineLimit(1)
                    }
                    .padding(.top, 34)
                }
                .padding(.top, -20)
                counts(them).padding(.horizontal, -15).contentMargins(.horizontal, 15).padding(.top, 17)
                if !who.status.isEmpty { Text(who.status).font(.builder(14.5, .medium)).foregroundStyle(Color.online).padding(.top, 14) }
                let bio = them?.person?.bio ?? ""
                Text(bio.isEmpty ? "No bio yet" : bio).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(wholeBio ? nil : 2).padding(.top, 18)
                Button(wholeBio ? "less" : "more") { wholeBio.toggle() }
                    .font(.builder(14.5)).underline().foregroundStyle(Color.faint).padding(.top, 2)
                HStack(spacing: 8) {
                    if store.profile.friendList.contains(where: { $0.id == id }) {
                        Button { open(.chat(id)) } label: {
                            Text("Chat").font(.builder(13.5, .bold)).frame(maxWidth: .infinity, minHeight: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("personChat")
                    } else {
                        Button { Task { _ = try? await store.addFriendById(id) } } label: {
                            Text("Add Friend").font(.builder(13.5, .bold)).frame(maxWidth: .infinity, minHeight: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                    }
                    moreMenu(store: store, id: id) { dismiss() }
                }
                .padding(.top, 24)
                tabs
                if creations {
                    if let games = more?.creations, !games.isEmpty {
                        section("Experiences") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 16) {
                                ForEach(games) { g in Button { open(.game(g)) } label: { GameCard(game: g) } }
                            }
                            .padding(.trailing, 16)
                        }
                    } else {
                        Text(more == nil ? " " : "No creations yet.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.leading, 16).padding(.top, 28)
                    }
                } else {
                    about
                }
            }
            .padding(.horizontal, 15).padding(.top, 40).padding(.bottom, 30)
            .buttonStyle(PressStyle())
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                Text("Profile").font(.builder(23.5, .bold))
                HStack {
                    Button { dismiss() } label: { Icon("x", size: 28).frame(width: 44, height: 44) }
                        .accessibilityIdentifier("personClose").accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.leading, 20)
            }
            .frame(height: 54).frame(maxWidth: .infinity)
            .background(Color.rgb(36, 37, 39).ignoresSafeArea(edges: .top))
        }
        .task {
            async let t = Roblox.someone(id)
            async let f = Roblox.headshots([id])
            async let m = Roblox.moreOf(id)
            them = await t
            face = await f[id]
            more = await m
        }
    }

    @ViewBuilder
    private var about: some View {
        if let worn = them?.wearing, !worn.isEmpty {
            section("Currently Wearing") { row { ForEach(worn) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) } } } }
        }
        if let games = them?.favorites, !games.isEmpty {
            section("Favorites") { row { ForEach(games) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 108) } } } }
        }
        if let friends = more?.friends, !friends.isEmpty {
            section("Friends (\(grouped(them?.friends ?? friends.count)))", seeAll: true) {
                row {
                    ForEach(friends, id: \.user.id) { f in
                        Button { open(.person(f.user.id)) } label: {
                            VStack(spacing: 6) {
                                RemoteCircle(url: f.face, size: 92)
                                Text(f.user.displayName).font(.builder(10.5)).lineLimit(1)
                            }
                            .frame(width: 96)
                        }
                    }
                }
            }
        }
        if let groups = more?.communities, !groups.isEmpty {
            section("Communities") {
                row {
                    ForEach(groups, id: \.id) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 120, height: 120)
                                .overlay { RemoteImage(url: more?.groupIcons[g.id], fill: true) }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            HStack(spacing: 4) {
                                Text(g.name).font(.builder(14.5, .bold)).lineLimit(2)
                                if g.verified { VerifiedBadge(size: 12).fixedSize() }
                            }
                            .padding(.top, 4)
                            Text("\(short(g.members))+ Members").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                            Text(g.role).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                        }
                        .frame(width: 120, alignment: .leading)
                    }
                }
            }
        }
        if let badges = more?.badges, !badges.isEmpty {
            section("Badges", chevron: true) {
                row {
                    ForEach(badges, id: \.id) { b in
                        VStack(alignment: .leading, spacing: 8) {
                            Circle().fill(Color.tile).frame(width: 112, height: 112)
                                .overlay { RemoteImage(url: b.icon, fill: true) }
                                .clipShape(Circle())
                            Text(b.name).font(.builder(14.5, .bold)).lineLimit(2)
                        }
                        .frame(width: 112, alignment: .leading)
                    }
                }
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["About", "Creations"], id: \.self) { t in
                let on = (t == "Creations") == creations
                Button { withAnimation(.easeOut(duration: 0.2)) { creations = t == "Creations" } } label: {
                    Text(t).font(.builder(14.2, .medium)).foregroundStyle(on ? Color.ink : Color.dim)
                        .frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
                }
                .accessibilityIdentifier("personTab-\(t)")
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                Rectangle().fill(creations ? Color.tile : Color.ink).frame(height: creations ? 1 : 2)
                Rectangle().fill(creations ? Color.ink : Color.tile).frame(height: creations ? 2 : 1)
            }
            .frame(height: 2, alignment: .bottom)
        }
        .padding(.top, 15)
    }

    private func section<C: View>(_ title: String, seeAll: Bool = false, chevron: Bool = false, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title).font(.builder(19, .bold))
                if chevron { Icon("chevron-large-right", size: 16) }
                if seeAll {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("See All").font(.builder(14.5, .medium))
                        Icon("arrow-large-right", size: 16)
                    }
                    .padding(.trailing, 16)
                }
            }
            content()
        }
        .padding(.leading, 16).padding(.top, 34)
    }

    private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) { content() }
        }
        .padding(.leading, -31).padding(.trailing, -15).contentMargins(.leading, 31).contentMargins(.trailing, 15)
    }
}

struct SearchPage: View {
    let open: (Page) -> Void
    @State private var query = ""
    @State private var results: [Game] = []
    @State private var note = "Search for an experience by name."
    @State private var asked = 0
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Icon("magnifying-glass", size: 18).foregroundStyle(Color.faint)
                TextField("Search", text: $query).font(.builder(16)).submitLabel(.search).autocorrectionDisabled()
                    .focused($typing).onSubmit { Task { await search() } }
                    .accessibilityIdentifier("searchField")
            }
            .padding(.horizontal, 12).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20).padding(.vertical, 10)
            ScrollView {
                if !note.isEmpty { Text(note).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 30) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                    ForEach(results) { g in
                        Button { open(.game(g)) } label: { WideGameCard(game: g) }
                            .buttonStyle(PressStyle()).accessibilityIdentifier("searchResult")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .page("Search")
        .onAppear { typing = true }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        asked += 1
        let mine = asked
        note = "Searching…"
        do {
            let found = try await Roblox.games(q)
            guard mine == asked else { return }
            results = found
            note = found.isEmpty ? "No experiences found for \u{201C}\(q)\u{201D}." : ""
        } catch {
            guard mine == asked else { return }
            note = error.localizedDescription
        }
    }
}

struct InfoPage: View {
    @EnvironmentObject var store: Store
    let kind: Info

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Icon(kind.icon, size: 56).padding(.top, 50)
                Text(kind.title).font(.builder(22, .bold))
                Text(text).font(.builder(14.5)).foregroundStyle(Color.faint).multilineTextAlignment(.center)
                if kind == .plus {
                    let on = store.profile.badge == .plus
                    WideButton(title: on ? "Cancel Roblox Plus" : "Subscribe", main: !on) { store.profile.badge = on ? .none : .plus }
                        .accessibilityIdentifier("plusSubscribe").padding(.top, 10)
                    Text(on ? "The Plus mark is on your profile." : "Subscribing here is free and only adds the Plus mark to your profile.")
                        .font(.builder(12)).foregroundStyle(Color.faint).multilineTextAlignment(.center)
                }
                if kind == .accounts {
                    HStack(spacing: 12) {
                        Headshot(image: store.avatar, crop: store.profile.crop, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.profile.shownName).font(.builder(16, .bold))
                            Text("@\(store.profile.shownUsername)").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        Spacer()
                        Icon("circle-check", size: 22, filled: true).foregroundStyle(Color.bloxBlue)
                    }
                    .padding(12).background(Color.tile, in: RoundedRectangle(cornerRadius: 8)).padding(.top, 10)
                }
            }
            .padding(.horizontal, 28)
        }
        .page(kind.title)
    }

    private var text: String {
        switch kind {
        case .communities: "You haven't joined any communities."
        case .messages: store.profile.messages > 0 ? "You have \(grouped(store.profile.messages)) unread messages." : "Your inbox is empty."
        case .plus: "More fun for less Robux: a monthly Robux stipend, discounts in the Marketplace, and trading."
        case .help: "Help and safety settings live on the Roblox website."
        case .learn: "Guides for building on Roblox live on the Creator Hub."
        case .create: "Experiences are made in Roblox Studio on a computer."
        case .accounts: "This phone is signed in to one account."
        }
    }
}
