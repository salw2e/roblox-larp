import SwiftUI
import BloxKit

struct ProfileView: View {
    @EnvironmentObject var store: Store
    var full = false                       // dragged up to fill the screen
    @Binding var atTop: Bool
    var pulling = false
    var close: () -> Void = {}
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
                NavigationLink { FullProfileView() } label: {
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
        .toolbar(.hidden, for: .navigationBar)
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
                    ForEach(store.profile.wearing) { ItemCard(item: $0).frame(width: 116).accessibilityIdentifier("wornItem") }
                }
            }
            .padding(.horizontal, -24).contentMargins(.horizontal, 24)
        }
    }

    private var games: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiences").font(.builder(20, .bold)).frame(height: 24)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 17) {
                ForEach(store.profile.games) { WideGameCard(game: $0).accessibilityIdentifier("profileGame") }
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
    private let grid = [GridItem(.adaptive(minimum: 104), spacing: 12, alignment: .top)]

    var body: some View {
        let p = store.profile
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    Headshot(image: store.avatar, crop: p.crop, size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        NameLine(profile: p, font: 24)
                        Text("@\(p.username)").foregroundStyle(Color.faint)
                    }
                }
                HStack {
                    stat(p.friends, "Friends")
                    stat(p.followers, "Followers")
                    stat(p.following, "Following")
                }
                if !p.bio.isEmpty { section("About") { Text(p.bio).font(.builder(18)) } }
                section("Currently Wearing") { itemGrid(p.wearing) }
                section("Inventory") { itemGrid(p.items) }
                if !p.games.isEmpty {
                    section("Favorites") {
                        LazyVGrid(columns: grid, spacing: 18) { ForEach(p.games) { GameCard(game: $0) } }
                    }
                }
            }
            .padding(22)
        }
        .background(Color.bg)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(short(n)).font(.builder(22, .bold))
            Text(label).font(.builder(15)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.builder(24, .bold))
            content()
        }
    }

    @ViewBuilder
    private func itemGrid(_ items: [Item]) -> some View {
        if items.isEmpty {
            Text("Nothing here yet.").foregroundStyle(Color.faint)
        } else {
            LazyVGrid(columns: grid, spacing: 18) { ForEach(items) { ItemCard(item: $0) } }
        }
    }
}
