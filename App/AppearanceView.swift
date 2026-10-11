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

    private static let categories = ["All": "", "Avatars": "avatar", "Backgrounds": "background", "Body": "body", "Clothing": "shirt"]
    private let order = ["All", "Avatars", "Backgrounds", "Body", "Clothing"]
    private let grid = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            stage
            sheet
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
            AvatarPicture(image: store.avatar).padding(.top, 56).padding(.bottom, 8)
            topControls
            HStack(spacing: 28) {
                Icon("arrow-curl-to-left", size: 22)
                Icon("arrow-curl-to-right", size: 22)
            }
            .font(.builder(17)).foregroundStyle(Color.faint)
            .padding(.horizontal, 18).frame(height: 44).background(Color.black.opacity(0.75), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20).padding(.bottom, 32)
        }
        .foregroundStyle(.white)
        .frame(height: 340)
    }

    private var topControls: some View {
        VStack(spacing: 14) {
            HStack {
                Button { if let openMenu { openMenu() } else { dismiss() } } label: {
                    Icon(openMenu == nil ? "arrow-large-left" : "three-bars-horizontal", size: 28)
                }
                .accessibilityIdentifier("appearanceBack")
                Spacer()
                tabs
                Spacer()
                Button { withAnimation { searching.toggle() } } label: {
                    Icon("magnifying-glass", size: 26)
                }
                .accessibilityIdentifier("searchToggle")
            }
            HStack(alignment: .top) {
                VStack(spacing: 12) {
                    Button { openProfile?() } label: { Headshot(image: store.avatar, crop: store.profile.crop, size: 38) }
                        .accessibilityIdentifier("pillHeadshot")
                    Icon("person-standing-gear", size: 24)
                }
                .padding(5).padding(.bottom, 6).background(Color.black.opacity(0.75), in: Capsule())
                Spacer()
                HStack(spacing: 8) {
                    RobuxIcon(size: 17)
                    Text(short(store.profile.robux)).font(.builder(16, .medium))
                }
                .padding(.horizontal, 16).frame(height: 44).background(Color.black.opacity(0.75), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("robuxPill")
            }
        }
        .padding(.horizontal, 20)
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            tab("Marketplace", on: !customize) { customize = false }
            tab("Customize", on: customize) { customize = true }
        }
        .padding(4).background(Color.black.opacity(0.45), in: Capsule())
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.builder(15, .medium)).padding(.horizontal, 12).frame(height: 34)
                .background(on ? Color.white.opacity(0.18) : .clear, in: Capsule())
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("tab-\(title)")
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(white: 0.35)).frame(width: 40, height: 4).padding(.vertical, 10)
            if searching && !customize { searchBar }
            if !customize { categoryTabs }
            ScrollView {
                if customize { inventory } else { marketplace }
            }
        }
        .background(Color.bg, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .padding(.top, -16)
    }

    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(order, id: \.self) { c in
                        Button {
                            category = c
                            query = ""
                            Task { await load() }
                        } label: {
                            VStack(spacing: 10) {
                                Text(c).font(.builder(17, .semibold))
                                    .foregroundStyle(category == c ? .white : Color.faint)
                                Rectangle().fill(category == c ? Color.white : .clear).frame(height: 2)
                            }
                            .fixedSize()
                        }
                        .accessibilityIdentifier("cat-\(c)")
                    }
                }
                .padding(.leading, 16)
            }
            Icon("three-sliders-horizontal", size: 24).padding(.horizontal, 16).padding(.bottom, 12)
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
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    private var marketplace: some View {
        let assets = results.filter { !$0.bundle }
        let styles = results.filter(\.bundle)
        let top = category == "All" && query.isEmpty
        return VStack(alignment: .leading, spacing: 16) {
            Text(top ? "Recommended For You" : query.isEmpty ? category : "Results").font(.builder(21, .bold))
                .padding(.top, 8)
            if loading { ProgressView().frame(maxWidth: .infinity) }
            if let failure { Text(failure).foregroundStyle(Color.faint) }
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(top ? Array(assets.prefix(3)) : results) { catalogTile($0) }
            }
            if top && !styles.isEmpty { exploreStyles(styles) }
            if top {
                LazyVGrid(columns: grid, spacing: 20) { ForEach(Array(assets.dropFirst(3))) { catalogTile($0) } }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 30)
        .buttonStyle(.plain)
    }

    private func exploreStyles(_ styles: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Explore Styles").font(.builder(21, .bold))
                Spacer()
                Text("See All").font(.builder(14, .medium)).padding(.horizontal, 10).frame(height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { ForEach(styles) { catalogTile($0).frame(width: 118) } }
            }
            .padding(.horizontal, -16).contentMargins(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    private func catalogTile(_ item: Item) -> some View {
        Button { shown = item } label: { tile(item, showCreator: true) }
            .accessibilityIdentifier("catalogItem")
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inventory").font(.builder(21, .bold)).padding(.top, 8)
            Text("Tap to put on or take off. Hold an item to change its price or remove it.").foregroundStyle(Color.faint)
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
        .padding(.horizontal, 16).padding(.bottom, 30)
        .buttonStyle(.plain)
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
