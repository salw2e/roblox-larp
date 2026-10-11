import SwiftUI
import BloxKit

enum Page: Hashable, Identifiable {
    case profile, fullProfile, favorites, friends, inventory, robux, transactions, notifications, trades
    case game(Game), item(Item), trade(Int), chat(Int64)
    var id: String { "\(self)" }
}

extension View {
    func page(_ title: String) -> some View {
        background(Color.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bg, for: .navigationBar)
    }
}

struct WideButton: View {
    let title: String
    var main = true
    var icon: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Icon(icon, size: 20, filled: true) }
                Text(title).font(.builder(16, .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(main ? Color.bloxBlue : Color.tile, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(main ? .white : Color.ink)
        }
        .buttonStyle(PressStyle())
    }
}

struct RobuxAmount: View {
    let amount: Int
    var size: CGFloat = 14.5
    var weight: Font.Weight = .regular
    var body: some View {
        HStack(spacing: 4) {
            Icon("robux", size: size * 1.15)
            Text(grouped(amount)).font(.builder(size, weight))
        }
    }
}

// MARK: - Robux

struct RobuxPage: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    @State private var buying: (robux: Int, price: String)?
    private let packs: [(Int, String)] = [(400, "$4.99"), (800, "$9.99"), (1_700, "$19.99"), (4_500, "$49.99"), (10_000, "$99.99"), (22_500, "$199.99")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("My Balance").font(.builder(14.5)).foregroundStyle(Color.faint)
                HStack(spacing: 8) {
                    Icon("robux", size: 34)
                    Text(grouped(store.profile.robux)).font(.builder(32, .bold)).accessibilityIdentifier("robuxBalance")
                }
                .padding(.top, 6)
                Button { open(.transactions) } label: {
                    HStack {
                        Text("My Transactions").font(.builder(16, .medium))
                        Spacer()
                        Icon("chevron-large-right", size: 18)
                    }
                    .padding(.horizontal, 16).frame(height: 52).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("myTransactions")
                .padding(.top, 20)
                Text("Buy Robux").font(.builder(20, .bold)).frame(height: 24).padding(.top, 28).padding(.bottom, 12)
                ForEach(packs, id: \.0) { pack in
                    HStack {
                        RobuxAmount(amount: pack.0, size: 17, weight: .bold)
                        Spacer()
                        Button { buying = pack } label: {
                            Text(pack.1).font(.builder(14.5, .bold)).frame(width: 88, height: 36)
                                .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("buyRobux-\(pack.0)")
                    }
                    .frame(height: 60)
                    Divider().overlay(Color.tile)
                }
            }
            .padding(20)
        }
        .page("Robux")
        .alert("Buy Robux", isPresented: Binding(get: { buying != nil }, set: { if !$0 { buying = nil } })) {
            Button("Buy") { if let buying { store.profile.topUp(buying.robux) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(buying.map { "\(grouped($0.robux)) Robux for \($0.price). Nothing is charged: this adds them to your pretend balance." } ?? "")
        }
    }
}

struct TransactionsPage: View {
    @EnvironmentObject var store: Store
    @State private var period = "Past Month"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Summary").font(.builder(20, .bold))
                    Spacer()
                    Menu {
                        ForEach(["Past Day", "Past Week", "Past Month", "Past Year"], id: \.self) { p in Button(p) { period = p } }
                    } label: {
                        HStack(spacing: 6) {
                            Text(period).font(.builder(14.5))
                            Icon("chevron-small-down", size: 16)
                        }
                        .padding(.horizontal, 12).frame(height: 36).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                group("Incoming Robux", Ledger.incoming)
                row(Ledger.pending, store.profile.ledger[Ledger.pending] ?? 0, faint: true).padding(.top, 8)
                group("Outgoing Robux", Ledger.outgoing)
            }
            .padding(20)
        }
        .page("My Transactions")
    }

    private func group(_ title: String, _ rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.builder(16, .bold)).padding(.top, 28).padding(.bottom, 6)
            ForEach(rows, id: \.self) { row($0, store.profile.ledger[$0] ?? 0) }
            Divider().overlay(Color.tile).padding(.vertical, 4)
            row("Total", store.profile.total(rows), bold: true)
        }
    }

    private func row(_ name: String, _ amount: Int, bold: Bool = false, faint: Bool = false) -> some View {
        HStack {
            Text(name).font(.builder(14.5, bold ? .bold : .regular)).foregroundStyle(faint ? Color.faint : Color.ink)
            Spacer()
            RobuxAmount(amount: amount, weight: bold ? .bold : .regular)
        }
        .frame(height: 40)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ledger-\(name)")
    }
}

// MARK: - Item

struct ItemPage: View {
    @EnvironmentObject var store: Store
    let item: Item
    @State private var info: ItemInfo?
    @State private var confirming = false
    @State private var refusal = ""

    var body: some View {
        let owned = store.profile.owns(item)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Thumb(url: item.thumb)
                HStack(spacing: 8) {
                    Text(item.name).font(.builder(20, .bold))
                    if info?.limited == true {
                        Text("Limited").font(.builder(12, .bold)).padding(.horizontal, 8).frame(height: 22)
                            .background(Color.online, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.black)
                    }
                }
                .padding(.top, 16)
                HStack(spacing: 4) {
                    Text("By \(item.creator)").font(.builder(14.5)).foregroundStyle(Color.faint)
                    if item.showsCreatorCheck { VerifiedBadge(size: 12) }
                }
                .padding(.top, 4)
                PriceLine(price: item.price, size: 20).padding(.top, 14)
                if owned != nil {
                    HStack(spacing: 6) {
                        Icon("circle-check", size: 18, filled: true)
                        Text("Item Owned").font(.builder(14.5))
                    }
                    .foregroundStyle(Color.faint).padding(.top, 10).accessibilityIdentifier("itemOwned")
                    WideButton(title: owned?.wearing == true ? "Take Off" : "Wear", main: owned?.wearing != true) {
                        store.profile.wear(item, owned?.wearing != true)
                    }
                    .accessibilityIdentifier("wearButton")
                    .padding(.top, 12)
                } else {
                    WideButton(title: item.price == 0 ? "Get" : "Buy") {
                        if item.price == 0 { finish(store.profile.buy(item)) } else { confirming = true }
                    }
                    .disabled(item.price == nil)
                    .opacity(item.price == nil ? 0.4 : 1)
                    .accessibilityIdentifier("buyButton")
                    .padding(.top, 16)
                }
                if !refusal.isEmpty { Text(refusal).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 10).accessibilityIdentifier("buyRefusal") }
                detail("Type", info?.type ?? "").padding(.top, 24)
                detail("Created", info?.created ?? "")
                if let d = info?.description, !d.isEmpty {
                    Text("Description").font(.builder(16, .bold)).padding(.top, 20)
                    Text(d).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 6)
                }
            }
            .padding(20)
        }
        .page("")
        .task { info = await Roblox.itemInfo(item) }
        .alert("Buy Item", isPresented: $confirming) {
            Button("Buy Now") { finish(store.profile.buy(item)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            let after = store.profile.robux - (item.price ?? 0)
            Text("Would you like to buy \(item.name) for \(grouped(item.price ?? 0)) Robux?" +
                 (after >= 0 ? " Your balance after this transaction will be \(grouped(after)) Robux." : ""))
        }
    }

    private func finish(_ result: Purchase) {
        switch result {
        case .bought, .alreadyOwned: refusal = ""
        case .tooExpensive: refusal = "You need \(grouped((item.price ?? 0) - store.profile.robux)) more Robux to buy this item."
        case .offSale: refusal = "This item is not currently for sale."
        }
    }

    @ViewBuilder
    private func detail(_ name: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack {
                Text(name).font(.builder(14.5)).foregroundStyle(Color.faint).frame(width: 110, alignment: .leading)
                Text(value).font(.builder(14.5))
            }
            .frame(height: 32)
        }
    }
}

// MARK: - Game

struct GamePage: View {
    @EnvironmentObject var store: Store
    let game: Game
    @State private var info: GameInfo?
    @State private var joining = false

    var body: some View {
        let favourite = store.profile.games.contains { $0.id == game.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 8).fill(Color.tile).aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { RemoteImage(url: game.wide ?? game.icon, fill: true) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(game.name).font(.builder(20, .bold)).padding(.top, 16)
                if let c = info?.creator, !c.isEmpty {
                    Text("By \(c)").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 4)
                }
                HStack(spacing: 0) {
                    stat("thumb-up", game.rating.map { "\($0)%" } ?? "--", "Rating")
                    stat("two-people", short(info?.playing ?? game.playing), "Active")
                    stat("circle-play", info.map { short($0.visits) } ?? "--", "Visits")
                }
                .padding(.top, 18)
                WideButton(title: joining ? "Joining…" : "Play", icon: "play-large") {
                    joining = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        joining = false
                    }
                }
                .accessibilityIdentifier("playButton")
                .padding(.top, 18)
                WideButton(title: favourite ? "Favorited" : "Favorite", main: false, icon: "star") {
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(game) }
                }
                .accessibilityIdentifier("favoriteButton")
                .padding(.top, 10)
                if let info {
                    Text("About").font(.builder(20, .bold)).padding(.top, 28)
                    Text(info.description).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 8)
                        .accessibilityIdentifier("gameAbout")
                    VStack(spacing: 0) {
                        fact("Favorites", grouped(info.favorites))
                        fact("Visits", grouped(info.visits))
                        fact("Created", info.created)
                        fact("Updated", info.updated)
                        fact("Server Size", "\(info.maxPlayers)")
                        fact("Genre", info.genre)
                    }
                    .padding(.top, 16)
                }
            }
            .padding(20)
        }
        .page("")
        .task { info = await Roblox.gameInfo(game.id) }
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Icon(icon, size: 18, filled: true)
                Text(value).font(.builder(17, .bold))
            }
            Text(label).font(.builder(12)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity)
    }

    private func fact(_ name: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).font(.builder(14.5)).foregroundStyle(Color.faint)
                Spacer()
                Text(value).font(.builder(14.5))
            }
            .frame(height: 40)
            Divider().overlay(Color.tile)
        }
    }
}

// MARK: - Notifications

struct NotificationsPage: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.profile.notices.isEmpty {
                    Text("You have no notifications.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        .frame(maxWidth: .infinity).padding(.top, 60)
                }
                ForEach(store.profile.notices) { n in
                    HStack(alignment: .top, spacing: 12) {
                        if let f = store.profile.friendList.first(where: { $0.id == n.friend }) {
                            RemoteCircle(url: f.headshot, size: 48)
                        } else {
                            Circle().fill(Color.tile).frame(width: 48, height: 48).overlay(Icon("tilt", size: 24, filled: true))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(n.text).font(.builder(14.5))
                            Text(n.when).font(.builder(12)).foregroundStyle(Color.faint)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("noticeRow")
                    Divider().overlay(Color.tile)
                }
            }
            .padding(.horizontal, 20)
        }
        .page("Notifications")
        .onAppear { store.profile.notifications = 0 }
    }
}

// MARK: - Chat

struct ChatList: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Chat").font(.builder(20, .bold)).frame(height: 28).padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 0) {
                    if store.profile.friendList.isEmpty {
                        Text("Add friends in Edit profile and they show up here.").font(.builder(14.5)).foregroundStyle(Color.faint)
                            .padding(.top, 40)
                    }
                    ForEach(store.profile.friendList) { f in
                        Button { open(.chat(f.id)) } label: {
                            HStack(spacing: 12) {
                                RemoteCircle(url: f.headshot, size: 52)
                                    .overlay(alignment: .bottomTrailing) {
                                        if f.online { Circle().fill(Color.bg).frame(width: 16, height: 16).overlay(Circle().fill(Color.online).frame(width: 11, height: 11)) }
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.displayName).font(.builder(16, .bold))
                                    Text(store.profile.chat(with: f.id).last?.text ?? (f.status.isEmpty ? "Say hi!" : f.status))
                                        .font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20).frame(height: 72).contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("chatRow")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bg)
    }
}

struct ChatPage: View {
    @EnvironmentObject var store: Store
    let friendId: Int64
    @State private var draft = ""
    @State private var asThem = false

    var body: some View {
        let friend = store.profile.friendList.first { $0.id == friendId }
        let lines = store.profile.chat(with: friendId)
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            HStack(alignment: .bottom, spacing: 8) {
                                if line.mine { Spacer(minLength: 60) } else { RemoteCircle(url: friend?.headshot, size: 28) }
                                Text(line.text).font(.builder(14.5)).padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(line.mine ? Color.bloxBlue : Color.tile, in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(line.mine ? .white : Color.ink)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { store.profile.chats["\(friendId)"]?.remove(at: i) }
                                    }
                                if !line.mine { Spacer(minLength: 60) }
                            }
                            .id(i)
                            .accessibilityIdentifier(line.mine ? "myLine" : "theirLine")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: lines.count) { _, n in withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) } }
                .onAppear { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
            }
            HStack(spacing: 10) {
                Button { asThem.toggle() } label: {
                    Icon(asThem ? "person" : "two-arrows-switch-right", size: 22, filled: asThem)
                        .frame(width: 40, height: 40).background(asThem ? Color.bloxBlue : Color.tile, in: Circle())
                }
                .accessibilityIdentifier("sendAsThem")
                TextField(asThem ? "Their message" : "Say something", text: $draft).font(.builder(14.5))
                    .padding(.horizontal, 14).frame(height: 40).background(Color.tile, in: Capsule())
                    .submitLabel(.send).onSubmit(send)
                    .accessibilityIdentifier("chatField")
                Button(action: send) { Icon("paper-airplane", size: 24, filled: true) }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("chatSend")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .page(friend?.displayName ?? "Chat")
    }

    private func send() {
        store.profile.say(draft, to: friendId, mine: !asThem)
        draft = ""
    }
}

// MARK: - Trades

struct TradesPage: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    @State private var status = TradeStatus.inbound

    var body: some View {
        let shown = store.profile.trades.filter { $0.status == status }
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TradeStatus.allCases, id: \.self) { s in
                    Button { status = s } label: {
                        VStack(spacing: 10) {
                            Text(s.rawValue.capitalized).font(.builder(14.5)).foregroundStyle(status == s ? Color.ink : Color.faint)
                            Rectangle().fill(status == s ? Color.ink : Color.tile).frame(height: 1)
                        }
                    }
                    .accessibilityIdentifier("trades-\(s.rawValue)")
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
            ScrollView {
                VStack(spacing: 0) {
                    if shown.isEmpty {
                        Text("You have no \(status.rawValue) trades.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 60)
                    }
                    ForEach(shown) { t in
                        Button { open(.trade(t.id)) } label: {
                            HStack(spacing: 12) {
                                RemoteCircle(url: t.partner.headshot, size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.partner.displayName).font(.builder(16, .bold))
                                    Text(t.when.isEmpty ? "@\(t.partner.name)" : t.when).font(.builder(12)).foregroundStyle(Color.faint)
                                }
                                Spacer()
                                Icon("chevron-large-right", size: 18).foregroundStyle(Color.faint)
                            }
                            .padding(.horizontal, 20).frame(height: 72).contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("tradeRow")
                        Divider().overlay(Color.tile).padding(.leading, 80)
                    }
                }
            }
        }
        .page("Trades")
    }
}

struct TradePage: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: Int
    @State private var note = ""
    private let grid = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)]

    var body: some View {
        ScrollView {
            if let t = store.profile.trades.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        RemoteCircle(url: t.partner.headshot, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trade with \(t.partner.displayName)").font(.builder(16, .bold))
                            Text(t.status.rawValue.capitalized + (t.when.isEmpty ? "" : " · \(t.when)")).font(.builder(12)).foregroundStyle(Color.faint)
                        }
                    }
                    side(t.status == .completed ? "Items you gave" : "Items you will give", t.giving, t.giveRobux, t.giveValue)
                    side(t.status == .completed ? "Items you received" : "Items you will receive", t.receiving, t.getRobux, t.getValue)
                    if t.status == .inbound {
                        WideButton(title: "Accept") {
                            if store.profile.accept(trade: id) { note = "Trade accepted." } else { note = "You don't have enough Robux for this trade." }
                        }
                        .accessibilityIdentifier("acceptTrade")
                        .padding(.top, 24)
                        WideButton(title: "Decline", main: false) {
                            if let i = store.profile.trades.firstIndex(where: { $0.id == id }) { store.profile.trades[i].status = .inactive }
                            dismiss()
                        }
                        .padding(.top, 10)
                    }
                    if !note.isEmpty { Text(note).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 12).accessibilityIdentifier("tradeNote") }
                }
                .padding(20)
            }
        }
        .page("Trade")
    }

    private func side(_ title: String, _ items: [Item], _ robux: Int, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.builder(16, .bold)).padding(.top, 24)
            LazyVGrid(columns: grid, spacing: 16) { ForEach(items) { ItemCard(item: $0) } }
            if robux > 0 {
                HStack {
                    Text("Robux").font(.builder(14.5)).foregroundStyle(Color.faint)
                    Spacer()
                    RobuxAmount(amount: robux)
                }
            }
            HStack {
                Text("Value").font(.builder(14.5, .bold))
                Spacer()
                RobuxAmount(amount: value, weight: .bold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tradeValue")
        }
    }
}
