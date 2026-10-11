import SwiftUI
import BloxKit

struct GamesView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var results: [Game] = []
    @State private var status = ""
    @State private var loading = false

    var body: some View {
        List {
            Section("On your profile") {
                if store.profile.games.isEmpty { Text("None yet. Search below to add some.").foregroundStyle(Color.faint) }
                ForEach(store.profile.games) { row($0).accessibilityIdentifier("chosenGame") }
                    .onDelete { store.profile.games.remove(atOffsets: $0) }
                    .onMove { store.profile.games.move(fromOffsets: $0, toOffset: $1) }
            }
            Section("Add from Roblox") {
                TextField("Search games", text: $query).submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await search() } }
                    .accessibilityIdentifier("gameSearch")
                if loading { ProgressView() }
                if !status.isEmpty { Text(status).foregroundStyle(Color.faint) }
                ForEach(results) { game in
                    let added = store.profile.games.contains { $0.id == game.id }
                    Button {
                        if added { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(game) }
                    } label: {
                        HStack {
                            row(game)
                            Spacer()
                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 24)).foregroundStyle(Color.bloxBlue)
                        }
                    }
                    .accessibilityIdentifier("addGame")
                }
            }
        }
        .navigationTitle("Games")
        .toolbar { EditButton() }
    }

    private func row(_ g: Game) -> some View {
        HStack(spacing: 12) {
            Thumb(url: g.icon).frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                Text("\(short(g.playing)) Playing").font(.system(size: 14)).foregroundStyle(Color.faint)
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true
        status = ""
        do {
            results = try await Roblox.games(q)
            if results.isEmpty { status = "No games found." }
        } catch {
            status = error.localizedDescription
        }
        loading = false
    }
}
