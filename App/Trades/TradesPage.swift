import SwiftUI
import SalBloxKit

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
