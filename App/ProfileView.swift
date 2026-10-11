import SwiftUI
import BloxKit

struct ProfileView: View {
    @EnvironmentObject var store: Store
    var full = false                       // dragged up to fill the screen
    @Binding var atTop: Bool
    var pulling = false
    var close: () -> Void = {}
    var open: (Page) -> Void = { _ in }
    var editAppearance: () -> Void = {}
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AvatarStage().frame(height: 236).frame(maxWidth: .infinity).padding(.top, 44)
                header.padding(.top, 6)
                chips.padding(.top, 16)
                if !store.profile.bio.isEmpty {
                    Text(store.profile.bio).font(.builder(14.5)).foregroundStyle(Color.faint)
                        .padding(.top, 25).accessibilityIdentifier("bio")
                }
                buttons.padding(.top, 25)
                wearing.padding(.top, 28)
                if !store.profile.games.isEmpty { games.padding(.top, 28) }
                Button { open(.fullProfile) } label: {
                    Text("View full profile").font(.builder(14.5, .medium)).frame(maxWidth: .infinity, minHeight: 40)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ink, lineWidth: 1))
                }
                .accessibilityIdentifier("viewFullProfile")
                .padding(.vertical, 28)
            }
            .padding(.horizontal, 24)
            .background(GeometryReader { g in
                Color.clear.preference(key: ScrollTop.self, value: g.frame(in: .named("profilePage")).minY)
            })
        }
        .coordinateSpace(name: "profilePage")
        .onPreferenceChange(ScrollTop.self) { atTop = $0 >= -1 }
        .scrollDisabled(!full || pulling)
        .background(alignment: .top) { backdrop }
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
                .accessibilityIdentifier("closeProfile")
                .padding(.leading, 20).padding(.top, 8)
            }
        }
        .sheet(isPresented: $editing) { EditProfileView() }
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
        .frame(height: 327).ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Headshot(image: store.avatar, crop: store.profile.crop, size: 88)
            VStack(alignment: .leading, spacing: 3) {
                NameLine(profile: store.profile, font: 20).frame(height: 24).foregroundStyle(Color.faint)
                Text("@\(store.profile.username)").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                    .frame(height: 18)
                    .accessibilityIdentifier("username")
            }
            .padding(.top, 22)
        }
    }

    private var chips: some View {
        let p = store.profile
        return HStack(spacing: 8) {
            chip("\(short(p.friends)) Friends", id: "friendsChip")
            chip("\(short(p.followers)) Followers", id: "followersChip")
            chip("\(short(p.following)) Following", id: "followingChip")
        }
    }

    private func chip(_ text: String, id: String) -> some View {
        Text(text).font(.builder(14.5)).lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Color.tile, in: Capsule())
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
            Icon("squares-grid-qr", size: 22).frame(width: 40, height: 40)
                .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
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

    private var games: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiences").font(.builder(20, .bold)).frame(height: 24)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(store.profile.games) { g in
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

struct FullProfileView: View {
    @EnvironmentObject var store: Store
    var open: (Page) -> Void = { _ in }
    var editAvatar: () -> Void = {}
    @State private var editing = false

    var body: some View {
        let p = store.profile
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.rgb(25, 26, 30))
                    AvatarStage().padding(.vertical, 10)
                    Text("3D").font(.builder(14.5, .bold)).frame(width: 44, height: 48)
                        .background(Color.tile, in: RoundedRectangle(cornerRadius: 8)).padding(12)
                }
                .frame(height: 300)
                HStack(alignment: .top, spacing: 13) {
                    Headshot(image: store.avatar, crop: p.crop, size: 88)
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.bloxBlue).frame(width: 14, height: 14)).offset(x: -4, y: -4)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        NameLine(profile: p, font: 26)
                        Text("@\(p.username)").font(.builder(12)).foregroundStyle(Color.faint)
                    }
                    .padding(.top, 34)
                }
                .padding(.top, -20)
                HStack(spacing: 8) {
                    chip("\(short(p.friends)) Friends")
                    chip("\(short(p.followers)) Followers")
                    chip("\(short(p.following)) Following")
                }
                .padding(.top, 17)
                if !p.bio.isEmpty {
                    Text(p.bio).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(2).padding(.top, 18)
                }
                HStack(spacing: 8) {
                    button("Edit avatar", action: editAvatar).accessibilityIdentifier("fullEditAvatar")
                    button("Edit profile") { editing = true }
                    Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 24)
                section("Currently Wearing") {
                    row { ForEach(p.wearing) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) } } }
                }
                if !p.games.isEmpty {
                    section("Experiences") {
                        row { ForEach(p.games) { g in Button { open(.game(g)) } label: { WideGameCard(game: g).frame(width: 170) } } }
                    }
                    section("Favorites", page: .favorites) {
                        row { ForEach(p.games) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 108) } } }
                    }
                }
                if !p.friendList.isEmpty {
                    section("Friends (\(grouped(p.friends)))", page: .friends) {
                        row {
                            ForEach(p.friendList) { f in
                                VStack(spacing: 6) {
                                    RemoteCircle(url: f.headshot, size: 84)
                                    Text(f.displayName).font(.builder(12)).lineLimit(1)
                                }
                                .frame(width: 88)
                            }
                        }
                    }
                }
                if !p.items.isEmpty {
                    section("Collections", page: .inventory) {
                        row { ForEach(p.items) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) } } }
                    }
                }
            }
            .padding(.horizontal, 15).padding(.top, 16).padding(.bottom, 30)
            .buttonStyle(PressStyle())
        }
        .page("Profile")
        .sheet(isPresented: $editing) { EditProfileView() }
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.builder(14.5)).lineLimit(1).padding(.horizontal, 12).frame(height: 31).background(Color.tile, in: Capsule())
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.builder(14.5, .bold)).frame(maxWidth: .infinity, minHeight: 40)
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
            .disabled(page == nil)
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
