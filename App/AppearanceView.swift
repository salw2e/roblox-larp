import SwiftUI
import BloxKit

struct AppearanceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var openMenu: (() -> Void)?
    var openProfile: (() -> Void)?

    @State private var customize = false
    @State private var searching = false
    @State private var query = ""
    @State private var category = "All"
    @State private var results: [Item] = []
    @State private var loading = false
    @State private var failure: String?
    @State private var shown: Item?
    @State private var pricing: Item?
    @State private var priceText = ""
    @State private var raised = false
    @GestureState private var pull: CGFloat = 0
    private let restTop: CGFloat = 316, raisedTop: CGFloat = 48

    private static let categories = ["All": "", "Avatars": "avatar", "Backgrounds": "background", "Body": "body", "Clothing": "shirt"]
    private let order = ["All", "Avatars", "Backgrounds", "Body", "Clothing"]
    private let grid = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), alignment: .top)]

    var body: some View {
        GeometryReader { geo in
            let top = min(max((raised ? raisedTop : restTop) + pull, raisedTop), restTop)
            ZStack(alignment: .top) {
                stage
                sheet.frame(height: max(geo.size.height - top, 0)).offset(y: top)
            }
        }
        .background(Color.bg)
        .task { if results.isEmpty { await load() } }
        .sheet(item: $shown) { ItemSheet(item: $0) }
        .alert("Price", isPresented: Binding(get: { pricing != nil }, set: { if !$0 { pricing = nil } })) {
            TextField("0 is Free, empty is Off Sale", text: $priceText).keyboardType(.numberPad)
            Button("Save") { savePrice() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(pricing?.name ?? "") }
    }

    private var stage: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.2), Color(white: 0.3)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
            AvatarStage().padding(.top, 50).padding(.bottom, 22)
            topControls
            if store.profile.needsRedraw || store.drawing || !store.drawNote.isEmpty { redrawControl }
            HStack(spacing: 22) {
                Icon("arrow-curl-to-left", size: 20)
                Icon("arrow-curl-to-right", size: 20)
            }
            .foregroundStyle(Color(white: 0.38))
            .padding(.horizontal, 12).frame(height: 44).background(Color.pill, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20).padding(.bottom, 33)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 332)
    }

    private var redrawControl: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if store.profile.needsRedraw || store.drawing {
                Button { Task { await store.redraw() } } label: {
                    HStack(spacing: 8) {
                        if store.drawing { ProgressView().tint(Color.ink) } else { Icon("arrow-spin-clockwise", size: 18) }
                        Text(store.drawing ? "Drawing…" : "Update avatar").font(.builder(14.5, .medium))
                    }
                    .padding(.horizontal, 14).frame(height: 44).background(Color.pill, in: Capsule())
                }
                .disabled(store.drawing)
                .accessibilityIdentifier("updateAvatar")
            }
            if !store.drawNote.isEmpty {
                Text(store.drawNote).font(.builder(12)).multilineTextAlignment(.trailing).frame(maxWidth: 200, alignment: .trailing)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.pill.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("drawNote")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 20).padding(.bottom, 33)
    }

    private var topControls: some View {
        VStack(spacing: 13) {
            HStack(spacing: 0) {
                Button { if let openMenu { openMenu() } else { dismiss() } } label: {
                    Icon(openMenu == nil ? "arrow-large-left" : "three-bars-horizontal", size: 25)
                        .overlay(alignment: .topTrailing) {
                            if openMenu != nil { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
                        }
                }
                .accessibilityIdentifier("appearanceBack")
                Spacer()
                Button { withAnimation { searching.toggle() } } label: {
                    Icon("magnifying-glass", size: 25).frame(width: 26)
                }
                .accessibilityIdentifier("searchToggle")
            }
            .frame(height: 28)
            .overlay(tabs)
            .padding(.trailing, 3)
            HStack(alignment: .top) {
                VStack(spacing: 13) {
                    Button { openProfile?() } label: { Headshot(image: store.avatar, crop: store.profile.crop, size: 36) }
                        .accessibilityIdentifier("pillHeadshot")
                    Icon("person-standing-gear", size: 24).frame(height: 24)
                }
                .padding(4).padding(.bottom, 6).background(Color.pill, in: Capsule())
                Spacer()
                HStack(spacing: 6) {
                    Icon("robux", size: 17)
                    Text(short(store.profile.robux)).font(.builder(14.5))
                }
                .padding(.horizontal, 16).frame(height: 44).background(Color.pill, in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("robuxPill")
            }
        }
        .padding(.horizontal, 20).padding(.top, 6)
    }

    private var tabs: some View {
        HStack(spacing: 1) {
            tab("Marketplace", on: !customize) { customize = false }
            tab("Customize", on: customize) { customize = true }
        }
        .padding(4).background(Color.tile.opacity(0.9), in: Capsule())
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.builder(12, .medium)).padding(.horizontal, 8).frame(height: 31)
                .background(on ? Color(red: 0.26, green: 0.27, blue: 0.31) : .clear, in: Capsule())
                .foregroundStyle(Color.ink)
        }
        .accessibilityIdentifier("tab-\(title)")
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(red: 0.19, green: 0.19, blue: 0.22)).frame(width: 36, height: 4)
                .padding(.top, 10).padding(.bottom, customize ? 12 : 20)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
                .gesture(sheetDrag)
                .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { raised.toggle() } }
                .accessibilityIdentifier("sheetHandle")
            if searching && !customize { searchBar }
            if !customize { categoryTabs }
            ScrollView {
                if customize { inventory } else { marketplace }
            }
        }
        .background(Color.bg, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
    }

    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($pull) { g, pull, _ in pull = g.translation.height }
            .onEnded { g in
                let goingUp = g.predictedEndTranslation.height < -60, goingDown = g.predictedEndTranslation.height > 60
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    raised = goingUp ? true : goingDown ? false : raised
                }
            }
    }

    private var categoryTabs: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(order, id: \.self) { c in
                        Button {
                            category = c
                            query = ""
                            Task { await load() }
                        } label: {
                            VStack(spacing: 7.5) {
                                Text(c).font(.builder(16, .bold)).frame(height: 20).padding(.horizontal, 11)
                                    .foregroundStyle(category == c ? Color.ink : Color.dim)
                                Rectangle().fill(category == c ? Color.ink : .clear).frame(height: 2.5)
                            }
                            .fixedSize()
                        }
                        .accessibilityIdentifier("cat-\(c)")
                    }
                }
            }
            Icon("three-sliders-horizontal", size: 22).frame(height: 20).padding(.leading, 8).padding(.trailing, 22)
        }
    }

    private var searchBar: some View {
        HStack {
            Icon("magnifying-glass", size: 18).foregroundStyle(Color.faint)
            TextField("Search the Marketplace", text: $query).submitLabel(.search)
                .onSubmit { Task { await load() } }
                .accessibilityIdentifier("catalogSearch")
        }
        .font(.builder(16)).padding(.horizontal, 12).frame(height: 40)
        .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 15).padding(.bottom, 10)
    }

    private var marketplace: some View {
        let assets = results.filter { !$0.bundle }
        let styles = results.filter(\.bundle)
        let top = category == "All" && query.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            Text(top ? "Recommended For You" : query.isEmpty ? category : "Results").font(.builder(20, .bold))
                .frame(height: 24).padding(.top, 10.5).padding(.bottom, 12)
            if loading { ProgressView().frame(maxWidth: .infinity).padding(.bottom, 12) }
            if let failure { Text(failure).foregroundStyle(Color.faint).padding(.bottom, 12) }
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(top ? Array(assets.prefix(3)) : results) { catalogTile($0) }
            }
            if top && !styles.isEmpty { exploreStyles(styles) }
            if top {
                LazyVGrid(columns: grid, spacing: 20) { ForEach(Array(assets.dropFirst(3))) { catalogTile($0) } }
                    .padding(.top, 26)
            }
        }
        .padding(.leading, 15).padding(.trailing, 14).padding(.bottom, 30)
        .buttonStyle(PressStyle())
    }

    private func exploreStyles(_ styles: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Explore Styles").font(.builder(20, .bold)).frame(height: 24)
                Spacer()
                Text("See All").font(.builder(12, .medium)).frame(width: 55, height: 25)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ink, lineWidth: 1))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { ForEach(styles) { catalogTile($0).frame(width: 115) } }
            }
            .padding(.leading, -15).padding(.trailing, -14).contentMargins(.leading, 15).contentMargins(.trailing, 14)
        }
        .padding(.top, 26)
    }

    private func catalogTile(_ item: Item) -> some View {
        Button { shown = item } label: { tile(item, showCreator: true) }
            .accessibilityIdentifier("catalogItem")
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory").font(.builder(20, .bold)).frame(height: 24).padding(.top, 10)
            Text("Tap to put on or take off. Hold an item to change its price or remove it.").font(.builder(14.5)).foregroundStyle(Color.faint)
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(store.profile.items) { item in
                    Button { store.profile.wear(item, !item.wearing) } label: { tile(item, showCreator: false) }
                        .accessibilityIdentifier("inventoryItem")
                        .contextMenu {
                            Button("Change price") { priceText = item.price.map(String.init) ?? ""; pricing = item }
                            Button("Remove", role: .destructive) { store.profile.items.removeAll { $0 == item } }
                        }
                }
            }
        }
        .padding(.leading, 15).padding(.trailing, 14).padding(.bottom, 30)
        .buttonStyle(PressStyle())
    }

    private func tile(_ item: Item, showCreator: Bool) -> some View {
        let worn = store.profile.owns(item)?.wearing ?? false
        return ItemCard(item: item, showCreator: showCreator)
            .overlay(alignment: .topTrailing) {
                if worn {
                    Image(systemName: "checkmark.circle.fill").font(.builder(24))
                        .foregroundStyle(.white, Color.bloxBlue).padding(6)
                }
            }
    }

    private func load() async {
        loading = true
        failure = nil
        let q = query.trimmingCharacters(in: .whitespaces)
        do {
            results = try await Roblox.search(q.isEmpty ? Self.categories[category] ?? "" : q)
            if results.isEmpty { failure = "Nothing found." }
        } catch {
            failure = error.localizedDescription
        }
        loading = false
    }

    private func savePrice() {
        guard let item = pricing, let i = store.profile.items.firstIndex(of: item) else { return }
        let t = priceText.trimmingCharacters(in: .whitespaces)
        store.profile.items[i].price = t.isEmpty ? nil : number(from: t)
        pricing = nil
    }
}

struct ItemSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    var body: some View {
        let worn = store.profile.owns(item)?.wearing ?? false
        VStack(alignment: .leading, spacing: 12) {
            Thumb(url: item.thumb).frame(maxWidth: 260).frame(maxWidth: .infinity)
            Text(item.name).font(.builder(24, .bold))
            HStack(spacing: 6) {
                Text("By \(item.creator)").foregroundStyle(Color.faint)
                if item.showsCreatorCheck { VerifiedBadge(size: 16) }
            }
            .font(.builder(17))
            PriceLine(price: item.price, size: 19)
            Button {
                store.profile.wear(item, !worn)
                dismiss()
            } label: {
                Text(worn ? "Take off" : "Wear").font(.builder(18, .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(worn ? Color.field : Color.bloxBlue, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("wearButton")
            .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.bg)
    }
}
