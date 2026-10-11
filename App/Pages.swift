import SwiftUI
import BloxKit

enum Page: Hashable, Identifiable {
    case profile, fullProfile, favorites, continuePlaying, friends, inventory, robux, transactions, notifications, trades
    case search, settings, momentsTab
    case game(Game), item(Item), trade(Int), chat(Int64), friend(Int64), info(Info)
    var id: String { "\(self)" }
}

enum Info: String, Hashable {
    case communities, messages, plus, help, learn, create, accounts

    var title: String {
        switch self {
        case .communities: "Communities"
        case .messages: "Messages"
        case .plus: "Roblox Plus"
        case .help: "Help & Safety"
        case .learn: "Learn"
        case .create: "Create"
        case .accounts: "Switch Accounts"
        }
    }

    var icon: String {
        switch self {
        case .communities: "three-people"
        case .messages: "envelope"
        case .plus: "roblox-plus"
        case .help: "shield-lock"
        case .learn: "person-graduate"
        case .create: "studio"
        case .accounts: "two-people"
        }
    }
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
    let close: () -> Void
    @State private var buying: (robux: Int, price: String)?
    @State private var sending = false
    @State private var plan: Plan?
    @State private var shownPlan: Int? = 0
    @State private var closedFAQ: Set<Int> = []
    private let packs: [(Int, String)] = [(22_500, "$199.99"), (10_000, "$99.99"), (4_500, "$49.99"), (3_150, "$34.99"),
                                          (1_700, "$19.99"), (1_200, "$14.99"), (800, "$9.99"), (400, "$4.99"), (80, "$0.99"), (40, "$0.49")]
    private static let panel = Color(red: 25 / 255, green: 26 / 255, blue: 31 / 255)
    private static let key = Color(red: 49 / 255, green: 49 / 255, blue: 59 / 255)

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Buy Robux").font(.builder(45, .bold)).padding(.top, 6)
                    Text("Robux packages").font(.builder(19.5, .bold)).padding(.top, 36)
                    (Text("By purchasing Robux, you agree to our ")
                        + Text("Terms of Use").font(.builder(12, .bold)).foregroundColor(Color.ink)
                        + Text(", including the arbitration clause and revocation policy."))
                        .font(.builder(12)).foregroundStyle(Color.faint).lineSpacing(2.5).padding(.top, 4)
                    VStack(spacing: 20) { ForEach(packs, id: \.0) { row($0) } }
                        .padding(.vertical, 19.5).padding(.leading, 22).padding(.trailing, 20)
                        .background(Self.panel, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.top, 15)
                    NavigationLink(value: Page.transactions) {
                        HStack {
                            Text("My Transactions").font(.builder(16, .medium))
                            Spacer()
                            Icon("chevron-large-right", size: 18)
                        }
                        .padding(.horizontal, 16).frame(height: 52).background(Self.panel, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("myTransactions")
                    .padding(.top, 24)
                    newOnRoblox.padding(.top, 32)
                    faq.padding(.top, 36)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .background(Color.bg.ignoresSafeArea(edges: .bottom))
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Page.self) { _ in TransactionsPage() }
        .alert("Buy Robux", isPresented: Binding(get: { buying != nil }, set: { if !$0 { buying = nil } })) {
            Button("Buy") { if let buying { store.profile.topUp(buying.robux) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(buying.map { "\(grouped($0.robux)) Robux for \($0.price). Nothing is charged: this adds them to your pretend balance." } ?? "")
        }
        .sheet(isPresented: $sending) { SendRobuxSheet() }
        .alert(plan.map { "Subscribe to \($0.name)" } ?? "", isPresented: Binding(get: { plan != nil }, set: { if !$0 { plan = nil } })) {
            Button("Subscribe") {
                if let plan {
                    store.profile.badge = .plus
                    store.profile.topUp(plan.robux)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(plan.map { "\($0.price)/month. Nothing is charged: your profile gets Roblox Plus" + ($0.robux > 0 ? " and \(grouped($0.robux)) Robux." : ".") } ?? "")
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            Button(action: close) { Icon("x", size: 32).frame(width: 44, height: 44) }
                .accessibilityIdentifier("robuxClose").accessibilityLabel("Close")
                .padding(.leading, 18)
            Icon("robux", size: 20).padding(.leading, 18)
            Text(grouped(store.profile.robux)).font(.builder(20, .bold)).padding(.leading, 6)
                .accessibilityIdentifier("robuxBalance")
            Spacer()
            Button { sending = true } label: {
                HStack(spacing: 6) {
                    Icon("arrow-up-from-line", size: 15)
                    Text("Send").font(.builder(12, .medium))
                }
                .frame(width: 68, height: 32).background(Self.key, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("sendRobux")
            .padding(.trailing, 20)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 56)
        .background(Self.panel)
    }

    struct Plan: Identifiable {
        let id: Int
        let name: String
        let price: String
        var was: String?            // the struck-out total value
        let robux: Int
        let perks: [(icon: String, text: String)]
    }

    private let plans = [
        Plan(id: 0, name: "Roblox Plus", price: "$4.99", robux: 0, perks: [("tag", "Up to 20% off on items and avatars"),
            ("controller", "Free private servers"), ("robux", "Send Robux for free"), ("paint-brush", "Customize profile and app theme")]),
        Plan(id: 1, name: "Plus 500", price: "$10.99", was: "$11.24", robux: 500, perks: [("premium", "Everything in Plus"),
            ("robux", "+500 Robux every month"), ("pig", "$11.24 total value")]),
        Plan(id: 2, name: "Plus 1000", price: "$15.99", was: "$17.24", robux: 1_000, perks: [("premium", "Everything in Plus"),
            ("robux", "+1,000 Robux every month"), ("pig", "$17.24 total value")]),
        Plan(id: 3, name: "Plus 2000", price: "$25.99", was: "$28.24", robux: 2_000, perks: [("premium", "Everything in Plus"),
            ("robux", "+2,000 Robux every month"), ("pig", "$28.24 total value")]),
    ]

    private static let faqs: [(q: String, a: Text)] = [
        ("What are Robux?", Text("Robux is the virtual currency that can be purchased using your local currency or with Roblox Gift Card credits. It allows users to customize their avatar and purchase special abilities and items in experiences.")),
        ("Where are my Robux?", Text("Your Robux balance and transaction history can be found under ") + Text("My Transactions").bold()
            + Text(".\n\nIn the desktop and mobile app, you can find your Robux balance by logging into the account where the Robux were purchased or earned, tapping on the Robux icon at the top right of the app, and see your balance displayed at the top.\n\nOn the web browser, log in to the account where the Robux were purchased or earned and your Robux balance is shown in the upper right corner.")),
        ("Do Robux expire?", Text("Robux do not expire. Once purchased, they will remain in the user's account until they are spent. Users can hold onto and utilize their Robux at any time.")),
    ]

    private var newOnRoblox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Icon("premium", size: 20)
                Text("New on Roblox").font(.builder(19.5, .bold))
                Spacer()
                Link(destination: URL(string: "https://www.roblox.com/premium/membership")!) {
                    Text("Learn more").font(.builder(14.2, .medium)).underline()
                }
            }
            .frame(height: 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12.5) {
                    ForEach(plans) { p in planCard(p).id(p.id) }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $shownPlan)
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
            .padding(.top, 12.5)
            HStack(spacing: 10) {
                ForEach(plans) { p in Circle().fill(p.id == (shownPlan ?? 0) ? Color.ink : Color.tile).frame(width: 6, height: 6) }
            }
            .frame(maxWidth: .infinity).padding(.top, 14)
        }
    }

    private func planCard(_ p: Plan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(p.name).font(.builder(16.2, .medium))
                Spacer()
                if let was = p.was { Text(was).font(.builder(14.5)).strikethrough().foregroundStyle(Color.faint) }
                Text(p.price).font(.builder(14.5, .bold))
            }
            .frame(height: 24).padding(.top, 13)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                ForEach(p.perks, id: \.text) { perk in
                    HStack(spacing: 14) {
                        Icon(perk.icon, size: 18).frame(width: 20)
                        Text(perk.text).font(.builder(14)).foregroundStyle(Color.faint).lineLimit(1)
                    }
                    .frame(height: 18)
                }
            }
            Spacer()
            Button { plan = p } label: {
                Text("\(p.price)/month").font(.builder(13.8, .bold)).foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.rgb(34, 33, 37), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("plan-\(p.id)")
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
        .frame(width: 311, height: 238)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rgb(38, 37, 39), lineWidth: 1))
    }

    private var faq: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FAQ").font(.builder(18.7, .bold)).frame(height: 24)
            VStack(spacing: 16) {
                ForEach(Self.faqs.indices, id: \.self) { i in
                    let open = !closedFAQ.contains(i)
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { if open { closedFAQ.insert(i) } else { closedFAQ.remove(i) } }
                        } label: {
                            HStack {
                                Text(Self.faqs[i].q).font(.builder(13.9, .bold))
                                Spacer()
                                Icon(open ? "chevron-small-up" : "chevron-small-down", size: 22)
                            }
                            .frame(height: 56).contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("faq-\(i)")
                        if open {
                            Self.faqs[i].a.font(.builder(14)).foregroundStyle(Color.faint).lineSpacing(2.5)
                                .padding(.top, -7.5).padding(.bottom, 18).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 12.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rgb(36, 35, 37), lineWidth: 1))
                }
            }
            .padding(.top, 13)
        }
    }

    private func row(_ pack: (Int, String)) -> some View {
        HStack(spacing: 0) {
            Icon("robux", size: 21)
            Text(grouped(pack.0)).font(.builder(23.3, .bold)).padding(.leading, 6)
            if pack.0 == 80 {
                HStack(spacing: 4) {
                    Icon("circle-star", size: 12)
                    Text("For you").font(.builder(12, .medium))
                }
                .padding(.horizontal, 9).frame(height: 24).background(Color.tile, in: Capsule()).padding(.leading, 9)
            }
            Spacer()
            Button { buying = pack } label: {
                Text(pack.1).font(.builder(13.5, .bold)).foregroundStyle(.white)
                    .frame(width: 120, height: 40)
                    .background(pack.0 == 80 ? Color.bloxBlue : Self.key, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("buyRobux-\(pack.0)")
        }
        .frame(height: 40)
    }
}

struct SendRobuxSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var to: Friend?
    @State private var amount = ""
    @State private var refused = false

    var body: some View {
        let p = store.profile
        let shown = p.friendList.filter { search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Icon("premium", size: 20)
                Text("Send Robux").font(.builder(19.6, .bold))
                Spacer()
                Icon("robux", size: 16)
                Text(grouped(p.robux)).font(.builder(14.5, .bold)).accessibilityIdentifier("sendBalance")
                Button { dismiss() } label: { Icon("x", size: 26).frame(width: 36, height: 36) }
                    .accessibilityIdentifier("sendClose").accessibilityLabel("Close").padding(.leading, 6)
            }
            .padding(.top, 13)
            HStack(spacing: 10) {
                Icon("magnifying-glass", size: 20)
                TextField("", text: $search, prompt: Text("Search").foregroundStyle(Color.faint))
                    .font(.builder(13.7)).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityIdentifier("sendSearch")
            }
            .padding(.horizontal, 14).frame(height: 39)
            .overlay(Capsule().stroke(Color.tile, lineWidth: 1))
            .padding(.top, 16)
            Text("My friends (\(grouped(p.friendList.count)))").font(.builder(15.9, .bold)).padding(.top, 20)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(shown) { f in
                        Button { to = f; amount = "" } label: {
                            HStack(spacing: 15) {
                                RemoteCircle(url: f.headshot, size: 48)
                                Text(f.displayName).font(.builder(14, .bold)).lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("sendTo")
                    }
                }
                .padding(.top, 16).padding(.bottom, 24)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 21)
        .presentationDetents([.height(822)])
        .presentationCornerRadius(16)
        .presentationBackground(Color.rgb(25, 26, 31))
        .alert("Send Robux to \(to?.displayName ?? "")", isPresented: Binding(get: { to != nil }, set: { if !$0 { to = nil } })) {
            TextField("Amount", text: $amount).keyboardType(.numberPad)
            Button("Send") { if !store.profile.send(number(from: amount)) { refused = true } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(grouped(store.profile.robux)) Robux.")
        }
        .alert("Not sent", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter an amount you have, more than 0.")
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
                        ForEach(Ledger.periods, id: \.self) { p in Button(p) { period = p } }
                    } label: {
                        HStack(spacing: 6) {
                            Text(period).font(.builder(14.5))
                            Icon("chevron-small-down", size: 16)
                        }
                        .padding(.horizontal, 12).frame(height: 36).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("ledgerPeriod")
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
            ForEach(rows, id: \.self) { row($0, Ledger.amount(store.profile.ledger[$0] ?? 0, in: period)) }
            Divider().overlay(Color.tile).padding(.vertical, 4)
            row("Total", rows.reduce(0) { $0 + Ledger.amount(store.profile.ledger[$1] ?? 0, in: period) }, bold: true)
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
    @State private var sharp: String?
    @State private var loaded = false
    @State private var confirming = false
    @State private var refusal = ""

    var body: some View {
        let owned = store.profile.owns(item)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Thumb(url: sharp ?? item.thumb)
                HStack(spacing: 8) {
                    Text(item.name).font(.builder(20, .bold))
                    if info?.limited == true || item.limited == true {
                        Text("Limited").font(.builder(12, .bold)).padding(.horizontal, 8).frame(height: 22)
                            .background(Color.online, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.black)
                    }
                }
                .padding(.top, 16)
                if !item.creator.isEmpty {
                    HStack(spacing: 4) {
                        Text("By \(item.creator)").font(.builder(14.5)).foregroundStyle(Color.faint)
                        if item.showsCreatorCheck { VerifiedBadge(size: 12) }
                    }
                    .padding(.top, 4)
                }
                PriceLine(price: (owned ?? item).price, size: 20).padding(.top, 14)
                if let owned {
                    HStack(spacing: 6) {
                        Icon("circle-check", size: 18, filled: true)
                        Text("Item Owned").font(.builder(14.5))
                    }
                    .foregroundStyle(Color.faint).padding(.top, 10).accessibilityIdentifier("itemOwned")
                    WideButton(title: owned.wearing ? "Take Off" : "Wear", main: !owned.wearing) { store.wear(item, !owned.wearing) }
                        .accessibilityIdentifier("wearButton")
                        .padding(.top, 12)
                } else if item.price == nil {
                    Text("This item is not currently for sale.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        .frame(maxWidth: .infinity, minHeight: 48).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 16).accessibilityIdentifier("notForSale")
                } else {
                    WideButton(title: item.price == 0 ? "Get" : "Buy") {
                        if item.price == 0 { finish(store.profile.buy(item)) } else { confirming = true }
                    }
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
                if loaded, info == nil, !item.bundle {
                    Button { Task { await load() } } label: {
                        Text("Couldn't load this item's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                    }
                    .padding(.top, 24).accessibilityIdentifier("itemRetry")
                }
            }
            .padding(20)
        }
        .page("")
        .task { await load() }
        .alert("Buy Item", isPresented: $confirming) {
            Button("Buy Now") { finish(store.profile.buy(item)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            let after = store.profile.robux - (item.price ?? 0)
            Text("Would you like to buy \(item.name) for \(grouped(item.price ?? 0)) Robux?" +
                 (after >= 0 ? " Your balance after this transaction will be \(grouped(after)) Robux." : ""))
        }
    }

    private func load() async {
        loaded = false
        async let details = Roblox.itemInfo(item)
        async let picture = Roblox.bigThumb(item)
        info = await details
        sharp = await picture
        loaded = true
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
    @State private var filled: Game?
    @State private var loaded = false
    @State private var joining = false

    var body: some View {
        let shown = filled ?? game
        let favourite = store.profile.games.contains { $0.id == game.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 8).fill(Color.tile).aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { RemoteImage(url: shown.wide ?? shown.icon, fill: shown.wide != nil) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(game.name).font(.builder(20, .bold)).padding(.top, 16)
                if let c = info?.creator, !c.isEmpty {
                    Text("By \(c)").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 4)
                }
                HStack(spacing: 0) {
                    stat("thumb-up", shown.rating.map { "\($0)%" } ?? "--", "Rating")
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
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(shown) }
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
                } else if loaded {
                    Button { Task { await load() } } label: {
                        Text("Couldn't load this experience's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                    }
                    .padding(.top, 28).accessibilityIdentifier("gameRetry")
                }
            }
            .padding(20)
        }
        .page("")
        .task { await load() }
    }

    private func load() async {
        loaded = false
        info = await Roblox.gameInfo(game.id)
        if game.wide == nil || game.rating == nil { filled = await Roblox.complete([game]).first }
        loaded = true
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
                    let friend = store.profile.friendList.first { $0.id == n.friend }
                    HStack(alignment: .top, spacing: 12) {
                        if let friend {
                            RemoteCircle(url: friend.headshot, size: 48)
                        } else {
                            Circle().fill(Color.tile).frame(width: 48, height: 48).overlay(Icon("tilt", size: 24, filled: true))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            (Text(friend.map { $0.displayName + " " } ?? "").font(.builder(14.5, .bold)) + Text(n.text).font(.builder(14.5)))
                                .accessibilityIdentifier("noticeText")
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.profile.notifications > 0 {
                    Button("Mark read") { store.profile.notifications = 0 }
                        .font(.builder(14.5)).accessibilityIdentifier("markRead")
                }
            }
        }
    }
}

// MARK: - Chat

struct ChatList: View {
    @EnvironmentObject var store: Store
    var openMenu: () -> Void = {}
    let open: (Page) -> Void
    @State private var searching = false
    @State private var query = ""
    @FocusState private var typing: Bool

    var body: some View {
        let p = store.profile
        let shown = p.friendList.enumerated()
            .filter { query.isEmpty || $0.element.displayName.localizedCaseInsensitiveContains(query) || $0.element.name.localizedCaseInsensitiveContains(query) }
            .sorted { a, b in
                let x = p.chat(with: a.element.id).last?.at ?? 0, y = p.chat(with: b.element.id).last?.at ?? 0
                return x != y ? x > y : a.offset < b.offset
            }
            .map(\.element)
        VStack(alignment: .leading, spacing: 0) {
            header
            if searching {
                TextField("Search chats", text: $query).focused($typing).autocorrectionDisabled()
                    .font(.builder(16)).padding(.horizontal, 12).frame(height: 40)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20).padding(.bottom, 10)
                    .accessibilityIdentifier("chatSearch")
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !searching {
                        action("person-play", "Start party", "Join experiences together") { open(.friends) }
                        action("three-people", "Communities", "Create and explore communities") { open(.info(.communities)) }
                    }
                    if p.friendList.isEmpty {
                        Text("Add friends and they show up here.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
                        Button { open(.friends) } label: {
                            Text("Add Friends").font(.builder(14.5, .bold)).padding(.horizontal, 20).frame(height: 40)
                                .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(shown) { f in conversation(f) }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bg)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: openMenu) {
                Icon("three-bars-horizontal", size: 25)
                    .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
            }
            .accessibilityIdentifier("chatMenu").accessibilityLabel("Menu")
            Text("Chat").font(.builder(28, .bold)).padding(.leading, 13)
            Spacer()
            Button {
                searching.toggle()
                query = ""
                typing = searching
            } label: { Icon(searching ? "x" : "magnifying-glass", size: 25) }
                .accessibilityIdentifier("chatSearchToggle").accessibilityLabel(searching ? "Close search" : "Search")
            Button { open(.friends) } label: { Icon("pencil-square", size: 25) }
                .accessibilityLabel("New chat").padding(.leading, 22)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 28)
        .padding(.leading, 20).padding(.trailing, 24).padding(.top, 6).padding(.bottom, 13)
    }

    private func action(_ icon: String, _ title: String, _ detail: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            HStack(spacing: 10) {
                Icon(icon, size: 22).frame(width: 36, height: 36).background(Color.tile, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.builder(16.2, .bold))
                    Text(detail).font(.builder(12)).foregroundStyle(Color.faint)
                }
                Spacer()
                Icon("arrow-large-right", size: 22)
            }
            .padding(.leading, 20).padding(.trailing, 24).frame(height: 64)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tile).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func conversation(_ f: Friend) -> some View {
        let last = store.profile.chat(with: f.id).last
        return Button { open(.chat(f.id)) } label: {
            HStack(alignment: .center, spacing: 10) {
                RemoteCircle(url: f.headshot, size: 39)
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.displayName).font(.builder(16.1, .bold)).lineLimit(1)
                    Text(last?.text ?? " ").font(.builder(13.1)).foregroundStyle(Color.faint).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let at = last?.at { Text(chatTime(at)).font(.builder(12.3)).foregroundStyle(Color.faint) }
            }
            .padding(.leading, 20).padding(.trailing, 22).frame(height: 64)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tile).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("chatRow")
    }
}

struct ChatPage: View {
    @EnvironmentObject var store: Store
    let friendId: Int64
    @State private var draft = ""
    @State private var asThem = false
    @FocusState private var typing: Bool

    var body: some View {
        let friend = store.profile.friendList.first { $0.id == friendId }
        let lines = store.profile.chat(with: friendId)
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.element.key) { i, line in
                            HStack(alignment: .bottom, spacing: 8) {
                                if line.mine { Spacer(minLength: 60) } else { RemoteCircle(url: friend?.headshot, size: 28) }
                                Text(line.text).font(.builder(14.5)).padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(line.mine ? Color.bloxBlue : Color.tile, in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(line.mine ? .white : Color.ink)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            store.profile.chats["\(friendId)"]?.removeAll { $0 == line }
                                        }
                                    }
                                if !line.mine { Spacer(minLength: 60) }
                            }
                            .id(i)
                            .accessibilityIdentifier(line.mine ? "myLine" : "theirLine")
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lines.count) { _, n in withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) } }
                .onChange(of: typing) { _, on in
                    if on { withAnimation { proxy.scrollTo(lines.count - 1, anchor: .bottom) } }
                }
                .onAppear { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
            }
            HStack(spacing: 10) {
                Button { asThem.toggle() } label: {
                    Icon(asThem ? "person" : "two-arrows-switch-right", size: 22, filled: asThem)
                        .frame(width: 40, height: 40).background(asThem ? Color.bloxBlue : Color.tile, in: Circle())
                }
                .accessibilityIdentifier("sendAsThem").accessibilityLabel(asThem ? "Sending as them" : "Sending as you")
                TextField(asThem ? "Their message" : "Say something", text: $draft).font(.builder(14.5))
                    .padding(.horizontal, 14).frame(height: 40).background(Color.tile, in: Capsule())
                    .focused($typing)
                    .submitLabel(.send).onSubmit(send)
                    .accessibilityIdentifier("chatField")
                Button(action: send) { Icon("paper-airplane", size: 24, filled: true) }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("chatSend").accessibilityLabel("Send")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .page(friend?.displayName ?? "Chat")
    }

    private func send() {
        store.profile.say(draft, to: friendId, mine: !asThem)
        draft = ""
        typing = true
    }
}

extension ChatLine {
    var key: String { id.map { "#\($0)" } ?? "\(mine)|\(text)" }
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
                    side(t.status == .completed ? "Items you gave" : "Items you will give", t.giving.map { store.profile.owns($0) ?? $0 }, t.giveRobux, store.profile.giveValue(of: t))
                    side(t.status == .completed ? "Items you received" : "Items you will receive", t.receiving, t.getRobux, t.getValue)
                    switch t.status {
                    case .inbound:
                        WideButton(title: "Accept") {
                            note = store.profile.accept(trade: id) ? "Trade accepted." : "You don't have enough Robux for this trade."
                        }
                        .accessibilityIdentifier("acceptTrade")
                        .padding(.top, 24)
                        WideButton(title: "Counter", main: false) { move(to: .outbound, saying: "Counter offer sent.") }
                            .accessibilityIdentifier("counterTrade").padding(.top, 10)
                        WideButton(title: "Decline", main: false) {
                            move(to: .inactive, saying: "")
                            dismiss()
                        }
                        .accessibilityIdentifier("declineTrade").padding(.top, 10)
                    case .outbound:
                        WideButton(title: "Cancel Trade", main: false) {
                            move(to: .inactive, saying: "")
                            dismiss()
                        }
                        .accessibilityIdentifier("cancelTrade").padding(.top, 24)
                    case .completed, .inactive:
                        EmptyView()
                    }
                    if !note.isEmpty { Text(note).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 12).accessibilityIdentifier("tradeNote") }
                }
                .padding(20)
            } else {
                Text("This trade no longer exists.").font(.builder(14.5)).foregroundStyle(Color.faint)
                    .frame(maxWidth: .infinity).padding(.top, 60).accessibilityIdentifier("tradeGone")
            }
        }
        .page("Trade")
    }

    private func move(to status: TradeStatus, saying words: String) {
        if let i = store.profile.trades.firstIndex(where: { $0.id == id }) { store.profile.trades[i].status = status }
        note = words
    }

    private func side(_ title: String, _ items: [Item], _ robux: Int, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.builder(16, .bold)).padding(.top, 24)
            if items.isEmpty && robux == 0 {
                Text("Nothing").font(.builder(14.5)).foregroundStyle(Color.faint)
            }
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
