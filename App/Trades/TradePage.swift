import SwiftUI
import SalBloxKit

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
