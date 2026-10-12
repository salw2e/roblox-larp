import SwiftUI
import SalBloxKit
import CoreImage.CIFilterBuiltins

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
                chip(counted(p.friends, "Friend"), dim: p.friends == 0, id: "friendsChip")     // any count at 0 is greyed
                chip(counted(p.followers, "Follower"), dim: p.followers == 0, id: "followersChip")
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
                    Button { open(.game(g)) } label: { WideGameCard(game: g, stats: true) }
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
