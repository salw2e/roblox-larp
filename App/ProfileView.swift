import SwiftUI
import BloxKit

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var editing = false
    @State private var dressing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stage
                header.padding(.top, -60)
                chips.padding(.top, 28)
                if !store.profile.bio.isEmpty {
                    Text(store.profile.bio).font(.system(size: 21)).padding(.top, 28).accessibilityIdentifier("bio")
                }
                buttons.padding(.top, 28)
                wearing.padding(.top, 36)
                if !store.profile.games.isEmpty { games.padding(.top, 32) }
                NavigationLink { FullProfileView() } label: {
                    Text("View full profile").font(.system(size: 21, weight: .medium)).frame(maxWidth: .infinity, minHeight: 64)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary, lineWidth: 1.5))
                }
                .accessibilityIdentifier("viewFullProfile")
                .padding(.vertical, 32)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) { EditProfileView() }
        .fullScreenCover(isPresented: $dressing) { AppearanceView() }
    }

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            AvatarPicture(image: store.avatar).frame(height: 400).frame(maxWidth: .infinity).padding(.top, 70)
            Image(systemName: "xmark").font(.system(size: 22, weight: .medium))
                .frame(width: 50, height: 50).background(.white, in: Circle())
                .padding(.top, 8)
        }
        .background(
            LinearGradient(colors: [Color(white: 0.84), .white], startPoint: .top, endPoint: .bottom)
                .padding(.horizontal, -22).ignoresSafeArea(edges: .top)
        )
    }

    private var header: some View {
        HStack(spacing: 16) {
            Headshot(image: store.avatar, crop: store.profile.crop, size: 128)
            VStack(alignment: .leading, spacing: 4) {
                NameLine(profile: store.profile, font: 26)
                Text("@\(store.profile.username)").font(.system(size: 19)).foregroundStyle(Color.faint).lineLimit(1)
                    .accessibilityIdentifier("username")
            }
            .padding(.top, 50)
        }
    }

    private var chips: some View {
        let p = store.profile
        return HStack(spacing: 10) {
            chip("\(short(p.friends)) Friends", dim: false, id: "friendsChip")
            chip("\(short(p.followers)) Followers", dim: false, id: "followersChip")
            chip("\(short(p.following)) Following", dim: p.following == 0, id: "followingChip")
        }
    }

    private func chip(_ text: String, dim: Bool, id: String) -> some View {
        Text(text).font(.system(size: 17)).lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 16).frame(height: 44)
            .background(Color.field.opacity(dim ? 0.6 : 1), in: Capsule())
            .foregroundStyle(dim ? Color(white: 0.65) : .primary)
            .accessibilityIdentifier(id)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button { dressing = true } label: {
                Text("Edit appearance").frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
            }
            .accessibilityIdentifier("editAppearance")
            Button { editing = true } label: {
                Text("Edit profile").frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("editProfile")
            Image(systemName: "qrcode").font(.system(size: 24)).frame(width: 58, height: 58)
                .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
        }
        .font(.system(size: 20, weight: .medium))
    }

    private var wearing: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Currently Wearing").font(.system(size: 28, weight: .bold))
            if store.profile.wearing.isEmpty {
                Text("Nothing yet. Tap Edit appearance to put items on.").foregroundStyle(Color.faint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.profile.wearing) { ItemCard(item: $0).frame(width: 170).accessibilityIdentifier("wornItem") }
                }
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22)
        }
    }

    private var games: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Favorites").font(.system(size: 28, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.profile.games) { GameCard(game: $0).frame(width: 150).accessibilityIdentifier("profileGame") }
                }
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22)
        }
    }
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
                if !p.bio.isEmpty { section("About") { Text(p.bio).font(.system(size: 18)) } }
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
        .background(Color.white)
        .navigationTitle(p.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(short(n)).font(.system(size: 22, weight: .bold))
            Text(label).font(.system(size: 15)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 24, weight: .bold))
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
