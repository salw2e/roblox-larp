import SwiftUI
import BloxKit

enum Page: Hashable, Identifiable {
    case profile, fullProfile, favorites, continuePlaying, friends, inventory, robux, transactions, notifications, trades
    case search, settings, momentsTab
    case game(Game), item(Item), trade(Int), chat(Int64), friend(Int64), person(Int64), info(Info)
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
    @Environment(\.dismiss) private var dismiss
    let item: Item
    var close: () -> Void = {}
    var isRoot = true
    var open: (Page) -> Void = { _ in }
    @State private var detail: ItemDetail?
    @State private var sharp: String?
    @State private var partPictures: [Int64: String] = [:]
    @State private var also: [Item] = []
    @State private var loaded = false
    @State private var wholeText = false
    @State private var buying: Item?

    var body: some View {
        let shown = detail?.item ?? item
        VStack(spacing: 0) {
            HStack {
                Button { if isRoot { close() } else { dismiss() } } label: {
                    Icon(isRoot ? "x" : "chevron-large-left", size: 26).frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("itemClose").accessibilityLabel(isRoot ? "Close" : "Back")
                Spacer()
            }
            .padding(.leading, 10).frame(height: 44)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(item.name).font(.builder(20, .bold)).lineLimit(2)
                        if shown.limited == true {
                            Text("Limited").font(.builder(12, .bold)).padding(.horizontal, 8).frame(height: 22)
                                .background(Color.online, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.black)
                        }
                    }
                    .padding(.top, 21)
                    RemoteImage(url: sharp ?? item.thumb, fill: false).frame(height: 220).frame(maxWidth: .infinity).padding(.top, 16)
                    if let parts = detail?.parts, !parts.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
                            ForEach(parts) { p in
                                VStack(alignment: .leading, spacing: 8) {
                                    Thumb(url: partPictures[p.id])
                                    Text(p.name).font(.builder(14.5, .bold)).lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 24)
                    }
                    if let d = detail?.description, !d.isEmpty {
                        VStack(spacing: 4) {
                            Text(d).font(.builder(16)).foregroundStyle(Color.faint).lineLimit(wholeText ? nil : 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { withAnimation(.easeOut(duration: 0.2)) { wholeText.toggle() } } label: {
                                Icon(wholeText ? "chevron-small-up" : "chevron-small-down", size: 22).frame(width: 44, height: 24)
                            }
                            .accessibilityLabel(wholeText ? "Less" : "More")
                        }
                        .padding(.top, 24)
                    }
                    if let f = detail?.favorites {
                        HStack(spacing: 14) {
                            Icon("star", size: 40, filled: true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(short(f)).font(.builder(26, .bold))
                                Text("Favorites").font(.builder(12))
                            }
                        }
                        .padding(.top, 24).padding(.leading, 10)
                    }
                    VStack(spacing: 0) {
                        if !shown.creator.isEmpty {
                            row("Creator") {
                                HStack(spacing: 6) {
                                    Text(shown.creator).font(.builder(16, .bold))
                                    if shown.showsCreatorCheck { VerifiedBadge(size: 14) }
                                    Icon("arrow-large-right", size: 18)
                                }
                            }
                        }
                        if let t = detail?.type, !t.isEmpty { row("Type") { Text(t).font(.builder(16)) } }
                        if let d = detail { row("Placement") { Text(d.placement).font(.builder(16)) } }
                    }
                    .padding(.top, 20)
                    if let owned = store.profile.owns(item) {
                        HStack(spacing: 6) {
                            Icon("circle-check", size: 18, filled: true)
                            Text(owned.wearing ? "You own this item and are wearing it" : "You own this item").font(.builder(14.5))
                        }
                        .foregroundStyle(Color.faint).padding(.top, 20).accessibilityIdentifier("itemOwned")
                    } else if shown.price == nil, loaded {
                        Text("This item is not currently for sale.").font(.builder(14.5)).foregroundStyle(Color.faint)
                            .padding(.top, 20).accessibilityIdentifier("notForSale")
                    }
                    if loaded, detail == nil {
                        Button { Task { await load() } } label: {
                            Text("Couldn't load this item's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        .padding(.top, 24).accessibilityIdentifier("itemRetry")
                    }
                    if !also.isEmpty {
                        Text("You May Also Like").font(.builder(20, .bold)).padding(.top, 32).padding(.bottom, 12)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 20) {
                            ForEach(also) { a in
                                NavigationLink(value: a) { ItemCard(item: a) }.buttonStyle(PressStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            bar(shown)
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .buying($buying, open: { close(); open($0) }) { it in if store.trial?.key == it.key { store.keepTrial() } }
        .task { await load() }
    }

    private func bar(_ shown: Item) -> some View {
        let owned = store.profile.owns(item)
        let trying = store.trial?.key == item.key
        return HStack(spacing: 14) {
            Group {
                if let owned {
                    Button { store.wear(item, !owned.wearing) } label: {
                        Text(owned.wearing ? "Take Off" : "Wear").font(.builder(16, .bold)).frame(maxWidth: .infinity).frame(height: 40)
                            .background(owned.wearing ? Color.tile : Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("wearButton")
                } else if let price = shown.price {
                    Button { buying = shown } label: {
                        HStack(spacing: 6) {
                            if price == 0 { Text("Get").font(.builder(16, .bold)) } else {
                                Icon("robux", size: 20)
                                Text(grouped(price)).font(.builder(16, .bold))
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("buyButton")
                } else {
                    Text("Off Sale").font(.builder(16, .bold)).foregroundStyle(Color.faint).frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .foregroundStyle(.white)
            .buttonStyle(PressStyle())
            Menu {
                if owned == nil {
                    Button(trying ? "Take Off" : "Try On") { store.tryOn(trying ? nil : shown) }
                } else {
                    Button("Remove from inventory", role: .destructive) { store.profile.items.removeAll { $0.same(item) } }
                }
            } label: {
                Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: Circle())
            }
            .accessibilityIdentifier("itemMore").accessibilityLabel("More")
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        .background(Color.bg)
    }

    private func row<V: View>(_ name: String, @ViewBuilder _ value: () -> V) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).font(.builder(16)).foregroundStyle(Color.faint)
                Spacer()
                value()
            }
            .frame(height: 55)
            Divider().overlay(Color.tile)
        }
    }

    private func load() async {
        loaded = false
        async let d = Roblox.itemDetails([item])
        async let picture = Roblox.bigThumb(item)
        detail = await d.first
        sharp = await picture
        loaded = true
        if let parts = detail?.parts, !parts.isEmpty {
            let pics = await Roblox.withThumbs(parts)
            partPictures = Dictionary(pics.compactMap { p in p.thumb.map { (p.id, $0) } }, uniquingKeysWith: { a, _ in a })
        }
        also = await Roblox.recommended(for: detail?.item ?? item, bundleType: detail?.bundleType)
    }
}

struct Buying: ViewModifier {
    @EnvironmentObject var store: Store
    @Binding var item: Item?
    var open: (Page) -> Void
    var bought: (Item) -> Void
    @State private var confirm: Item?
    @State private var short: Item?

    func body(content: Content) -> some View {
        content
            .onChange(of: item) { _, new in
                guard let new, let price = new.price else { return }
                item = nil
                if price == 0 { finish(new) } else if price <= store.profile.robux { confirm = new } else { short = new }
            }
            .alert("Buy Item", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), presenting: confirm) { it in
                Button("Buy Now") { finish(it) }
                Button("Cancel", role: .cancel) {}
            } message: { it in
                let after = store.profile.robux - (it.price ?? 0)
                Text("Would you like to buy \(it.name) for \(grouped(it.price ?? 0)) Robux? Your balance after this transaction will be \(grouped(after)) Robux.")
            }
            .overlay {
                if let it = short {
                    BuyRobuxAndItem(item: it, close: { short = nil }, plus: { short = nil; open(.robux) }) { finish(it) }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.18), value: short?.key)
    }

    private func finish(_ it: Item) {
        if store.profile.buy(it) == .bought { bought(it) }
    }
}

extension View {
    func buying(_ item: Binding<Item?>, open: @escaping (Page) -> Void, bought: @escaping (Item) -> Void = { _ in }) -> some View {
        modifier(Buying(item: item, open: open, bought: bought))
    }
}

struct BuyRobuxAndItem: View {
    @EnvironmentObject var store: Store
    let item: Item
    let close: () -> Void
    let plus: () -> Void
    let buy: () -> Void
    @State private var pick = 0

    var body: some View {
        let packs = robuxPacksFor(shortfall: (item.price ?? 0) - store.profile.robux)
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Buy Robux and item").font(.builder(18, .bold))
                    Spacer()
                    Button(action: close) { Icon("x", size: 22) }.accessibilityLabel("Close")
                }
                HStack(spacing: 14) {
                    RemoteImage(url: item.thumb, fill: false).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.builder(14.5, .bold)).lineLimit(1)
                        HStack(spacing: 4) {
                            Icon("robux", size: 16)
                            Text(grouped(item.price ?? 0)).font(.builder(14.5, .bold))
                        }
                    }
                }
                .padding(.top, 18)
                VStack(spacing: 12) {
                    ForEach(packs.indices, id: \.self) { i in
                        Button { pick = i } label: {
                            HStack(spacing: 6) {
                                Icon("robux", size: 18)
                                Text(grouped(packs[i].robux)).font(.builder(17, .bold))
                                if packs[i].better {
                                    HStack(spacing: 3) {
                                        Icon("tag", size: 11)
                                        Text("Better value").font(.builder(10.5, .medium))
                                    }
                                    .padding(.horizontal, 7).frame(height: 20).background(Color.tile, in: Capsule())
                                }
                                Spacer()
                                Text(packs[i].price).font(.builder(16, .bold))
                            }
                            .padding(.horizontal, 14).frame(height: 54)
                            .background(Color.rgb(32, 33, 38), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(i == pick ? Color.white : Color.tile, lineWidth: i == pick ? 2 : 1))
                        }
                        .accessibilityIdentifier("pack-\(packs[i].robux)")
                    }
                }
                .padding(.top, 18)
                Button {
                    if packs.indices.contains(pick) { store.profile.topUp(packs[pick].robux) }
                    close()
                    buy()
                } label: {
                    Text("Buy").font(.builder(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("buyRobuxAndItem")
                .padding(.top, 26)
                Button(action: plus) {
                    HStack(spacing: 8) {
                        Icon("premium", size: 18)
                        Text("Get 10% off").font(.builder(16, .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 10)
                Text("Nothing is charged: the Robux go to your pretend balance.").font(.builder(10.5)).foregroundStyle(Color.faint)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 12)
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 321)
            .background(Color.rgb(25, 26, 31), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tile, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Game

struct GamePage: View {
    @EnvironmentObject var store: Store
    let game: Game
    var close: () -> Void = {}
    var open: (Page) -> Void = { _ in }
    @Binding var full: Bool
    @State private var info: GameInfo?
    @State private var more: Roblox.GameMore?
    @State private var wholeText = false
    @State private var pass: GamePass?          // the Store pass being bought
    @State private var notEnough = false
    @State private var filled: Game?
    @State private var slides: [String] = []
    @State private var events: [GameEvent] = []
    @State private var eventPictures: [Int64: String] = [:]
    @State private var maturity: String?
    @State private var slide = 0
    @State private var loaded = false
    @State private var joining = false
    @State private var notify = false
    @GestureState private var pull: CGFloat = 0
    private static let sheet = Color.rgb(25, 26, 30)

    var body: some View {
        let shown = filled ?? game
        VStack(spacing: 0) {
            if full {
                HStack {
                    Button(action: close) { Icon("x", size: 26).frame(width: 44, height: 44) }
                        .accessibilityIdentifier("gameClose").accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.leading, 14).frame(height: 48).contentShape(Rectangle())
            } else {
                Capsule().fill(Color.rgb(58, 59, 66)).frame(width: 39, height: 4)
                    .frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
                    .accessibilityIdentifier("gameHandle")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !full { header(shown) }
                    pictures(shown).padding(.top, full ? 0 : 28)
                    chips(shown).padding(.top, 22)
                    if !events.isEmpty { eventRow.padding(.top, 28) }
                    if let info {
                        Text("Description").font(.builder(20, .bold)).padding(.top, 28)
                        Text(info.description).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(wholeText ? nil : 4).padding(.top, 10)
                            .accessibilityIdentifier("gameAbout")
                        Button(wholeText ? "less" : "more") { wholeText.toggle() }
                            .font(.builder(14.5, .medium)).underline().padding(.top, 4)
                        if let passes = more?.passes, !passes.isEmpty { store(passes).padding(.top, 28) }
                        information(info).padding(.top, 28)
                        if let links = more?.social, !links.isEmpty { social(links).padding(.top, 28) }
                        if let also = more?.also, !also.isEmpty {
                            Text("People Also Join").font(.builder(20, .bold)).padding(.top, 28).padding(.bottom, 12)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(also) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 117) }.buttonStyle(PressStyle()) }
                                }
                            }
                            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
                        }
                    } else if loaded {
                        Button { Task { await load() } } label: {
                            Text("Couldn't load this experience's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        .padding(.top, 28).accessibilityIdentifier("gameRetry")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 11).padding(.bottom, 24)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { g in
                if !full, g.translation.height < -24 { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = true } }
            })
            bar
        }
        .background(Self.sheet, in: UnevenRoundedRectangle(topLeadingRadius: full ? 0 : 16, topTrailingRadius: full ? 0 : 16))
        .offset(y: max(pull, 0))
        .gesture(
            DragGesture(minimumDistance: 6)
                .updating($pull) { g, pull, _ in pull = g.translation.height }
                .onEnded { g in
                    let flick = g.predictedEndTranslation.height
                    if flick < -80 { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = true } }
                    else if flick > 140 { if full { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = false } } else { close() } }
                },
            including: .gesture
        )
        .alert(pass.map { "Buy \($0.name)" } ?? "", isPresented: Binding(get: { pass != nil }, set: { if !$0 { pass = nil } }), presenting: pass) { p in
            Button("Buy Now") { if !store.profile.send(p.price ?? 0) { notEnough = true } }
            Button("Cancel", role: .cancel) {}
        } message: { p in Text("Buy \(p.name) for \(grouped(p.price ?? 0)) Robux?") }
        .alert("Not enough Robux", isPresented: $notEnough) {
            Button("OK", role: .cancel) {}
        } message: { Text("Get more on the Buy Robux page.") }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: pull == 0)
        .task { await load() }
    }

    private func header(_ shown: Game) -> some View {
        HStack(alignment: .top, spacing: 12.7) {
            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 56, height: 56)
                .overlay { RemoteImage(url: shown.icon, fill: true) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name).font(.builder(20, .bold)).lineLimit(2)
                if let c = info?.creator, !c.isEmpty {
                    HStack(spacing: 6) {
                        Text(c).font(.builder(16)).lineLimit(1)
                        if info?.creatorVerified == true { VerifiedBadge(size: 16).fixedSize() }
                    }
                }
                if let maturity { Text(maturity).font(.builder(14.5)).foregroundStyle(Color.faint) }
            }
        }
    }

    private func pictures(_ shown: Game) -> some View {
        let all = slides.isEmpty ? [shown.wide ?? shown.icon].compactMap { $0 } : slides
        return RoundedRectangle(cornerRadius: 8).fill(Color.tile).aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                TabView(selection: $slide) {
                    ForEach(all.indices, id: \.self) { i in RemoteImage(url: all[i], fill: true).tag(i) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                if all.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(all.indices, id: \.self) { i in
                            Capsule().fill(Color.white.opacity(i == slide ? 1 : 0.75)).frame(width: i == slide ? 24 : 6, height: 6)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: slide)
                    .padding(.bottom, 14)
                }
            }
    }

    private func chips(_ shown: Game) -> some View {
        let favourite = store.profile.games.contains { $0.id == game.id }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Icon("thumb-up", size: 16)
                    Text(shown.rating.map { "\($0)%" } ?? "--")
                    Rectangle().fill(Color.faint.opacity(0.4)).frame(width: 1, height: 16)
                    Icon("thumb-down", size: 16)
                }
                .chip()
                HStack(spacing: 6) {
                    Icon("two-people", size: 16)
                    Text("\(short(info?.playing ?? game.playing)) active")
                }
                .chip()
                Button { notify.toggle() } label: {
                    HStack(spacing: 6) {
                        Icon("bell", size: 16, filled: notify)
                        Text(notify ? "Notifying" : "Notify")
                    }
                    .chip()
                }
                Button {
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(shown) }
                } label: {
                    HStack(spacing: 6) {
                        Icon("star", size: 16, filled: favourite)
                        Text(favourite ? "Favorited" : "Favorite")
                    }
                    .chip()
                }
                .accessibilityIdentifier("favoriteButton")
            }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        .buttonStyle(PressStyle())
    }

    private var bar: some View {
        let favourite = store.profile.games.contains { $0.id == game.id }
        return HStack(spacing: 0) {
            Menu {
                Button(favourite ? "Unfavorite" : "Favorite") {
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(filled ?? game) }
                }
                Button(notify ? "Stop notifications" : "Notify") { notify.toggle() }
            } label: { Icon("circle-three-dots-horizontal", size: 27).frame(width: 44, height: 48) }
                .accessibilityLabel("More")
            Button { close(); open(.friends) } label: { Icon("person-play", size: 27).frame(width: 44, height: 48) }
                .accessibilityLabel("Play with friends").padding(.leading, 13)
            Button {
                joining = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    joining = false
                }
            } label: {
                ZStack {
                    if joining { ProgressView().tint(.white) } else { Icon("play-large", size: 26, filled: true) }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("playButton").accessibilityLabel(joining ? "Joining" : "Play")
            .padding(.leading, 18)
        }
        .foregroundStyle(Color.ink)
        .padding(.leading, 14).padding(.trailing, 13).padding(.top, 13).padding(.bottom, 8)
        .background(Color.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.rgb(47, 48, 56)).frame(height: 1) }
    }

    private func load() async {
        loaded = false
        async let i = Roblox.gameInfo(game.id)
        async let m = Roblox.maturity(game.id)
        async let s = Roblox.slides(game.id)
        async let e = Roblox.events(game.id)
        async let g = Roblox.gameMore(game.id)
        if game.wide == nil || game.rating == nil || game.icon == nil { filled = await Roblox.complete([game]).first }
        (info, maturity, slides) = await (i, m, s)
        (events, eventPictures) = await e
        more = await g
        loaded = true
    }

    private var eventRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Events").font(.builder(20, .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(events.indices, id: \.self) { i in
                        let e = events[i]
                        let live = e.when() == "Live now"
                        VStack(alignment: .leading, spacing: 0) {
                            Color.tile.aspectRatio(16 / 9, contentMode: .fit)
                                .overlay { RemoteImage(url: e.media.flatMap { eventPictures[$0] }, fill: true) }
                                .clipped()
                                .overlay(alignment: .topLeading) {
                                    Text(live ? "Happening now" : e.when()).font(.builder(12, .medium)).padding(.horizontal, 9).frame(height: 24)
                                        .background(Color.white, in: Capsule()).foregroundStyle(.black).padding(10)
                                }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.title).font(.builder(14.5, .bold)).lineLimit(1)
                                Text(e.subtitle.isEmpty ? " " : e.subtitle).font(.builder(13)).foregroundStyle(Color.faint).lineLimit(1)
                                Button { join() } label: {
                                    Text("Join Event").font(.builder(13, .medium)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 32)
                                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(PressStyle())
                                .padding(.top, 8)
                            }
                            .padding(10)
                        }
                        .background(Color.rgb(32, 33, 38))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 360)
                        .accessibilityIdentifier("gameEvent")
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func join() {
        joining = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            joining = false
        }
    }

    private func store(_ passes: [GamePass]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Store").font(.builder(20, .bold))
                Icon("chevron-large-right", size: 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(passes, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 130, height: 130)
                                .overlay { RemoteImage(url: more?.passIcons[p.id], fill: false).padding(14) }
                            Text(p.name).font(.builder(14.5, .bold)).lineLimit(1).frame(width: 130, alignment: .leading)
                            Button { if p.price != nil { pass = p } } label: {
                                HStack(spacing: 4) {
                                    if let price = p.price { Icon("robux", size: 15); Text(grouped(price)).font(.builder(13, .medium)) }
                                    else { Text("Off Sale").font(.builder(13, .medium)) }
                                }
                                .foregroundStyle(.black).frame(width: 130, height: 30).background(Color.white.opacity(p.price == nil ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func information(_ info: GameInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Information").font(.builder(20, .bold)).padding(.bottom, 4)
            fact("Visits", short(info.visits))
            if let m = maturity { fact("Content Maturity", m.replacingOccurrences(of: "Maturity: ", with: ""), arrow: true) }
            if !info.creator.isEmpty { fact("Developer", info.creator, badge: info.creatorVerified, arrow: true) }
            fact("Server Size", "\(info.maxPlayers)")
            if !info.genre.isEmpty { fact("Genre", info.genre) }
            if !info.subgenre.isEmpty { fact("Subgenre", info.subgenre) }
            fact("Created", info.created)
            fact("Updated", info.updated)
            if let v = more?.voice { fact("Voice Chat", v ? "Supported" : "Not supported") }
            if let c = more?.camera { fact("Camera", c ? "Supported" : "Not supported") }
        }
    }

    private func social(_ links: [SocialLink]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Media").font(.builder(20, .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(links, id: \.url) { l in
                        if let u = URL(string: l.url) {
                            Link(destination: u) {
                                VStack(spacing: 8) {
                                    Circle().fill(Color.tile).frame(width: 92, height: 92)
                                        .overlay(Icon(["Discord": "discord", "YouTube": "youtube", "Twitter": "twitter", "Twitch": "twitch",
                                                       "Facebook": "facebook", "Guilded": "guilded"][l.type] ?? "chain-link", size: 34, filled: true))
                                    Text(l.type).font(.builder(12)).lineLimit(1)
                                }
                                .frame(width: 96)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func fact(_ name: String, _ value: String, badge: Bool = false, arrow: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(name).font(.builder(16)).foregroundStyle(Color.faint)
                Spacer()
                Text(value).font(.builder(16, .bold)).lineLimit(1)
                if badge { VerifiedBadge(size: 14).fixedSize() }
                if arrow { Icon("chevron-large-right", size: 14) }
            }
            .frame(height: 57)
            Divider().overlay(Color.tile)
        }
    }
}

private extension View {
    func chip() -> some View {
        font(.builder(14.5)).padding(.horizontal, 12).frame(height: 32).background(Color.tile, in: Capsule())
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
