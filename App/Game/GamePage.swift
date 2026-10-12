import SwiftUI
import SalBloxKit

struct GamePage: View {
    @EnvironmentObject var store: Store
    let game: Game
    var close: () -> Void = {}
    var open: (Page) -> Void = { _ in }
    @Binding var full: Bool
    @State private var info: GameInfo?
    @State private var more: Roblox.GameMore?
    @State private var wholeText = false
    @State private var pass: GamePass?          // the Store pass being bought
    @State private var notEnough = false
    @State private var filled: Game?
    @State private var slides: [String] = []
    @State private var events: [GameEvent] = []
    @State private var eventPictures: [Int64: String] = [:]
    @State private var maturity: String?
    @State private var slide = 0
    @State private var loaded = false
    @State private var joining = false
    @State private var notify = false
    @GestureState private var pull: CGFloat = 0
    private static let sheet = Color.rgb(25, 26, 30)

    var body: some View {
        let shown = filled ?? game
        VStack(spacing: 0) {
            if full {
                HStack {
                    Button(action: close) { Icon("x", size: 26).frame(width: 44, height: 44) }
                        .accessibilityIdentifier("gameClose").accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.leading, 14).frame(height: 48).contentShape(Rectangle())
            } else {
                Capsule().fill(Color.rgb(58, 59, 66)).frame(width: 39, height: 4)
                    .frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
                    .accessibilityIdentifier("gameHandle")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !full { header(shown) }
                    pictures(shown).padding(.top, full ? 0 : 28)
                    chips(shown).padding(.top, 22)
                    if !events.isEmpty { eventRow.padding(.top, 28) }
                    if let info {
                        Text("Description").font(.builder(20, .bold)).padding(.top, 28)
                        Text(info.description).font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(wholeText ? nil : 4).padding(.top, 10)
                            .accessibilityIdentifier("gameAbout")
                        Button(wholeText ? "less" : "more") { wholeText.toggle() }
                            .font(.builder(14.5, .medium)).underline().padding(.top, 4)
                        if let passes = more?.passes, !passes.isEmpty { store(passes).padding(.top, 28) }
                        information(info).padding(.top, 28)
                        if let links = more?.social, !links.isEmpty { social(links).padding(.top, 28) }
                        if let also = more?.also, !also.isEmpty {
                            Text("People Also Join").font(.builder(20, .bold)).padding(.top, 28).padding(.bottom, 12)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(also) { g in Button { open(.game(g)) } label: { GameCard(game: g).frame(width: 117) }.buttonStyle(PressStyle()) }
                                }
                            }
                            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
                        }
                    } else if loaded {
                        Button { Task { await load() } } label: {
                            Text("Couldn't load this experience's details. Tap to try again.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        .padding(.top, 28).accessibilityIdentifier("gameRetry")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 11).padding(.bottom, 24)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { g in
                if !full, g.translation.height < -24 { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = true } }
            })
            bar
        }
        .background(Self.sheet, in: UnevenRoundedRectangle(topLeadingRadius: full ? 0 : 16, topTrailingRadius: full ? 0 : 16))
        .offset(y: max(pull, 0))
        .gesture(
            DragGesture(minimumDistance: 6)
                .updating($pull) { g, pull, _ in pull = g.translation.height }
                .onEnded { g in
                    let flick = g.predictedEndTranslation.height
                    if flick < -80 { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = true } }
                    else if flick > 140 { if full { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { full = false } } else { close() } }
                },
            including: .gesture
        )
        .overlay {
            if let p = pass {
                BuyItemCard(name: p.name, price: p.price ?? 0, thumb: nil, close: { pass = nil }) { _ in
                    if !store.profile.send(p.price ?? 0) { notEnough = true }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: pass?.id)
        .alert("Not enough Robux", isPresented: $notEnough) {
            Button("OK", role: .cancel) {}
        } message: { Text("Get more on the Buy Robux page.") }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: pull == 0)
        .task { await load() }
    }

    private func header(_ shown: Game) -> some View {
        HStack(alignment: .top, spacing: 12.7) {
            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 56, height: 56)
                .overlay { RemoteImage(url: shown.icon, fill: true) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name).font(.builder(20, .bold)).lineLimit(2)
                if let c = info?.creator, !c.isEmpty {
                    HStack(spacing: 6) {
                        Text(c).font(.builder(16)).lineLimit(1)
                        if info?.creatorVerified == true { VerifiedBadge(size: 16).fixedSize() }
                    }
                }
                if let maturity { Text(maturity).font(.builder(14.5)).foregroundStyle(Color.faint) }
            }
        }
    }

    private func pictures(_ shown: Game) -> some View {
        let all = slides.isEmpty ? [shown.wide ?? shown.icon].compactMap { $0 } : slides
        return RoundedRectangle(cornerRadius: 8).fill(Color.tile).aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                TabView(selection: $slide) {
                    ForEach(all.indices, id: \.self) { i in RemoteImage(url: all[i], fill: true).tag(i) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                if all.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(all.indices, id: \.self) { i in
                            Capsule().fill(Color.white.opacity(i == slide ? 1 : 0.75)).frame(width: i == slide ? 24 : 6, height: 6)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: slide)
                    .padding(.bottom, 14)
                }
            }
    }

    private func chips(_ shown: Game) -> some View {
        let favourite = store.profile.games.contains { $0.id == game.id }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Icon("thumb-up", size: 16)
                    Text(shown.rating.map { "\($0)%" } ?? "--")
                    Rectangle().fill(Color.faint.opacity(0.4)).frame(width: 1, height: 16)
                    Icon("thumb-down", size: 16)
                }
                .chip()
                HStack(spacing: 6) {
                    Icon("two-people", size: 16)
                    Text("\(short(info?.playing ?? game.playing)) active")
                }
                .chip()
                Button { notify.toggle() } label: {
                    HStack(spacing: 6) {
                        Icon("bell", size: 16, filled: notify)
                        Text(notify ? "Notifying" : "Notify")
                    }
                    .chip()
                }
                Button {
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(shown) }
                } label: {
                    HStack(spacing: 6) {
                        Icon("star", size: 16, filled: favourite)
                        Text(favourite ? "Favorited" : "Favorite")
                    }
                    .chip()
                }
                .accessibilityIdentifier("favoriteButton")
            }
        }
        .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        .buttonStyle(PressStyle())
    }

    private var bar: some View {
        let favourite = store.profile.games.contains { $0.id == game.id }
        return HStack(spacing: 0) {
            Menu {
                Button(favourite ? "Unfavorite" : "Favorite") {
                    if favourite { store.profile.games.removeAll { $0.id == game.id } } else { store.profile.games.append(filled ?? game) }
                }
                Button(notify ? "Stop notifications" : "Notify") { notify.toggle() }
            } label: { Icon("circle-three-dots-horizontal", size: 27).frame(width: 44, height: 48) }
                .accessibilityLabel("More")
            Button { close(); open(.friends) } label: { Icon("person-play", size: 27).frame(width: 44, height: 48) }
                .accessibilityLabel("Play with friends").padding(.leading, 13)
            Button {
                joining = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    joining = false
                }
            } label: {
                ZStack {
                    if joining { ProgressView().tint(.white) } else { Icon("play-large", size: 26, filled: true) }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("playButton").accessibilityLabel(joining ? "Joining" : "Play")
            .padding(.leading, 18)
        }
        .foregroundStyle(Color.ink)
        .padding(.leading, 14).padding(.trailing, 13).padding(.top, 13).padding(.bottom, 8)
        .background(Color.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.rgb(47, 48, 56)).frame(height: 1) }
    }

    private func load() async {
        loaded = false
        async let i = Roblox.gameInfo(game.id)
        async let m = Roblox.maturity(game.id)
        async let s = Roblox.slides(game.id)
        async let e = Roblox.events(game.id)
        async let g = Roblox.gameMore(game.id)
        if game.wide == nil || game.rating == nil || game.icon == nil { filled = await Roblox.complete([game]).first }
        (info, maturity, slides) = await (i, m, s)
        (events, eventPictures) = await e
        more = await g
        loaded = true
    }

    private var eventRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Events").font(.builder(20, .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(events.indices, id: \.self) { i in
                        let e = events[i]
                        let live = e.when() == "Live now"
                        VStack(alignment: .leading, spacing: 0) {
                            Color.tile.aspectRatio(16 / 9, contentMode: .fit)
                                .overlay { RemoteImage(url: e.media.flatMap { eventPictures[$0] }, fill: true) }
                                .clipped()
                                .overlay(alignment: .topLeading) {
                                    Text(live ? "Happening now" : e.when()).font(.builder(12, .medium)).padding(.horizontal, 9).frame(height: 24)
                                        .background(Color.white, in: Capsule()).foregroundStyle(.black).padding(10)
                                }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.title).font(.builder(14.5, .bold)).lineLimit(1)
                                Text(e.subtitle.isEmpty ? " " : e.subtitle).font(.builder(13)).foregroundStyle(Color.faint).lineLimit(1)
                                Button { join() } label: {
                                    Text("Join Event").font(.builder(13, .medium)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 32)
                                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(PressStyle())
                                .padding(.top, 8)
                            }
                            .padding(10)
                        }
                        .background(Color.rgb(32, 33, 38))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 360)
                        .accessibilityIdentifier("gameEvent")
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func join() {
        joining = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            joining = false
        }
    }

    private func store(_ passes: [GamePass]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Store").font(.builder(20, .bold))
                Icon("chevron-large-right", size: 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(passes, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tile).frame(width: 130, height: 130)
                                .overlay { RemoteImage(url: more?.passIcons[p.id], fill: false).padding(14) }
                            Text(p.name).font(.builder(14.5, .bold)).lineLimit(1).frame(width: 130, alignment: .leading)
                            Button { if p.price != nil { pass = p } } label: {
                                HStack(spacing: 4) {
                                    if let price = p.price { Icon("robux", size: 15); Text(grouped(price)).font(.builder(13, .medium)) }
                                    else { Text("Off Sale").font(.builder(13, .medium)) }
                                }
                                .foregroundStyle(.black).frame(width: 130, height: 30).background(Color.white.opacity(p.price == nil ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func information(_ info: GameInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Information").font(.builder(20, .bold)).padding(.bottom, 4)
            fact("Visits", short(info.visits))
            if let m = maturity { fact("Content Maturity", m.replacingOccurrences(of: "Maturity: ", with: ""), arrow: true) }
            if !info.creator.isEmpty { fact("Developer", info.creator, badge: info.creatorVerified, arrow: true) }
            fact("Server Size", "\(info.maxPlayers)")
            if !info.genre.isEmpty { fact("Genre", info.genre) }
            if !info.subgenre.isEmpty { fact("Subgenre", info.subgenre) }
            fact("Created", info.created)
            fact("Updated", info.updated)
            if let v = more?.voice { fact("Voice Chat", v ? "Supported" : "Not supported") }
            if let c = more?.camera { fact("Camera", c ? "Supported" : "Not supported") }
        }
    }

    private func social(_ links: [SocialLink]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Media").font(.builder(20, .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(links, id: \.url) { l in
                        if let u = URL(string: l.url) {
                            Link(destination: u) {
                                VStack(spacing: 8) {
                                    Circle().fill(Color.tile).frame(width: 92, height: 92)
                                        .overlay(Icon(["Discord": "discord", "YouTube": "youtube", "Twitter": "twitter", "Twitch": "twitch",
                                                       "Facebook": "facebook", "Guilded": "guilded"][l.type] ?? "chain-link", size: 34, filled: true))
                                    Text(l.type).font(.builder(12)).lineLimit(1)
                                }
                                .frame(width: 96)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, -20).contentMargins(.horizontal, 20)
        }
    }

    private func fact(_ name: String, _ value: String, badge: Bool = false, arrow: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(name).font(.builder(16)).foregroundStyle(Color.faint)
                Spacer()
                Text(value).font(.builder(16, .bold)).lineLimit(1)
                if badge { VerifiedBadge(size: 14).fixedSize() }
                if arrow { Icon("chevron-large-right", size: 14) }
            }
            .frame(height: 57)
            Divider().overlay(Color.tile)
        }
    }
}

private extension View {
    func chip() -> some View {
        font(.builder(14.5)).padding(.horizontal, 12).frame(height: 32).background(Color.tile, in: Capsule())
    }
}

// MARK: - Notifications
