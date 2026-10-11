import SwiftUI
import SalBloxKit

struct GameCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Thumb(url: game.icon)
            Text(game.name).font(.builder(14, .bold)).lineLimit(2, reservesSpace: true)
            GameStats(game: game)
        }
    }
}

struct GameStats: View {
    let game: Game
    var body: some View {
        HStack(spacing: 3) {
            Icon("thumb-up", size: 13, filled: true)
            Text(game.rating.map { "\($0)%" } ?? "--")
            Icon("two-people", size: 13, filled: true).padding(.leading, 6)
            Text(short(game.playing))
        }
        .font(.builder(12)).foregroundStyle(Color.faint)
    }
}

struct WideGameCard: View {
    let game: Game
    var stats = false           // profiles show the small rating-and-players line instead of "86% Rating"
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 8).fill(Color.tile)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    RemoteImage(url: game.wide ?? game.icon, fill: true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(game.name).font(.builder(14.5, .bold)).lineLimit(1).frame(height: 18).padding(.top, 12)
            if stats {
                GameStats(game: game).frame(height: 16).padding(.top, 3)
            } else {
                HStack(spacing: 3) {
                    Icon(game.rating == nil ? "two-people" : "thumb-up", size: 15, filled: true)
                    Text(game.rating.map { "\($0)% Rating" } ?? "\(short(game.playing)) Playing")
                }
                .font(.builder(14.5)).foregroundStyle(Color.faint).frame(height: 18).padding(.top, 3)
            }
        }
    }
}
