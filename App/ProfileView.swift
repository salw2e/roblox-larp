import SwiftUI
import CoreImage.CIFilterBuiltins
import BloxKit

struct ProfileView: View {
    @EnvironmentObject var store: Store
    var full = false                       // dragged up to fill the screen
    var statusBar: CGFloat = 0
    @Binding var atTop: Bool
    var pulling = false
    var close: () -> Void = {}
    var open: (Page) -> Void = { _ in }
    var editAppearance: () -> Void = {}
    @State private var editing = false
    @State private var showingCode = false
    @State private var restY: CGFloat?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AvatarStage().frame(height: 236).frame(maxWidth: .infinity).padding(.top, 44)
                header.padding(.top, 6)
                chips.padding(.top, 16)
                if !store.profile.bio.isEmpty {
                    Text(store.profile.bio).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(3)
                        .padding(.top, 25).accessibilityIdentifier("bio")
                }
                buttons.padding(.top, 25)
                wearing.padding(.top, 28)
                if !store.profile.experiences.isEmpty { experiences.padding(.top, 28) }
                Button { open(.fullProfile) } label: {
                    Text("View full profile").font(.builder(14.5, .medium)).frame(maxWidth: .infinity, minHeight: 40)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ink, lineWidth: 1))
                }
                .accessibilityIdentifier("viewFullProfile")
                .padding(.vertical, 28)
            }
            .padding(.horizontal, 24)
            .background(alignment: .top) { backdrop }
            .background(GeometryReader { g in
                Color.clear.preference(key: ScrollTop.self, value: g.frame(in: .named("profilePage")).minY)
            })
        }
        .coordinateSpace(name: "profilePage")
        .onPreferenceChange(ScrollTop.self) { y in
            let rest = max(restY ?? y, y)
            restY = rest
            atTop = y >= rest - 1
        }
        .onChange(of: full) { _, _ in restY = nil }
        .scrollDisabled(!full || pulling)
        .background(Color.bg)
        .overlay(alignment: .top) {
            if !full { Capsule().fill(Color.rgb(79, 81, 92)).frame(width: 36, height: 4).padding(.top, 10) }
        }
        .overlay(alignment: .topLeading) {
            if full {
                Button(action: close) {
                    Image(systemName: "xmark").font(.builder(16, .medium))
                        .frame(width: 36, height: 36).background(Color.pill.opacity(0.6), in: Circle())
                }
                .accessibilityIdentifier("closeProfile").accessibilityLabel("Close")
                .padding(.leading, 20).padding(.top, statusBar + 8)
            }
        }
        .sheet(isPresented: $editing) { EditProfileView() }
        .sheet(isPresented: $showingCode) { ProfileCode() }
    }

    private var backdrop: some View {
        LinearGradient(stops: [
            .init(color: .rgb(41, 40, 44), location: 0),
            .init(color: .rgb(57, 59, 65), location: 0.39),
            .init(color: .rgb(77, 87, 100), location: 0.57),
            .init(color: .rgb(88, 99, 113), location: 0.69),
            .init(color: .rgb(54, 61, 70), location: 0.85),
            .init(color: .bg, location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .overlay {
            BackdropPicture().mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                                  startPoint: .top, endPoint: .bottom))
        }
        .frame(height: 327)
        .overlay(alignment: .top) { Color.rgb(41, 40, 44).frame(height: 800).offset(y: -800) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Headshot(image: store.avatar, crop: store.profile.crop, size: 88)
            VStack(alignment: .leading, spacing: 3) {
                NameLine(profile: store.profile, font: 20).frame(height: 24).foregroundStyle(Color.faint)
                Text("@\(store.profile.shownUsername)").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                    .frame(height: 18)
                    .accessibilityIdentifier("username")
            }
            .padding(.top, 22)
        }
    }

    private var chips: some View {
        let p = store.profile
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("\(short(p.friends)) Friends", dim: p.friends == 0, id: "friendsChip")     // any count at 0 is greyed
                chip("\(short(p.followers)) Followers", dim: p.followers == 0, id: "followersChip")
                chip("\(short(p.following)) Following", dim: p.following == 0, id: "followingChip")
            }
        }
        .padding(.horizontal, -24).contentMargins(.horizontal, 24)
    }

    private func chip(_ text: String, dim: Bool, id: String) -> some View {
        Text(text).font(.builder(14.5)).lineLimit(1).fixedSize()
            .padding(.horizontal, 12).frame(height: 32)
            .background(Color.tile.opacity(dim ? 0.6 : 1), in: Capsule())
            .foregroundStyle(dim ? Color.dim.opacity(0.6) : Color.ink)
            .accessibilityIdentifier(id)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(action: editAppearance) {
                Text("Edit appearance").frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
            }
            .accessibilityIdentifier("editAppearance")
            Button { editing = true } label: {
                Text("Edit profile").frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityIdentifier("editProfile")
            Button { showingCode = true } label: {
                Icon("squares-grid-qr", size: 22).frame(width: 40, height: 40)
                    .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityIdentifier("profileCode").accessibilityLabel("Profile QR code")
        }
        .font(.builder(14.5, .medium)).lineLimit(1)
        .buttonStyle(PressStyle())
    }

    private var wearing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currently Wearing").font(.builder(20, .bold)).frame(height: 24)
            if store.profile.wearing.isEmpty {
                Text("Nothing yet. Tap Edit appearance to put items on.").font(.builder(14.5)).foregroundStyle(Color.faint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(store.profile.wearing) { item in
                        Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 116) }
                            .buttonStyle(PressStyle()).accessibilityIdentifier("wornItem")
                    }
                }
            }
            .padding(.horizontal, -24).contentMargins(.horizontal, 24)
        }
    }

    private var experiences: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiences").font(.builder(20, .bold)).frame(height: 24)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(store.profile.experiences) { g in
                    Button { open(.game(g)) } label: { WideGameCard(game: g) }
                        .buttonStyle(PressStyle()).accessibilityIdentifier("profileGame")
                }
            }
        }
    }
}

struct ScrollTop: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ProfileCode: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 16) {
            Text("Share Profile").font(.builder(20, .bold)).padding(.top, 28)
            if let code = Self.code("https://www.roblox.com/users/profile?username=\(store.profile.shownUsername)") {
                Image(uiImage: code).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220)
                    .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("profileCodeImage").accessibilityLabel("QR code")
            }
            Text("@\(store.profile.shownUsername)").font(.builder(14.5)).foregroundStyle(Color.faint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .presentationBackground(Color.bg)
    }

    static func code(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct FullProfileView: View {
    @EnvironmentObject var store: Store
    var open: (Page) -> Void = { _ in }
    var editAvatar: () -> Void = {}
    @State private var editing = false
    @State private var flat = false            // the 3D switch turned off
    @State private var wholeBio = false
    @State private var showingCode = false
    @State private var creations = false       // the Creations tab
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let p = store.profile
        let collectibles = p.items.filter { $0.limited == true }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.rgb(25, 26, 30))
                        .overlay { BackdropPicture() }.clipShape(RoundedRectangle(cornerRadius: 8))
                    AvatarStage(flat: flat).padding(.vertical, 10)
                    if store.modelVersion > 0 {
                        Button { flat.toggle() } label: {
                            Text(flat ? "2D" : "3D").font(.builder(14.5, .bold)).frame(width: 44, height: 48)
                                .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("toggle3D").accessibilityLabel(flat ? "Show in 3D" : "Show flat picture")
                        .padding(12)
                    }
                }
                .frame(height: 300)
                HStack(alignment: .top, spacing: 13) {
                    Headshot(image: store.avatar, crop: p.crop, size: 88)
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.bloxBlue).frame(width: 14, height: 14)).offset(x: -4, y: -4)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        NameLine(profile: p, font: 26)
                        Text("@\(p.shownUsername)").font(.builder(12)).foregroundStyle(Color.faint).lineLimit(1)
                    }
                    .padding(.top, 34)
                }
                .padding(.top, -20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("\(short(p.friends)) Friends", dim: p.friends == 0)
                        chip("\(short(p.followers)) Followers", dim: p.followers == 0)
                        chip("\(short(p.following)) Following", dim: p.following == 0)
                    }
                }
                .padding(.horizontal, -15).contentMargins(.horizontal, 15)
                .padding(.top, 17)
                if !p.bio.isEmpty {
                    Text(p.bio).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(wholeBio ? nil : 2).padding(.top, 18)
                        .accessibilityIdentifier("fullBio")
                    if p.bio.count > 80 || p.bio.contains("\n") {
                        Button(wholeBio ? "less" : "more") { wholeBio.toggle() }
                            .font(.builder(14.5)).underline().foregroundStyle(Color.faint).padding(.top, 2)
                            .accessibilityIdentifier("bioMore")
                    }
                }
                HStack(spacing: 8) {
                    button("Edit avatar", action: editAvatar).accessibilityIdentifier("fullEditAvatar")
                    button("Edit profile") { editing = true }
                    Menu {
                        Button("Share profile") { showingCode = true }
                        Button("Edit profile") { editing = true }
                    } label: {
                        Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("fullMore").accessibilityLabel("More")
                }
                .padding(.top, 24)
                tabs
                if creations {
                    if p.experiences.isEmpty {
                        Text("No creations yet.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.leading, 16).padding(.top, 28)
                    } else {
                        section("Experiences") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 16) {
                                ForEach(p.experiences) { g in Button { open(.game(g)) } label: { GameCard(game: g) } }
                            }
                            .padding(.trailing, 16)
                        }
                    }
                } else {
                    section("Currently Wearing") {
                        if p.wearing.isEmpty { Text("Nothing yet.").font(.builder(14.5)).foregroundStyle(Color.faint) }
                        row { ForEach(p.wearing) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) }.accessibilityIdentifier("fullWorn") } }
                    }
                    if !p.games.isEmpty {
                        section("Favorites", page: .favorites) {
                            row { ForEach(p.games) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 108) } } }
                        }
                    }
                    if !p.friendList.isEmpty {
                        section("Friends (\(grouped(max(p.friends, p.friendList.count))))", page: .friends) {
                            row {
                                ForEach(p.friendList) { f in
                                    Button { open(.friend(f.id)) } label: {
                                        VStack(spacing: 6) {
                                            RemoteCircle(url: f.headshot, size: 84)
                                            Text(f.displayName).font(.builder(12)).lineLimit(1)
                                        }
                                        .frame(width: 88)
                                    }
                                }
                            }
                        }
                    }
                    if !collectibles.isEmpty {
                        section("Collections", page: .inventory) {
                            row { ForEach(collectibles) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) } } }
                        }
                    }
                }
            }
            .padding(.horizontal, 15).padding(.top, 40).padding(.bottom, 30)
            .buttonStyle(PressStyle())
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .sheet(isPresented: $editing) { EditProfileView() }
        .sheet(isPresented: $showingCode) { ProfileCode() }
    }

    private var header: some View {
        ZStack {
            Text("Profile").font(.builder(23.5, .bold))
            HStack {
                Button { dismiss() } label: { Icon("x", size: 28).frame(width: 44, height: 44) }
                    .accessibilityIdentifier("fullProfileClose").accessibilityLabel("Close")
                Spacer()
            }
            .padding(.leading, 20)
        }
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(Color.rgb(36, 37, 39).ignoresSafeArea(edges: .top))
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["About", "Creations"], id: \.self) { t in
                let on = (t == "Creations") == creations
                Button { withAnimation(.easeOut(duration: 0.2)) { creations = t == "Creations" } } label: {
                    Text(t).font(.builder(14.2, .medium)).foregroundStyle(on ? Color.ink : Color.dim)
                        .frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
                }
                .accessibilityIdentifier("profileTab-\(t)")
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                Rectangle().fill(creations ? Color.tile : Color.ink).frame(height: creations ? 1 : 2)
                Rectangle().fill(creations ? Color.ink : Color.tile).frame(height: creations ? 2 : 1)
            }
            .frame(height: 2, alignment: .bottom)
        }
        .padding(.top, 15)
    }

    private func chip(_ text: String, dim: Bool) -> some View {
        Text(text).font(.builder(14.5)).lineLimit(1).fixedSize().padding(.horizontal, 12).frame(height: 31)
            .background(Color.tile.opacity(dim ? 0.6 : 1), in: Capsule())
            .foregroundStyle(dim ? Color.dim.opacity(0.6) : Color.ink)
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.builder(13.5, .bold)).frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func section<C: View>(_ title: String, page: Page? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { if let page { open(page) } } label: {
                HStack(spacing: 6) {
                    Text(title).font(.builder(19, .bold))
                    if page != nil { Icon("chevron-large-right", size: 16) }
                }
            }
            .allowsHitTesting(page != nil)
            content()
        }
        .padding(.leading, 16).padding(.top, 34)
    }

    private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) { content() }
        }
        .padding(.leading, -31).padding(.trailing, -15).contentMargins(.leading, 31).contentMargins(.trailing, 15)
    }
}
