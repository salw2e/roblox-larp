import SwiftUI
import SalBloxKit

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
