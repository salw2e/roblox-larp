import SwiftUI
import SalBloxKit

enum MainTab: String, CaseIterable { case home = "Home", moments = "Moments", chat = "Chat", me = "Me" }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = MainTab.home
    @State private var menu = false
    @State private var barHidden = false
    @State private var path: [Page] = []        // pages pushed over the tabs
    @State private var settings = false
    @State private var robux = false
    @State private var game: Game?
    @State private var gameFull = false
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
                GamePage(game: g, close: closeGame, open: { open($0) }, full: $gameFull)
                    .id(g.id)
                    .padding(.top, gameFull ? 0 : Self.gameTop)
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
                    kept(.me) { AppearanceView(active: tab == .me, openMenu: openMenu, hideBar: { barHidden = $0 }, open: { open($0) }) }
                }
                .frame(maxHeight: .infinity)
                if !(barHidden && tab == .me) { bar }
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
            gameFull = game != nil && gameFull
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
