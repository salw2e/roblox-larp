import SwiftUI
import SalBloxKit

struct GamesView: View {
    @EnvironmentObject var store: Store
    @State private var made = false
    @State private var query = ""
    @State private var results: [Game] = []
    @State private var status = ""
    @State private var loading = false
    @State private var asked = 0

    private var list: Binding<[Game]> { made ? $store.profile.experiences : $store.profile.games }

    var body: some View {
        List {
            Section {
                Picker("List", selection: $made) {
                    Text("Favorites").tag(false)
                    Text("Experiences").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("gameListPicker")
            } footer: {
                Text(made ? "Experiences show on your profile as games you made." : "Favorites show on Home under Continue and on the Favorites page.")
            }
            Section(made ? "Your experiences" : "Your favorites") {
                if list.wrappedValue.isEmpty { Text("None yet. Search below to add some.").foregroundStyle(Color.faint) }
                ForEach(list.wrappedValue) { row($0).accessibilityIdentifier("chosenGame") }
                    .onDelete { list.wrappedValue.remove(atOffsets: $0) }
                    .onMove { list.wrappedValue.move(fromOffsets: $0, toOffset: $1) }
            }
            Section("Add from Roblox") {
                TextField("Search games", text: $query).submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await search() } }
                    .accessibilityIdentifier("gameSearch")
                if loading { ProgressView() }
                if !status.isEmpty { Text(status).foregroundStyle(Color.faint) }
                ForEach(results) { game in
                    let added = list.wrappedValue.contains { $0.id == game.id }
                    Button {
                        if added { list.wrappedValue.removeAll { $0.id == game.id } } else { list.wrappedValue.append(game) }
                    } label: {
                        HStack {
                            row(game)
                            Spacer()
                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                                .font(.builder(24)).foregroundStyle(Color.bloxBlue)
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
                Text(g.name).font(.builder(17, .semibold)).lineLimit(2)
                Text("\(short(g.playing)) Playing").font(.builder(14)).foregroundStyle(Color.faint)
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        asked += 1
        let mine = asked
        loading = true
        status = ""
        do {
            let found = try await Roblox.games(q)
            guard mine == asked else { return }
            results = found
            if results.isEmpty { status = "No games found." }
        } catch {
            guard mine == asked else { return }
            status = error.localizedDescription
        }
        loading = false
    }
}
