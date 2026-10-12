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
                if price <= store.profile.robux { confirm = new } else { short = new }       // free ones ask too, like the real app
            }
            .overlay {
                if let it = confirm {
                    BuyItemCard(name: it.name, price: it.price ?? 0, thumb: it.thumb, close: { confirm = nil }) { wear in finish(it, wear: wear) }
                        .transition(.opacity)
                }
            }
            .overlay {
                if let it = short {
                    BuyRobuxAndItem(item: it, close: { short = nil }, plus: { short = nil; open(.robux) }) { finish(it, wear: true) }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.18), value: short?.key)
            .animation(.easeOut(duration: 0.18), value: confirm?.key)
    }

    private func finish(_ it: Item, wear: Bool) {
        guard store.profile.buy(it) == .bought else { return }
        if wear {
            if store.trial?.key != it.key { store.wear(it, true) }
            bought(it)
        } else if store.trial?.key == it.key {
            store.tryOn(nil)        // bought but left off
        }
    }
}

extension View {
    func buying(_ item: Binding<Item?>, open: @escaping (Page) -> Void, bought: @escaping (Item) -> Void = { _ in }) -> some View {
        modifier(Buying(item: item, open: open, bought: bought))
    }
}

// the card roblox shows over the dimmed screen when you buy
struct PopupCard<Content: View>: View {
    let title: String
    let close: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title).font(.builder(20, .bold))
                    Spacer()
                    Button(action: close) { Icon("x", size: 22) }.accessibilityIdentifier("popupClose").accessibilityLabel("Close")
                }
                content
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 15).padding(.top, 19).padding(.bottom, 18)
            .frame(width: 286)
            .background(Color.rgb(25, 26, 31), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tile, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct PopupItemLine: View {
    let name: String
    let price: Int
    let thumb: String?
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            if let thumb { RemoteImage(url: thumb, fill: false).frame(width: 44, height: 44).padding(.top, 2) }
            VStack(alignment: .leading, spacing: 9) {
                Text(name).font(.builder(15.5, .bold)).lineLimit(1)
                Text("Permanent").font(.builder(12.5, .bold)).foregroundStyle(Color.faint)
                HStack(spacing: 5) {
                    Icon("robux", size: 16)
                    Text(grouped(price)).font(.builder(14.5, .bold))
                }
            }
        }
        .padding(.leading, thumb == nil ? 0 : 13).padding(.top, 20)
    }
}

private func popupButton(_ text: String) -> some View {
    Text(text).font(.builder(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 36)
        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
}

private func popupFootnote(_ text: String) -> some View {
    Text(text).font(.builder(12)).foregroundStyle(Color.faint).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 15)
}

struct BuyItemCard: View {
    let name: String
    let price: Int
    let thumb: String?
    let close: () -> Void
    let buy: (_ wear: Bool) -> Void
    @State private var wear = true

    var body: some View {
        PopupCard(title: "Buy item", close: close) {
            PopupItemLine(name: name, price: price, thumb: thumb)
            Button { wear.toggle() } label: {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 3).fill(wear ? Color.white : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white, lineWidth: 1.5))
                        .overlay { if wear { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Color.bg) } }
                        .frame(width: 14, height: 14)
                    Text("Wear item after purchase").font(.builder(14))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("wearAfter").accessibilityValue(wear ? "on" : "off")
            .padding(.top, 24)
            Button {
                close()
                buy(wear)
            } label: { popupButton("Buy") }
            .accessibilityIdentifier("buyItemConfirm")
            .padding(.top, 19)
        }
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
        PopupCard(title: "Buy Robux and item", close: close) {
            PopupItemLine(name: item.name, price: item.price ?? 0, thumb: item.thumb)
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
                        .padding(.horizontal, 14).frame(height: 52)
                        .background(Color.rgb(32, 33, 38), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(i == pick ? Color.white : Color.tile, lineWidth: i == pick ? 2 : 1))
                    }
                    .accessibilityIdentifier("pack-\(packs[i].robux)")
                }
            }
            .padding(.top, 33)
            Button {
                if packs.indices.contains(pick) { store.profile.topUp(packs[pick].robux) }
                close()
                buy()
            } label: { popupButton("Buy") }
            .accessibilityIdentifier("buyRobuxAndItem")
            .padding(.top, 35)
            Button(action: plus) {
                HStack(spacing: 8) {
                    Icon("roblox-plus", size: 18)
                    Text("Get 10% off").font(.builder(16, .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 35).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 8)
            popupFootnote("Your payment method will be charged. Roblox Terms of Use apply.")
        }
    }
}

// MARK: - Game
