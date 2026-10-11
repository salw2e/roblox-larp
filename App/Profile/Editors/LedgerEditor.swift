import SwiftUI
import SalBloxKit

struct LedgerEditor: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section("Balance") { field("Robux", $store.profile.robux, id: "ledgerRobux") }
            Section("Incoming Robux") { ForEach(Ledger.incoming, id: \.self) { field($0, row($0), id: "edit-\($0)") } }
            Section("Pending") { field(Ledger.pending, row(Ledger.pending), id: "edit-\(Ledger.pending)") }
            Section("Outgoing Robux") { ForEach(Ledger.outgoing, id: \.self) { field($0, row($0), id: "edit-\($0)") } }
        }
        .navigationTitle("Robux & transactions")
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } } }
    }

    private func row(_ name: String) -> Binding<Int> {
        Binding(get: { store.profile.ledger[name] ?? 0 }, set: { store.profile.ledger[name] = $0 })
    }

    private func field(_ label: String, _ value: Binding<Int>, id: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            PlainNumberField(value: value, id: id).frame(width: 140)
        }
    }
}

struct PlainNumberField: View {
    @Binding var value: Int
    let id: String
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
            .accessibilityIdentifier(id)
            .onAppear { text = value == 0 ? "" : "\(value)" }
            .onChange(of: text) { _, t in
                let kept = digits(in: t)
                if kept != t { text = kept }
                value = number(from: kept)
            }
    }
}
