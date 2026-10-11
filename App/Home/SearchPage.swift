import SwiftUI
import SalBloxKit

struct SearchPage: View {
    let open: (Page) -> Void
    @State private var query = ""
    @State private var results: [Game] = []
    @State private var note = "Search for an experience by name."
    @State private var asked = 0
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Icon("magnifying-glass", size: 18).foregroundStyle(Color.faint)
                TextField("Search", text: $query).font(.builder(16)).submitLabel(.search).autocorrectionDisabled()
                    .focused($typing).onSubmit { Task { await search() } }
                    .accessibilityIdentifier("searchField")
            }
            .padding(.horizontal, 12).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20).padding(.vertical, 10)
            ScrollView {
                if !note.isEmpty { Text(note).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 30) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                    ForEach(results) { g in
                        Button { open(.game(g)) } label: { WideGameCard(game: g) }
                            .buttonStyle(PressStyle()).accessibilityIdentifier("searchResult")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .page("Search")
        .onAppear { typing = true }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        asked += 1
        let mine = asked
        note = "Searching…"
        do {
            let found = try await Roblox.games(q)
            guard mine == asked else { return }
            results = found
            note = found.isEmpty ? "No experiences found for \u{201C}\(q)\u{201D}." : ""
        } catch {
            guard mine == asked else { return }
            note = error.localizedDescription
        }
    }
}
