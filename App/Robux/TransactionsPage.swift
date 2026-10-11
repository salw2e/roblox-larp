import SwiftUI
import SalBloxKit

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
