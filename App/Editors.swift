import SwiftUI
import BloxKit

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

struct NoticesEditor: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var when = "now"
    @State private var friend: Int64?

    var body: some View {
        Form {
            Section("New notification") {
                TextField("Text, e.g. sent you a friend request", text: $text, axis: .vertical).accessibilityIdentifier("noticeText")
                TextField("When, e.g. 2h", text: $when)
                Picker("Whose face", selection: $friend) {
                    Text("Roblox").tag(Int64?.none)
                    ForEach(store.profile.friendList) { Text($0.displayName).tag(Int64?.some($0.id)) }
                }
                Button("Add") {
                    let id = store.profile.newId()
                    store.profile.notices.insert(Notice(id: id, text: text.trimmingCharacters(in: .whitespacesAndNewlines), when: when, friend: friend), at: 0)
                    store.profile.notifications += 1          // the bell counts it
                    text = ""
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("noticeAdd")
            }
            Section("Shown, newest first") {
                ForEach(store.profile.notices) { n in
                    VStack(alignment: .leading) {
                        Text(n.text)
                        Text(n.when).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { gone in
                    store.profile.notices.remove(atOffsets: gone)
                    store.profile.notifications = min(max(store.profile.notifications - gone.count, 0), store.profile.notices.count)
                }
                .onMove { store.profile.notices.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .navigationTitle("Notifications")
        .toolbar { EditButton() }
    }
}

struct TradesEditor: View {
    @EnvironmentObject var store: Store
    @State private var partner = ""
    @State private var status = ""
    @State private var adding = false

    var body: some View {
        Form {
            Section("New trade") {
                TextField("Other player's Roblox username", text: $partner)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("tradePartner")
                Button(adding ? "Looking up…" : "Create") { create() }
                    .disabled(adding || partner.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("tradeCreate")
                if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
            }
            Section("Trades") {
                ForEach(store.profile.trades) { t in
                    NavigationLink { TradeEditor(id: t.id) } label: {
                        VStack(alignment: .leading) {
                            Text(t.partner.displayName)
                            Text("\(t.status.rawValue.capitalized) · you give \(grouped(t.giveValue)), you get \(grouped(t.getValue))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("tradeEditRow")
                }
                .onDelete { store.profile.trades.remove(atOffsets: $0) }
            }
        }
        .navigationTitle("Trades")
    }

    private func create() {
        let name = partner.trimmingCharacters(in: .whitespaces)
        adding = true
        status = ""
        Task {
            do {
                let person = try await Roblox.person(name)
                let id = store.profile.newId()
                store.profile.trades.insert(Trade(id: id, partner: person), at: 0)
                partner = ""
                status = "Created. Open it below to add items."
            } catch {
                status = error.localizedDescription
            }
            adding = false
        }
    }
}

struct TradeEditor: View {
    @EnvironmentObject var store: Store
    let id: Int
    @State private var picking = false
    @State private var note = ""

    private var status: Binding<TradeStatus> {
        Binding(get: { store.profile.trades.first { $0.id == id }?.status ?? .inactive }, set: { new in
            guard let i = store.profile.trades.firstIndex(where: { $0.id == id }), store.profile.trades[i].status != new else { return }
            if new == .completed {
                note = store.profile.complete(trade: id) ? "Completed: the items and Robux have moved." : "Not completed: you don't have enough Robux for this trade."
            } else if store.profile.trades[i].status == .completed {
                note = "A completed trade stays completed: its items have already moved."
            } else {
                store.profile.trades[i].status = new
                note = ""
            }
        })
    }

    var body: some View {
        if let i = store.profile.trades.firstIndex(where: { $0.id == id }) {
            let trade = $store.profile.trades[i]
            Form {
                Section {
                    Picker("Status", selection: status) {
                        ForEach(TradeStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .accessibilityIdentifier("tradeStatus")
                    if !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("tradeEditNote") }
                    TextField("When, e.g. 10/11/2026", text: trade.when)
                }
                Section("You give (from your inventory)") {
                    if store.profile.items.isEmpty { Text("Your inventory is empty.").foregroundStyle(.secondary) }
                    ForEach(store.profile.items) { item in
                        let on = trade.wrappedValue.giving.contains { $0.same(item) }
                        Button {
                            if on { trade.wrappedValue.giving.removeAll { $0.same(item) } } else { trade.wrappedValue.giving.append(item) }
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(priceText(item.price)).foregroundStyle(.secondary)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                    numberRow("Plus Robux", trade.giveRobux)
                }
                Section("You get") {
                    ForEach(trade.wrappedValue.receiving) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(priceText(item.price)).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { trade.wrappedValue.receiving.remove(atOffsets: $0) }
                    Button("Add from the Marketplace") { picking = true }.accessibilityIdentifier("tradeAddItem")
                    numberRow("Plus Robux", trade.getRobux)
                }
            }
            .navigationTitle("Trade with \(trade.wrappedValue.partner.displayName)")
            .sheet(isPresented: $picking) {
                ItemPicker { item in
                    if !trade.wrappedValue.receiving.contains(where: { $0.same(item) }) {
                        trade.wrappedValue.receiving.append(item)
                    }
                }
            }
        }
    }

    private func numberRow(_ label: String, _ value: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            PlainNumberField(value: value, id: "tradeRobux").frame(width: 140)
        }
    }
}

struct ItemPicker: View {
    @Environment(\.dismiss) private var dismiss
    let pick: (Item) -> Void
    @State private var query = ""
    @State private var results: [Item] = []
    @State private var note = ""
    @State private var picked: Set<String> = []
    @State private var asked = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if !note.isEmpty { Text(note).foregroundStyle(Color.faint).padding() }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top),
                                    GridItem(.flexible(), alignment: .top)], spacing: 20) {
                    ForEach(results) { item in
                        Button {
                            pick(item)
                            picked.insert(item.key)
                        } label: {
                            ItemCard(item: item, showCreator: true)
                                .overlay(alignment: .topTrailing) {
                                    if picked.contains(item.key) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.white, Color.bloxBlue).padding(6)
                                    }
                                }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("pickItem")
                    }
                }
                .padding(15)
            }
            .background(Color.bg)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search the Marketplace")
            .onSubmit(of: .search) { Task { await load() } }
            .navigationTitle("Pick items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("pickDone") } }
            .task { await load() }
        }
    }

    private func load() async {
        asked += 1
        let mine = asked
        note = "Searching…"
        do {
            let found = try await Roblox.search(query.trimmingCharacters(in: .whitespaces)).items
            guard mine == asked else { return }
            results = found
            note = results.isEmpty ? "Nothing found." : ""
        } catch {
            guard mine == asked else { return }
            note = error.localizedDescription
        }
    }
}
