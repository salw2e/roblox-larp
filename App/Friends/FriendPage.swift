import SwiftUI
import SalBloxKit

struct FriendPage: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: Int64
    let open: (Page) -> Void
    @State private var them: Roblox.Someone?
    @State private var more: Roblox.More?
    @State private var face: String?
    @State private var wholeBio = false
    @State private var creations = false

    var body: some View {
        let who = personName(store, id, them?.person)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 8).fill(Color.rgb(25, 26, 30))
                    .overlay {
                        if let picture = them?.picture { RemoteImage(url: picture, fill: false).padding(.vertical, 10) }
                        else if them == nil { ProgressView().tint(Color.faint) }
                    }
                    .frame(height: 300)
                HStack(alignment: .top, spacing: 13) {
                    RemoteCircle(url: who.face ?? face, size: 88)
                        .overlay(alignment: .bottomTrailing) {
                            if who.online { Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.online).frame(width: 14, height: 14)).offset(x: -4, y: -4) }
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(who.display).font(.builder(26, .bold)).lineLimit(1).minimumScaleFactor(0.75).accessibilityIdentifier("personName")
                            if them?.person?.verified == true { VerifiedBadge(size: 19.5).fixedSize() }
                        }
                        Text("@\(who.user)").font(.builder(12)).foregroundStyle(Color.faint).lineLimit(1)
                    }
                    .padding(.top, 34)
                }
                .padding(.top, -20)
                counts(them).padding(.horizontal, -15).contentMargins(.horizontal, 15).padding(.top, 17)
                if !who.status.isEmpty { Text(who.status).font(.builder(14.5, .medium)).foregroundStyle(Color.online).padding(.top, 14) }
                let bio = them?.person?.bio ?? ""
                Text(bio.isEmpty ? "No bio yet" : bio).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(wholeBio ? nil : 2).padding(.top, 18)
                Button(wholeBio ? "less" : "more") { wholeBio.toggle() }
                    .font(.builder(14.5)).underline().foregroundStyle(Color.faint).padding(.top, 2)
                HStack(spacing: 8) {
                    if store.profile.friendList.contains(where: { $0.id == id }) {
                        Button { open(.chat(id)) } label: {
                            Text("Chat").font(.builder(13.5, .bold)).frame(maxWidth: .infinity, minHeight: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("personChat")
                    } else {
                        Button { Task { _ = try? await store.addFriendById(id) } } label: {
                            Text("Add Friend").font(.builder(13.5, .bold)).frame(maxWidth: .infinity, minHeight: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                    }
                    moreMenu(store: store, id: id) { dismiss() }
                }
                .padding(.top, 24)
                tabs
                if creations {
                    if let games = more?.creations, !games.isEmpty {
                        section("Experiences") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 16) {
                                ForEach(games) { g in Button { open(.game(g)) } label: { GameCard(game: g) } }
                            }
                            .padding(.trailing, 16)
                        }
                    } else {
                        Text(more == nil ? " " : "No creations yet.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.leading, 16).padding(.top, 28)
                    }
                } else {
                    about
                }
            }
            .padding(.horizontal, 15).padding(.top, 40).padding(.bottom, 30)
            .buttonStyle(PressStyle())
        }
        .background(Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                Text("Profile").font(.builder(23.5, .bold))
                HStack {
                    Button { dismiss() } label: { Icon("x", size: 28).frame(width: 44, height: 44) }
                        .accessibilityIdentifier("personClose").accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.leading, 20)
            }
            .frame(height: 54).frame(maxWidth: .infinity)
            .background(Color.rgb(36, 37, 39).ignoresSafeArea(edges: .top))
        }
        .task {
            async let t = Roblox.someone(id)
            async let f = Roblox.headshots([id])
            async let m = Roblox.moreOf(id)
            them = await t
            face = await f[id]
            more = await m
        }
    }

    @ViewBuilder
    private var about: some View {
        if let worn = them?.wearing, !worn.isEmpty {
            section("Currently Wearing") { row { ForEach(worn) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 108) } } } }
        }
        if let games = them?.favorites, !games.isEmpty {
            section("Favorites") { row { ForEach(games) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 108) } } } }
        }
        if let friends = more?.friends, !friends.isEmpty {
            section("Friends (\(grouped(them?.friends ?? friends.count)))", seeAll: true) {
                row {
                    ForEach(friends, id: \.user.id) { f in
                        Button { open(.person(f.user.id)) } label: {
                            VStack(spacing: 6) {
                                RemoteCircle(url: f.face, size: 92)
                                Text(f.user.displayName).font(.builder(10.5)).lineLimit(1)
                            }
                            .frame(width: 96)
                        }
                    }
                }
            }
        }
        if let groups = more?.communities, !groups.isEmpty {
            section("Communities") {
                row {
                    ForEach(groups, id: \.id) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 120, height: 120)
                                .overlay { RemoteImage(url: more?.groupIcons[g.id], fill: true) }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            HStack(spacing: 4) {
                                Text(g.name).font(.builder(14.5, .bold)).lineLimit(2)
                                if g.verified { VerifiedBadge(size: 12).fixedSize() }
                            }
                            .padding(.top, 4)
                            Text("\(short(g.members))+ Members").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                            Text(g.role).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                        }
                        .frame(width: 120, alignment: .leading)
                    }
                }
            }
        }
        if let badges = more?.badges, !badges.isEmpty {
            section("Badges", chevron: true) {
                row {
                    ForEach(badges, id: \.id) { b in
                        VStack(alignment: .leading, spacing: 8) {
                            Circle().fill(Color.tile).frame(width: 112, height: 112)
                                .overlay { RemoteImage(url: b.icon, fill: true) }
                                .clipShape(Circle())
                            Text(b.name).font(.builder(14.5, .bold)).lineLimit(2)
                        }
                        .frame(width: 112, alignment: .leading)
                    }
                }
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["About", "Creations"], id: \.self) { t in
                let on = (t == "Creations") == creations
                Button { withAnimation(.easeOut(duration: 0.2)) { creations = t == "Creations" } } label: {
                    Text(t).font(.builder(14.2, .medium)).foregroundStyle(on ? Color.ink : Color.dim)
                        .frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
                }
                .accessibilityIdentifier("personTab-\(t)")
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

    private func section<C: View>(_ title: String, seeAll: Bool = false, chevron: Bool = false, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title).font(.builder(19, .bold))
                if chevron { Icon("chevron-large-right", size: 16) }
                if seeAll {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("See All").font(.builder(14.5, .medium))
                        Icon("arrow-large-right", size: 16)
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
