import SwiftUI
import BloxKit

struct AppearanceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var customize = false
    @State private var searching = false
    @State private var query = ""
    @State private var results: [Item] = []
    @State private var loading = false
    @State private var failure: String?
    @State private var shown: Item?
    @State private var pricing: Item?
    @State private var priceText = ""
    private let grid = [GridItem(.adaptive(minimum: 104), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            stage
            sheet
        }
        .background(Color(white: 0.9))
        .task { if results.isEmpty { await load("") } }
        .sheet(item: $shown) { ItemSheet(item: $0) }
        .alert("Price", isPresented: Binding(get: { pricing != nil }, set: { if !$0 { pricing = nil } })) {
            TextField("0 is Free, empty is Off Sale", text: $priceText).keyboardType(.numberPad)
            Button("Save") { savePrice() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(pricing?.name ?? "") }
    }

    private var stage: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.86), Color(white: 0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
            AvatarPicture(image: store.avatar).padding(.top, 50).padding(.bottom, 10)
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "arrow.left").font(.system(size: 24)) }
                        .accessibilityIdentifier("appearanceBack")
                    Spacer()
                    tabs
                    Spacer()
                    Button { withAnimation { searching.toggle() } } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 24))
                    }
                    .accessibilityIdentifier("searchToggle")
                }
                HStack {
                    VStack(spacing: 18) {
                        Headshot(image: store.avatar, crop: store.profile.crop, size: 64)
                        Image(systemName: "figure.stand").font(.system(size: 22))
                    }
                    .padding(8).background(.white, in: Capsule())
                    Spacer()
                    HStack(spacing: 8) {
                        RobuxIcon(size: 22)
                        Text(short(store.profile.robux)).font(.system(size: 21, weight: .medium))
                    }
                    .padding(.horizontal, 22).frame(height: 60).background(.white, in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("robuxPill")
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 380)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tab("Marketplace", on: !customize) { customize = false }
            tab("Customize", on: customize) { customize = true }
        }
        .padding(5).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 20, weight: .medium)).padding(.horizontal, 14).frame(height: 46)
                .background(on ? Color(white: 0.88) : .clear, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(on ? .primary : Color.faint)
        }
        .accessibilityIdentifier("tab-\(title)")
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(white: 0.8)).frame(width: 40, height: 5).padding(.vertical, 10)
            if searching && !customize { searchBar }
            ScrollView {
                if customize { inventory } else { marketplace }
            }
        }
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.faint)
            TextField("Search the Marketplace", text: $query).submitLabel(.search)
                .onSubmit { Task { await load(query) } }
                .accessibilityIdentifier("catalogSearch")
        }
        .font(.system(size: 19)).padding(.horizontal, 16).frame(height: 50)
        .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 22).padding(.bottom, 8)
    }

    private var marketplace: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(query.isEmpty ? "Recommended For You" : "Results").font(.system(size: 28, weight: .bold))
            if loading { ProgressView().frame(maxWidth: .infinity) }
            if let failure { Text(failure).foregroundStyle(Color.faint) }
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(results) { item in
                    Button { shown = item } label: { tile(item, showCreator: true) }
                        .accessibilityIdentifier("catalogItem")
                }
            }
        }
        .padding(.horizontal, 22).padding(.bottom, 30)
        .buttonStyle(.plain)
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Inventory").font(.system(size: 28, weight: .bold))
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
        .padding(.horizontal, 22).padding(.bottom, 30)
        .buttonStyle(.plain)
    }

    private func tile(_ item: Item, showCreator: Bool) -> some View {
        let worn = store.profile.owns(item)?.wearing ?? false
        return ItemCard(item: item, showCreator: showCreator)
            .overlay(alignment: .topTrailing) {
                if worn {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 26))
                        .foregroundStyle(.white, Color.bloxBlue).padding(6)
                }
            }
    }

    private func load(_ keyword: String) async {
        loading = true
        failure = nil
        do {
            results = try await Roblox.search(keyword.trimmingCharacters(in: .whitespaces))
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
            Text(item.name).font(.system(size: 26, weight: .bold))
            HStack(spacing: 6) {
                Text("By \(item.creator)").foregroundStyle(Color.faint)
                if item.creator == "Roblox" { VerifiedBadge(size: 16) }
            }
            .font(.system(size: 18))
            PriceLine(price: item.price, size: 20)
            Button {
                store.profile.wear(item, !worn)
                dismiss()
            } label: {
                Text(worn ? "Take off" : "Wear").font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(worn ? Color.field : Color.bloxBlue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(worn ? .primary : Color.white)
            }
            .accessibilityIdentifier("wearButton")
            .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
    }
}
