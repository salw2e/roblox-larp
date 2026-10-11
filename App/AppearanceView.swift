import SwiftUI
import BloxKit

struct AppearanceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var phase
    var active = true
    var openMenu: () -> Void = {}
    var open: (Page) -> Void = { _ in }

    @State private var customize = false
    @State private var searching = false
    @State private var query = ""
    @State private var category = "All"
    @State private var sub: String?
    @State private var sort = Sort.relevance
    @State private var results: [Item] = []
    @State private var styles: [Item] = []
    @State private var next: String?
    @State private var loading = false
    @State private var failure: String?
    @State private var asked = 0
    @State private var pricing: Item?
    @State private var priceText = ""
    @State private var priceProblem = ""
    @State private var raised = false
    @State private var shelf = Shelf.avatars    // Customize's tab
    @State private var slotPicked: [Shelf: String] = [:]
    @State private var suggested: [String: [Item]] = [:]
    @State private var plusOnes: [Item] = []
    @State private var buying: Item?                         // the try-on bar's price button
    @State private var naming = false
    @State private var outfitName = ""
    @State private var details: Outfit?
    @State private var renaming: Outfit?
    @GestureState private var pull: CGFloat = 0
    @FocusState private var typing: Bool
    private let restTop: CGFloat = 316, raisedTop: CGFloat = 48

    enum Sort: String, CaseIterable { case relevance = "Relevance", low = "Price: low to high", high = "Price: high to low" }

    private static let categories: [String: String] = [
        "Avatars": "kfHzJwaNYM8s2CWRqYUhRa", "Backgrounds": "ijFKKMZq6jV4gkJQC4v7L1",
        "Body": "mwkR3QvDBVzYk4o9RAVVa2", "Clothing": "5G3bZScC9Hxp2D2EUtGSNm", "Accessories": "wNYJso48d1XnhMyFWT3oX3",
        "Animations": "9fPpW3SJ6UkieQU5jJ4dgP", "Makeup": "dBM565GC3YYTdi9UKvr87Z",
    ]
    private static let subcategories: [String: [(name: String, id: String)]] = [
        "Body": [("Full Bodies", "kfHzJwaNYM8s2CWRqYUhRa"), ("Hair", "d6a7M7r9MMrpf7z7VxW9ZS"), ("Heads", "s5NLP7BS9PRLKvUVca4XKg")],
        "Clothing": [("Shirts", "pJ71PxerdfEuarTNRtSZYs"), ("T-Shirts", "fLRqNzGqjX7MzcqeMro9hc"), ("Sweaters", "31M6WgEMmyq9TTfk3pUUpZ"),
                     ("Jackets", "kPZpEVNdProGcqMbj1jDKJ"), ("Pants", "1MvRtnnsy2FJWmkErSBxBa"), ("Dresses & Skirts", "oSSCBSqkQPZu6HataAUAxB"),
                     ("Bodysuits", "u5jaNLyf2ZhvR95GS37ui5"), ("Shorts", "etAPg889P243JyjdbZCXhw"), ("Shoes", "uLRgNoJ1awZkhpVw9WyvKo"),
                     ("Classic Shirts", "2a2rf9qyeTd8W5iegK2Prc"), ("Classic T-Shirts", "43H35nJKHzCQM63q3wPaJG"),
                     ("Classic Pants", "49cFNAJWuwiJJVUSADG6DR")],
        "Accessories": [("Head", "thukPQUFe5EHxRrtsgq43u"), ("Face", "b5rkQhGSfwhfTK177y6ERa"), ("Neck", "tvckLAbtDAGwF9Y2sph2Ce"),
                        ("Shoulder", "8i1sggNTrxoN799hpRrR1S"), ("Front", "kj535RzJxHTCnXPBLo5KaE"), ("Back", "7yGywzp5JeDsNjhXWJqSw3"),
                        ("Waist", "6jYQPDtkVwQZcKtvVpyYAN"), ("Gear", "gUtxkR951g3VPgRkb5ay8u")],
        "Animations": [("Bundles", "whf6kUVBwk2xdwKUmRYN6G"), ("Emotes", "ioNxAT977DFP2hMnAJbsbF")],
        "Makeup": [("Looks", "dBM565GC3YYTdi9UKvr87Z"), ("Eyes", "1e7vNivWk2To6BdYJt5RGF"), ("Lips", "c3PEmGVddwsc6bKqtuR7rC"),
                   ("Face", "tm9VSS61JdHJGtKvbjKa4D"), ("Eyelashes", "4zqsNnG4Tp7xZThAEpv2dN"), ("Eyebrows", "1cMbsG373EMD4ncRqGhtyZ")],
    ]
    private let order = ["All", "Avatars", "Backgrounds", "Body", "Clothing", "Accessories", "Animations", "Makeup"]
    private var taxonomy: String? { sub ?? Self.categories[category] }
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
        .task(id: active) { if active, results.isEmpty { await load() } }
        .onChange(of: phase) { _, now in
            if now == .active, active, results.isEmpty, !loading { Task { await load() } }
        }
        .alert("Price", isPresented: Binding(get: { pricing != nil }, set: { if !$0 { pricing = nil } })) {
            TextField("0 is Free, empty is Off Sale", text: $priceText).keyboardType(.numberPad)
            Button("Save") { savePrice() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(pricing?.name ?? "") }
        .alert("Price not changed", isPresented: Binding(get: { !priceProblem.isEmpty }, set: { if !$0 { priceProblem = "" } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(priceProblem) }
        .buying($buying, open: open) { it in if store.trial?.key == it.key { store.keepTrial() } }
        .onChange(of: active) { _, on in if !on { store.tryOn(nil) } }
    }

    private var stage: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.2), Color(white: 0.3)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
            BackdropPicture().ignoresSafeArea(edges: .top)
            AvatarStage().padding(.top, 50).padding(.bottom, 22)
            topControls
            if store.drawing || !store.drawNote.isEmpty { drawingStatus }
            HStack(spacing: 22) {
                Button { store.undo() } label: { Icon("arrow-curl-to-left", size: 20) }
                    .disabled(store.undone.isEmpty).foregroundStyle(store.undone.isEmpty ? Color(white: 0.38) : Color.ink)
                    .accessibilityIdentifier("undoWear").accessibilityLabel("Undo")
                Button { store.redo() } label: { Icon("arrow-curl-to-right", size: 20) }
                    .disabled(store.redone.isEmpty).foregroundStyle(store.redone.isEmpty ? Color(white: 0.38) : Color.ink)
                    .accessibilityIdentifier("redoWear").accessibilityLabel("Redo")
            }
            .padding(.horizontal, 12).frame(height: 44).background(Color.pill, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20).padding(.bottom, 33)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 332)
    }

    private var drawingStatus: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if store.drawing {
                ProgressView().tint(Color.ink).frame(width: 36, height: 36).background(Color.pill, in: Circle())
                    .accessibilityIdentifier("drawingNow").accessibilityLabel("Updating your avatar")
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
                Button(action: openMenu) {
                    Icon("three-bars-horizontal", size: 25)
                        .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
                }
                .accessibilityIdentifier("appearanceMenu").accessibilityLabel("Menu")
                Spacer()
                Button(action: toggleSearch) { Icon("magnifying-glass", size: 25).frame(width: 26) }
                    .accessibilityIdentifier("searchToggle").accessibilityLabel("Search the Marketplace")
            }
            .frame(height: 28)
            .overlay(tabs)
            .padding(.trailing, 3)
            HStack(alignment: .top) {
                VStack(spacing: 13) {
                    Button { open(.profile) } label: { Headshot(image: store.avatar, crop: store.profile.crop, size: 36) }
                        .accessibilityIdentifier("pillHeadshot").accessibilityLabel("Your profile")
                    Button { customize = true } label: { Icon("person-standing-gear", size: 24).frame(height: 24) }
                        .accessibilityIdentifier("avatarSettings").accessibilityLabel("Customize avatar")
                }
                .padding(4).padding(.bottom, 6).background(Color.pill, in: Capsule())
                Spacer()
                Button { open(.robux) } label: {
                    HStack(spacing: 6) {
                        Icon("robux", size: 17)
                        Text(short(store.profile.robux)).font(.builder(14.5))
                    }
                    .padding(.horizontal, 16).frame(height: 44).background(Color.pill, in: Capsule())
                }
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
            VStack(spacing: 0) {
                Capsule().fill(Color(red: 0.19, green: 0.19, blue: 0.22)).frame(width: 36, height: 4)
                    .padding(.top, 10).padding(.bottom, customize ? 12 : 20)
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                    .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { raised.toggle() } }
                    .accessibilityIdentifier("sheetHandle").accessibilityLabel(raised ? "Lower the list" : "Raise the list")
                    .accessibilityAddTraits(.isButton)
                if searching && !customize { searchBar }
                if customize { shelfTabs } else { categoryTabs; subTabs }
            }
            .simultaneousGesture(sheetDrag)
            ScrollView {
                if customize { inventory } else { marketplace }
            }
            .refreshable { if !customize { await load() } }
            if let t = store.trial, !customize { trialBar(t) }
        }
        .background(Color.bg, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
    }

    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($pull) { g, pull, _ in
                pull = abs(g.translation.height) > abs(g.translation.width) ? g.translation.height : 0
            }
            .onEnded { g in
                guard abs(g.translation.height) > abs(g.translation.width) else { return }
                let goingUp = g.predictedEndTranslation.height < -60, goingDown = g.predictedEndTranslation.height > 60
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    raised = goingUp ? true : goingDown ? false : raised
                }
            }
    }

    private func underlined(_ title: String, on: Bool) -> some View {
        VStack(spacing: 7.5) {
            Text(title).font(.builder(16, .bold)).frame(height: 20).padding(.horizontal, 11)
                .foregroundStyle(on ? Color.ink : Color.dim)
            Rectangle().fill(on ? Color.ink : .clear).frame(height: 2.5)
        }
        .fixedSize()
    }

    @ViewBuilder
    private var subTabs: some View {
        if let subs = Self.subcategories[category] {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 23) {
                    ForEach(subs, id: \.id) { s in
                        Button {
                            sub = sub == s.id ? nil : s.id
                            Task { await load() }
                        } label: {
                            Text(s.name).font(.builder(14.5, .medium)).foregroundStyle(sub == s.id ? Color.ink : Color.dim)
                        }
                        .accessibilityIdentifier("sub-\(s.name)")
                    }
                }
                .frame(height: 36)
            }
            .contentMargins(.horizontal, 18)
            .padding(.top, 4)
        }
    }

    private var shelfTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Shelf.allCases, id: \.self) { s in
                    Button { shelf = s } label: { underlined(s.rawValue, on: shelf == s) }
                        .accessibilityIdentifier("shelf-\(s.rawValue)")
                }
            }
        }
    }

    private var categoryTabs: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(order, id: \.self) { c in
                        Button { choose(c) } label: { underlined(c, on: category == c) }
                            .accessibilityIdentifier("cat-\(c)")
                    }
                }
            }
            Menu {
                Picker("Sort", selection: $sort) { ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            } label: {
                Icon("three-sliders-horizontal", size: 22).frame(height: 20).padding(.leading, 8).padding(.trailing, 22)
            }
            .accessibilityIdentifier("sortMenu").accessibilityLabel("Sort")
        }
    }

    private var searchBar: some View {
        HStack {
            Icon("magnifying-glass", size: 18).foregroundStyle(Color.faint)
            TextField("Search the Marketplace", text: $query).submitLabel(.search).focused($typing)
                .autocorrectionDisabled()
                .onSubmit { Task { await load() } }
                .accessibilityIdentifier("catalogSearch")
            if !query.isEmpty {
                Button { query = ""; Task { await load() } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.faint) }
                    .accessibilityLabel("Clear search")
            }
        }
        .font(.builder(16)).padding(.horizontal, 12).frame(height: 40)
        .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 15).padding(.bottom, 10)
    }

    private var sorted: [Item] {
        switch sort {
        case .relevance: results
        case .low: results.sorted { ($0.price ?? .max) < ($1.price ?? .max) }
        case .high: results.sorted { ($0.price ?? -1) > ($1.price ?? -1) }
        }
    }

    private var marketplace: some View {
        let front = category == "All" && query.isEmpty && sort == .relevance
        let assets = sorted.filter { !$0.bundle }
        return VStack(alignment: .leading, spacing: 0) {
            if category == "Backgrounds" && query.isEmpty { plusBanner.padding(.top, 10) }
            Text(front ? "Recommended For You" : query.isEmpty ? category : "Results").font(.builder(20, .bold))
                .frame(height: 24).padding(.top, 10.5).padding(.bottom, 12)
            if loading && results.isEmpty { ProgressView().tint(Color.faint).frame(maxWidth: .infinity).padding(.bottom, 12) }
            if let failure { Text(failure).font(.builder(14.5)).foregroundStyle(Color.faint).padding(.bottom, 12).accessibilityIdentifier("catalogFailure") }
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(front ? Array(assets.prefix(3)) : sorted) { catalogTile($0) }
            }
            if front && !styles.isEmpty { exploreStyles }
            if front {
                LazyVGrid(columns: grid, spacing: 20) { ForEach(Array(assets.dropFirst(3))) { catalogTile($0) } }
                    .padding(.top, 26)
            }
            if next != nil {
                ProgressView().tint(Color.faint).frame(maxWidth: .infinity).padding(.top, 24)
                    .onAppear { Task { await loadMore() } }
            }
        }
        .padding(.leading, 15).padding(.trailing, 14).padding(.bottom, 30)
        .buttonStyle(PressStyle())
    }

    private var plusBanner: some View {
        HStack(spacing: 8) {
            Icon("premium", size: 16)
            Text("Unlock free exclusive backgrounds with Plus.").font(.builder(12)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button { open(.robux) } label: { Text("Subscribe").font(.builder(12, .medium)).underline() }
                .accessibilityIdentifier("plusSubscribe")
        }
        .padding(.horizontal, 12).frame(height: 38)
        .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
    }

    private var exploreStyles: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Explore Styles").font(.builder(20, .bold)).frame(height: 24)
                Spacer()
                Button { choose("Avatars") } label: {
                    Text("See All").font(.builder(12, .medium)).frame(width: 55, height: 25)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ink, lineWidth: 1))
                }
                .accessibilityIdentifier("seeAllStyles")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { ForEach(styles) { catalogTile($0).frame(width: 115) } }
            }
            .padding(.leading, -15).padding(.trailing, -14).contentMargins(.leading, 15).contentMargins(.trailing, 14)
        }
        .padding(.top, 26)
    }

    private func catalogTile(_ item: Item) -> some View {
        let trying = store.trial?.key == item.key
        return Button {
            if trying || store.profile.owns(item) != nil { open(.item(item)) } else { store.tryOn(item) }
        } label: {
            tile(item, showCreator: true)
                .overlay(alignment: .top) {
                    if trying {
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2)
                                .overlay(alignment: .bottom) {
                                    Text("Details").font(.builder(12, .medium)).foregroundStyle(Color.bg)
                                        .frame(maxWidth: .infinity).frame(height: 26)
                                        .background(Color.white.opacity(0.92), in: UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6))
                                        .padding(2)
                                }
                                .frame(width: g.size.width, height: g.size.width)
                        }
                    }
                }
        }
        .accessibilityIdentifier("catalogItem")
        .accessibilityLabel(trying ? "\(item.name), trying on. Details" : item.name)
    }

    private func trialBar(_ t: Item) -> some View {
        HStack(spacing: 14) {
            Button { buying = t } label: {
                HStack(spacing: 6) {
                    if let price = t.price, price > 0 {
                        Icon("robux", size: 20)
                        Text(grouped(price)).font(.builder(16, .bold))
                    } else {
                        Text(t.price == nil ? "Off Sale" : "Get").font(.builder(16, .bold))
                    }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 40)
                .background(t.price == nil ? Color.tile : Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(t.price == nil)
            .accessibilityIdentifier("trialBuy")
            Menu {
                Button("Details") { open(.item(t)) }
                Button("Take Off") { store.tryOn(nil) }
            } label: {
                Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: Circle())
            }
            .accessibilityIdentifier("trialMore").accessibilityLabel("More")
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.bg)
    }

    private var inventory: some View {
        let mine = store.profile.items.filter { Shelf.of($0) == shelf }
        return VStack(alignment: .leading, spacing: 0) {
            if shelf == .avatars {
                outfits.padding(.top, 11)
                if !mine.isEmpty {
                    Text("Purchased").font(.builder(20, .bold)).frame(height: 24).padding(.top, 30).padding(.bottom, 12)
                    owned(mine)
                }
                if !styles.isEmpty {
                    Text("You May Also Like").font(.builder(20, .bold)).frame(height: 24).padding(.top, 30).padding(.bottom, 12)
                    LazyVGrid(columns: grid, spacing: 20) { ForEach(styles) { catalogTile($0) } }
                }
            } else if let slot = currentSlot, slot.name == "Build" {
                slotRow.padding(.top, 11)
                buildPanel.padding(.top, 20)
            } else if let slot = currentSlot, slot.name == "Skin" {
                slotRow.padding(.top, 11)
                skinPanel.padding(.top, 20)
            } else if let slot = currentSlot {
                slotRow.padding(.top, 11)
                let here = mine.filter(slot.holds)
                if here.isEmpty {
                    Text("No \(plural(slot.name))").font(.builder(16, .medium)).frame(maxWidth: .infinity).padding(.top, 30)
                        .accessibilityIdentifier("slotEmpty")
                } else {
                    owned(here).padding(.top, 20)
                }
                suggestions(slot.taxonomy)
            } else {                                // Backgrounds: no slots
                if mine.isEmpty {
                    Text("No Backgrounds").font(.builder(16, .medium)).frame(maxWidth: .infinity).padding(.top, 30)
                } else {
                    owned(mine).padding(.top, 11)
                }
                plusSection.padding(.top, 30)
                suggestions("ijFKKMZq6jV4gkJQC4v7L1")
            }
        }
        .padding(.leading, 15).padding(.trailing, 14).padding(.bottom, 30)
        .buttonStyle(PressStyle())
        .task { await store.fillKinds() }
        .task { if styles.isEmpty, let page = try? await Roblox.search("", category: Self.categories["Avatars"]) { styles = page.items } }
        .alert("Save this avatar", isPresented: $naming) {
            TextField("Name", text: $outfitName)
            Button("Save") { store.saveOutfit(named: outfitName) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Saves what you're wearing now under Avatars.") }
        .confirmationDialog(details?.name ?? "", isPresented: Binding(get: { details != nil }, set: { if !$0 { details = nil } }), titleVisibility: .visible) {
            if let o = details {
                Button("Rename") { outfitName = o.name; renaming = o }
                Button("Delete", role: .destructive) { store.deleteOutfit(o) }
            }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $outfitName)
            Button("Save") {
                let n = outfitName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let o = renaming, !n.isEmpty, let i = store.profile.outfits.firstIndex(where: { $0.id == o.id }) { store.profile.outfits[i].name = n }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var currentSlot: Slot? {
        let slots = shelf.slots
        return slots.first { $0.name == slotPicked[shelf] } ?? slots.first
    }

    private func plural(_ name: String) -> String {
        name.hasSuffix("s") || ["Hair", "Outerwear", "Gear", "Other", "Full Body", "Head", "Face", "Neck", "Back", "Waist", "Shoulder", "Front"].contains(name)
            ? name : name + "s"
    }

    private var slotRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 9) {
                ForEach(shelf.slots, id: \.self) { s in
                    let on = s == currentSlot
                    let worn = store.profile.items.first { $0.wearing && s.holds($0) }
                    Button { slotPicked[shelf] = s.name } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10).fill(Color.tile).frame(width: 64, height: 64)
                                .overlay {
                                    if s.name == "Skin" { Circle().fill(skinColor).padding(16) }
                                    else if s.name == "Build" { Icon("person-standing", size: 30).foregroundStyle(Color.faint) }
                                    else if let worn { RemoteImage(url: worn.thumb, fill: false).padding(5) }
                                    else { Image(systemName: "plus").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.faint) }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Color.white : .clear, lineWidth: 2))
                            Text(s.name).font(.builder(10.5)).lineLimit(1).frame(width: 70)
                        }
                    }
                    .accessibilityIdentifier("slot-\(s.name)")
                }
            }
        }
        .padding(.leading, -15).padding(.trailing, -14).contentMargins(.leading, 15).contentMargins(.trailing, 14)
    }

    private var skinColor: Color { Self.color(Build.skin(in: store.profile.definition) ?? "#A3A2A5") }

    private static func color(_ hex: String) -> Color {
        let v = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    private var plusSection: some View {
        let member = store.profile.badge == .plus
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Icon("premium", size: 20)
                Text("Exclusive with Plus").font(.builder(20, .bold))
            }
            if !member { plusBanner }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(91), spacing: 13.7, alignment: .top), count: 4), alignment: .leading, spacing: 13.7) {
                Button { choose("Backgrounds") } label: {
                    RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 91, height: 91)
                        .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .light)).foregroundStyle(Color.faint))
                }
                .accessibilityLabel("More backgrounds")
                ForEach(plusOnes) { bg in
                    let worn = store.profile.owns(bg)?.wearing ?? false
                    Button { if member { store.wear(bg, !worn) } else { open(.robux) } } label: {
                        RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 91, height: 91)
                            .overlay { RemoteImage(url: bg.thumb, fill: true) }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(worn ? Color.white : .clear, lineWidth: 2))
                    }
                    .accessibilityIdentifier("plusBackground").accessibilityLabel(bg.name)
                }
            }
        }
        .task { if plusOnes.isEmpty { plusOnes = await Roblox.plusBackgrounds() } }
    }

    private var buildPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Build.ranges, id: \.key) { r in
                BuildSlider(name: r.name, range: r.min...r.max, value: Build.scale(r.key, in: store.profile.definition)) { v in
                    store.setBody(Build.setting(r.key, to: v, in: store.profile.definition))
                }
                .accessibilityIdentifier("build-\(r.key)")
            }
        }
        .padding(.trailing, 1)
    }

    private var skinPanel: some View {
        let now = Build.skin(in: store.profile.definition)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
            ForEach(Build.skins, id: \.self) { hex in
                Button { store.setBody(Build.painting(hex, in: store.profile.definition)) } label: {
                    Circle().fill(Self.color(hex)).frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Color.white, lineWidth: now == hex ? 3 : 0).padding(-4))
                }
                .accessibilityIdentifier("skin-\(hex)").accessibilityLabel(now == hex ? "Skin \(hex), chosen" : "Skin \(hex)")
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func suggestions(_ taxonomy: String) -> some View {
        if !taxonomy.isEmpty { suggestionList(taxonomy) }
    }

    private func suggestionList(_ taxonomy: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let items = suggested[taxonomy], !items.isEmpty {
                Text("You May Also Like").font(.builder(20, .bold)).frame(height: 24).padding(.top, 34).padding(.bottom, 12)
                LazyVGrid(columns: grid, spacing: 20) { ForEach(items.prefix(12)) { catalogTile($0) } }
            }
        }
        .task(id: taxonomy) {
            if suggested[taxonomy] == nil, let page = try? await Roblox.search("", category: taxonomy) { suggested[taxonomy] = page.items }
        }
    }

    private var outfits: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(91), spacing: 13.7, alignment: .top), count: 4), alignment: .leading, spacing: 16) {
            Button { outfitName = ""; naming = true } label: {
                VStack(alignment: .leading, spacing: 9) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 91, height: 91)
                        .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .light)).foregroundStyle(Color.faint))
                    Text("Add/Edit").font(.builder(12)).lineLimit(1)
                }
            }
            .accessibilityIdentifier("addOutfit")
            ForEach(store.profile.outfits) { o in
                let on = store.profile.isWorn(o)
                Button { if on { details = o } else { store.wear(outfit: o) } } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 91, height: 91)
                            .overlay {
                                if let picture = UIImage(contentsOfFile: Store.outfitPicture(o.id).path) {
                                    Image(uiImage: picture).resizable().scaledToFit().padding(6)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if on {
                                    Text("Details").font(.builder(12, .medium)).foregroundStyle(Color.bg)
                                        .frame(maxWidth: .infinity).frame(height: 30)
                                        .background(Color.white.opacity(0.92), in: UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6))
                                        .padding(2)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Color.white : .clear, lineWidth: 2))
                        Text(o.name).font(.builder(12)).lineLimit(1)
                    }
                }
                .accessibilityIdentifier("outfit")
                .accessibilityLabel(on ? "\(o.name), worn. Details" : o.name)
            }
        }
    }

    private func owned(_ list: [Item]) -> some View {
        LazyVGrid(columns: grid, spacing: 20) {
            ForEach(list) { item in
                Button { store.wear(item, !item.wearing) } label: { tile(item, showCreator: false) }
                    .accessibilityIdentifier("inventoryItem")
                    .contextMenu {
                        Button("Change price") { priceText = item.price.map(String.init) ?? ""; pricing = item }
                        Button("Open its page") { open(.item(item)) }
                        Button("Remove", role: .destructive) { store.profile.items.removeAll { $0.same(item) } }
                    }
            }
        }
    }

    private func tile(_ item: Item, showCreator: Bool) -> some View {
        let worn = store.profile.owns(item)?.wearing ?? false
        return ItemCard(item: item, showCreator: showCreator)
            .overlay(alignment: .topTrailing) {
                if worn {
                    Image(systemName: "checkmark.circle.fill").font(.builder(24))
                        .foregroundStyle(.white, Color.bloxBlue).padding(6)
                        .accessibilityLabel("Wearing")
                }
            }
    }

    private func choose(_ c: String) {
        customize = false
        category = c
        sub = nil
        query = ""
        Task { await load() }
    }

    private func toggleSearch() {
        customize = false
        withAnimation { searching.toggle() }
        if searching {
            typing = true
        } else if !query.isEmpty {
            query = ""
            Task { await load() }
        }
    }

    private func load() async {
        asked += 1
        let mine = asked
        let q = query.trimmingCharacters(in: .whitespaces), taxonomy = self.taxonomy
        loading = true
        failure = nil
        for (attempt, pause) in [0, 2, 5].enumerated() {
            if attempt > 0 { try? await Task.sleep(for: .seconds(pause)) }
            guard mine == asked else { return }
            do {
                let page = try await Roblox.search(q, category: taxonomy)
                guard mine == asked else { return }
                results = page.items
                next = page.next
                failure = page.items.isEmpty ? "Nothing found." : nil
                break
            } catch {
                guard mine == asked else { return }
                failure = error.localizedDescription
            }
        }
        loading = false
        if styles.isEmpty, let page = try? await Roblox.search("", category: Self.categories["Avatars"]) {
            styles = page.items
        }
    }

    private func loadMore() async {
        guard let cursor = next, !loading else { return }
        let mine = asked
        loading = true
        defer { loading = false }
        guard let page = try? await Roblox.search(query.trimmingCharacters(in: .whitespaces), category: taxonomy, cursor: cursor),
              mine == asked else { return }
        results += page.items.filter { new in !results.contains { $0.same(new) } }
        next = page.next
    }

    private func savePrice() {
        defer { pricing = nil }
        guard let item = pricing else { return }
        guard let i = store.profile.items.firstIndex(where: { $0.same(item) }) else {
            priceProblem = "\(item.name) is no longer in your inventory."
            return
        }
        let t = priceText.trimmingCharacters(in: .whitespaces)
        guard t.isEmpty || t == digits(in: t) else {
            priceProblem = "A price is digits only, like 1500. Leave it empty for Off Sale."
            return
        }
        store.profile.items[i].price = t.isEmpty ? nil : number(from: t)
    }
}

private struct BuildSlider: View {
    let name: String
    let range: ClosedRange<Double>
    let value: Double
    let commit: (Double) -> Void
    @State private var shown: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.builder(14.5, .medium))
                Spacer()
                Text("\(Int(((shown ?? value) * 100).rounded()))%").font(.builder(14.5)).foregroundStyle(Color.faint)
            }
            Slider(value: Binding(get: { shown ?? value }, set: { shown = $0 }), in: range, step: 0.01) { editing in
                if !editing, let v = shown {
                    commit(v)
                    shown = nil
                }
            }
            .tint(Color.bloxBlue)
        }
    }
}
