import SwiftUI
import BloxKit

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var dressing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stage
                header.padding(.top, -24)
                chips.padding(.top, 18)
                if !store.profile.bio.isEmpty {
                    Text(store.profile.bio).font(.system(size: 16)).padding(.top, 20).accessibilityIdentifier("bio")
                }
                buttons.padding(.top, 20)
                wearing.padding(.top, 26)
                if !store.profile.games.isEmpty { games.padding(.top, 32) }
                NavigationLink { FullProfileView() } label: {
                    Text("View full profile").font(.system(size: 16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary, lineWidth: 1.5))
                }
                .accessibilityIdentifier("viewFullProfile")
                .padding(.vertical, 24)
            }
            .padding(.horizontal, 22)
        }
        .background(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.3), Color.bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 420).ignoresSafeArea(edges: .top)
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) { EditProfileView() }
        .fullScreenCover(isPresented: $dressing) { AppearanceView() }
    }

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            AvatarPicture(image: store.avatar).frame(height: 230).frame(maxWidth: .infinity).padding(.top, 60).padding(.bottom, 20)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .medium))
                    .frame(width: 40, height: 40).background(Color.field, in: Circle())
            }
            .accessibilityIdentifier("closeProfile")
            .padding(.top, 8)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Headshot(image: store.avatar, crop: store.profile.crop, size: 86)
            VStack(alignment: .leading, spacing: 4) {
                NameLine(profile: store.profile, font: 21)
                Text("@\(store.profile.username)").font(.system(size: 15)).foregroundStyle(Color.faint).lineLimit(1)
                    .accessibilityIdentifier("username")
            }
            .padding(.top, 30)
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
        Text(text).font(.system(size: 14)).lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 13).frame(height: 32)
            .background(Color.field.opacity(dim ? 0.6 : 1), in: Capsule())
            .foregroundStyle(dim ? Color(white: 0.5) : .primary)
            .accessibilityIdentifier(id)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button { dressing = true } label: {
                Text("Edit appearance").frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
            }
            .accessibilityIdentifier("editAppearance")
            Button { editing = true } label: {
                Text("Edit profile").frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("editProfile")
            Image(systemName: "qrcode").font(.system(size: 18)).frame(width: 40, height: 40)
                .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
        }
        .font(.system(size: 16, weight: .medium)).lineLimit(1)
    }

    private var wearing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currently Wearing").font(.system(size: 21, weight: .bold))
            if store.profile.wearing.isEmpty {
                Text("Nothing yet. Tap Edit appearance to put items on.").foregroundStyle(Color.faint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.profile.wearing) { ItemCard(item: $0).frame(width: 116).accessibilityIdentifier("wornItem") }
                }
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22)
        }
    }

    private var games: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Favorites").font(.system(size: 21, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.profile.games) { GameCard(game: $0).frame(width: 116).accessibilityIdentifier("profileGame") }
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
        .background(Color.bg)
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
