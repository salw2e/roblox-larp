import SwiftUI
import SalBloxKit
import CoreImage.CIFilterBuiltins

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
                        section("Friends (\(grouped(max(p.friends, p.friendList.count))))", seeAll: .friends) {
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

    private func section<C: View>(_ title: String, page: Page? = nil, seeAll: Page? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { if let page { open(page) } } label: {
                    HStack(spacing: 6) {
                        Text(title).font(.builder(19, .bold))
                        if page != nil { Icon("chevron-large-right", size: 16) }
                    }
                }
                .allowsHitTesting(page != nil)
                if let seeAll {
                    Spacer()
                    Button { open(seeAll) } label: {
                        HStack(spacing: 4) {
                            Text("See All").font(.builder(14.5, .medium))
                            Icon("arrow-large-right", size: 16)
                        }
                    }
                    .padding(.trailing, 16)
                }
            }
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
