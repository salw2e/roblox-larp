import SwiftUI
import SalBloxKit

struct GamesPage: View {
    let title: String
    let games: [Game]
    let empty: String
    let open: (Page) -> Void
    var body: some View {
        ScrollView {
            if games.isEmpty {
                Text(empty).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(games) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g) }.buttonStyle(PressStyle())
                }
            }
            .padding(20)
        }
        .page(title)
    }
}
