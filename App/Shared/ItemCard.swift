import SwiftUI
import SalBloxKit

struct Thumb: View {
    let url: String?
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.tile)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RemoteImage(url: url, fill: false).padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PriceLine: View {
    let price: Int?
    var size: CGFloat = 14.5
    var body: some View {
        HStack(spacing: 3) {
            if let price, price > 0 { Icon("robux", size: size * 1.15) }
            Text(priceText(price)).font(.builder(size))
        }
        .foregroundStyle(Color.ink)
    }
}

struct ItemCard: View {
    let item: Item
    var showCreator = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Thumb(url: item.thumb)
            Text(item.name).font(.builder(14.5, .bold)).lineLimit(1).frame(height: 18).padding(.top, 10)
            if showCreator {
                HStack(spacing: 4) {
                    Text(item.creator).foregroundStyle(Color.faint).lineLimit(1)
                    if item.showsCreatorCheck { VerifiedBadge(size: 12) }
                }
                .font(.builder(14.5)).frame(height: 18).padding(.top, 3)
            }
            PriceLine(price: item.price).frame(height: 18).padding(.top, showCreator ? 6 : 3)
        }
    }
}
