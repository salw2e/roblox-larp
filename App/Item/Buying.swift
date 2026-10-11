import SwiftUI
import SalBloxKit

struct Buying: ViewModifier {
    @EnvironmentObject var store: Store
    @Binding var item: Item?
    var open: (Page) -> Void
    var bought: (Item) -> Void
    @State private var confirm: Item?
    @State private var short: Item?

    func body(content: Content) -> some View {
        content
            .onChange(of: item) { _, new in
                guard let new, let price = new.price else { return }
                item = nil
                if price == 0 { finish(new) } else if price <= store.profile.robux { confirm = new } else { short = new }
            }
            .alert("Buy Item", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), presenting: confirm) { it in
                Button("Buy Now") { finish(it) }
                Button("Cancel", role: .cancel) {}
            } message: { it in
                let after = store.profile.robux - (it.price ?? 0)
                Text("Would you like to buy \(it.name) for \(grouped(it.price ?? 0)) Robux? Your balance after this transaction will be \(grouped(after)) Robux.")
            }
            .overlay {
                if let it = short {
                    BuyRobuxAndItem(item: it, close: { short = nil }, plus: { short = nil; open(.robux) }) { finish(it) }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.18), value: short?.key)
    }

    private func finish(_ it: Item) {
        if store.profile.buy(it) == .bought { bought(it) }
    }
}

extension View {
    func buying(_ item: Binding<Item?>, open: @escaping (Page) -> Void, bought: @escaping (Item) -> Void = { _ in }) -> some View {
        modifier(Buying(item: item, open: open, bought: bought))
    }
}

struct BuyRobuxAndItem: View {
    @EnvironmentObject var store: Store
    let item: Item
    let close: () -> Void
    let plus: () -> Void
    let buy: () -> Void
    @State private var pick = 0

    var body: some View {
        let packs = robuxPacksFor(shortfall: (item.price ?? 0) - store.profile.robux)
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Buy Robux and item").font(.builder(18, .bold))
                    Spacer()
                    Button(action: close) { Icon("x", size: 22) }.accessibilityLabel("Close")
                }
                HStack(spacing: 14) {
                    RemoteImage(url: item.thumb, fill: false).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.builder(14.5, .bold)).lineLimit(1)
                        HStack(spacing: 4) {
                            Icon("robux", size: 16)
                            Text(grouped(item.price ?? 0)).font(.builder(14.5, .bold))
                        }
                    }
                }
                .padding(.top, 18)
                VStack(spacing: 12) {
                    ForEach(packs.indices, id: \.self) { i in
                        Button { pick = i } label: {
                            HStack(spacing: 6) {
                                Icon("robux", size: 18)
                                Text(grouped(packs[i].robux)).font(.builder(17, .bold))
                                if packs[i].better {
                                    HStack(spacing: 3) {
                                        Icon("tag", size: 11)
                                        Text("Better value").font(.builder(10.5, .medium))
                                    }
                                    .padding(.horizontal, 7).frame(height: 20).background(Color.tile, in: Capsule())
                                }
                                Spacer()
                                Text(packs[i].price).font(.builder(16, .bold))
                            }
                            .padding(.horizontal, 14).frame(height: 54)
                            .background(Color.rgb(32, 33, 38), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(i == pick ? Color.white : Color.tile, lineWidth: i == pick ? 2 : 1))
                        }
                        .accessibilityIdentifier("pack-\(packs[i].robux)")
                    }
                }
                .padding(.top, 18)
                Button {
                    if packs.indices.contains(pick) { store.profile.topUp(packs[pick].robux) }
                    close()
                    buy()
                } label: {
                    Text("Buy").font(.builder(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("buyRobuxAndItem")
                .padding(.top, 26)
                Button(action: plus) {
                    HStack(spacing: 8) {
                        Icon("premium", size: 18)
                        Text("Get 10% off").font(.builder(16, .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 10)
                Text("Nothing is charged: the Robux go to your pretend balance.").font(.builder(10.5)).foregroundStyle(Color.faint)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 12)
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 321)
            .background(Color.rgb(25, 26, 31), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tile, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Game
