import SwiftUI
import SalBloxKit

struct ItemPage: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let item: Item
    var close: () -> Void = {}
    var isRoot = true
    var open: (Page) -> Void = { _ in }
    @State private var detail: ItemDetail?
    @State private var sharp: String?
    @State private var partPictures: [Int64: String] = [:]
    @State private var also: [Item] = []
    @State private var loaded = false
    @State private var wholeText = false
    @State private var buying: Item?

    var body: some View {
        let shown = detail?.item ?? item
        VStack(spacing: 0) {
            HStack {
                Button { if isRoot { close() } else { dismiss() } } label: {
                    Icon(isRoot ? "x" : "chevron-large-left", size: 26).frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("itemClose").accessibilityLabel(isRoot ? "Close" : "Back")
                Spacer()
            }
            .padding(.leading, 10).frame(height: 44)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(item.name).font(.builder(20, .bold)).lineLimit(2)
                        if shown.limited == true {
                            Text("Limited").font(.builder(12, .bold)).padding(.horizontal, 8).frame(height: 22)
                                .background(Color.online, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.black)
                        }
                    }
                    .padding(.top, 21)
                    RemoteImage(url: sharp ?? item.thumb, fill: false).frame(height: 220).frame(maxWidth: .infinity).padding(.top, 16)
                    if let parts = detail?.parts, !parts.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
                            ForEach(parts) { p in
                                VStack(alignment: .leading, spacing: 8) {
                                    Thumb(url: partPictures[p.id])
                                    Text(p.name).font(.builder(14.5, .bold)).lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 24)
                    }
                    if let d = detail?.description, !d.isEmpty {
                        VStack(spacing: 4) {
                            Text(d).font(.builder(16)).foregroundStyle(Color.faint).lineLimit(wholeText ? nil : 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { withAnimation(.easeOut(duration: 0.2)) { wholeText.toggle() } } label: {
                                Icon(wholeText ? "chevron-small-up" : "chevron-small-down", size: 22).frame(width: 44, height: 24)
                            }
                            .accessibilityLabel(wholeText ? "Less" : "More")
                        }
                        .padding(.top, 24)
                    }
                    if let f = detail?.favorites {
                        HStack(spacing: 14) {
                            Icon("star", size: 40, filled: true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(short(f)).font(.builder(26, .bold))
                                Text("Favorites").font(.builder(12))
                            }
                        }
                        .padding(.top, 24).padding(.leading, 10)
                    }
                    VStack(spacing: 0) {
                        if !shown.creator.isEmpty {
                            row("Creator") {
                                HStack(spacing: 6) {
                                    Text(shown.creator).font(.builder(16, .bold))
                                    if shown.showsCreatorCheck { VerifiedBadge(size: 14) }
                                    Icon("arrow-large-right", size: 18)
                                }
                            }
                        }
                        if let t = detail?.type, !t.isEmpty { row("Type") { Text(t).font(.builder(16)) } }
                        if let d = detail { row("Placement") { Text(d.placement).font(.builder(16)) } }
                    }
                    .padding(.top, 20)
                    if let owned = store.profile.owns(item) {
                        HStack(spacing: 6) {
                            Icon("circle-check", size: 18, filled: true)
                            Text(owned.wearing ? "You own this item and are wearing it" : "You own this item").font(.builder(14.5))
                        }
                        .foregroundStyle(Color.faint).padding(.top, 20).accessibilityIdentifier("itemOwned")
                    } else if shown.price == nil, loaded {
                        Text("This item is not currently for sale.").font(.builder(14.5)).foregroundStyle(Color.faint)
                            .padding(.top, 20).accessibilityIdentifier("notForSale")
                    }
                    if loaded, detail == nil {
                        Button { Task { await load() } } label: {
                            Text("Couldn't load this item's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        .padding(.top, 24).accessibilityIdentifier("itemRetry")
                    }
                    if !also.isEmpty {
                        Text("You May Also Like").font(.builder(20, .bold)).padding(.top, 32).padding(.bottom, 12)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 20) {
                            ForEach(also) { a in
                                NavigationLink(value: a) { ItemCard(item: a) }.buttonStyle(PressStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            bar(shown)
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .buying($buying, open: { close(); open($0) }) { it in if store.trial?.key == it.key { store.keepTrial() } }
        .task { await load() }
    }

    private func bar(_ shown: Item) -> some View {
        let owned = store.profile.owns(item)
        let trying = store.trial?.key == item.key
        return HStack(spacing: 14) {
            Group {
                if let owned {
                    Button { store.wear(item, !owned.wearing) } label: {
                        Text(owned.wearing ? "Take Off" : "Wear").font(.builder(16, .bold)).frame(maxWidth: .infinity).frame(height: 40)
                            .background(owned.wearing ? Color.tile : Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("wearButton")
                } else if let price = shown.price {
                    Button { buying = shown } label: {
                        HStack(spacing: 6) {
                            if price == 0 { Text("Get").font(.builder(16, .bold)) } else {
                                Icon("robux", size: 20)
                                Text(grouped(price)).font(.builder(16, .bold))
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("buyButton")
                } else {
                    Text("Off Sale").font(.builder(16, .bold)).foregroundStyle(Color.faint).frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .foregroundStyle(.white)
            .buttonStyle(PressStyle())
            Menu {
                if owned == nil {
                    Button(trying ? "Take Off" : "Try On") { store.tryOn(trying ? nil : shown) }
                } else {
                    Button("Remove from inventory", role: .destructive) { store.profile.items.removeAll { $0.same(item) } }
                }
            } label: {
                Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: Circle())
            }
            .accessibilityIdentifier("itemMore").accessibilityLabel("More")
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        .background(Color.bg)
    }

    private func row<V: View>(_ name: String, @ViewBuilder _ value: () -> V) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).font(.builder(16)).foregroundStyle(Color.faint)
                Spacer()
                value()
            }
            .frame(height: 55)
            Divider().overlay(Color.tile)
        }
    }

    private func load() async {
        loaded = false
        async let d = Roblox.itemDetails([item])
        async let picture = Roblox.bigThumb(item)
        detail = await d.first
        sharp = await picture
        loaded = true
        if let parts = detail?.parts, !parts.isEmpty {
            let pics = await Roblox.withThumbs(parts)
            partPictures = Dictionary(pics.compactMap { p in p.thumb.map { (p.id, $0) } }, uniquingKeysWith: { a, _ in a })
        }
        also = await Roblox.recommended(for: detail?.item ?? item, bundleType: detail?.bundleType)
    }
}
