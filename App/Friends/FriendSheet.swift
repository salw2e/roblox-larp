import SwiftUI
import SalBloxKit

struct FriendSheet: View {
    @EnvironmentObject var store: Store
    let id: Int64
    let close: () -> Void
    let open: (Page) -> Void
    @State private var them: Roblox.Someone?
    @State private var face: String?
    @State private var trusted = false
    @GestureState private var pull: CGFloat = 0

    var body: some View {
        let who = personName(store, id, them?.person)
        VStack(spacing: 0) {
            Capsule().fill(Color.rgb(58, 59, 66)).frame(width: 39, height: 4).frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        if let picture = them?.picture { RemoteImage(url: picture, fill: false) } else if them == nil { ProgressView().tint(Color.faint) }
                    }
                    .frame(height: 236).frame(maxWidth: .infinity)
                    HStack(alignment: .center, spacing: 12) {
                        RemoteCircle(url: who.face ?? face, size: 88)
                            .overlay(alignment: .bottomTrailing) {
                                if who.online { Circle().fill(Color.bg).frame(width: 20, height: 20).overlay(Circle().fill(Color.online).frame(width: 14, height: 14)).offset(x: -4, y: -4) }
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(who.display).font(.builder(20, .bold)).lineLimit(1).accessibilityIdentifier("friendName")
                                if them?.person?.verified == true { VerifiedBadge(size: 15).fixedSize() }
                            }
                            Text("@\(who.user)").font(.builder(14.5)).foregroundStyle(Color.faint).lineLimit(1)
                        }
                    }
                    .padding(.top, 6)
                    counts(them).padding(.top, 16)
                    HStack(spacing: 8) {
                        grey("Chat") { close(); open(.chat(id)) }.accessibilityIdentifier("friendChat")
                        grey(trusted ? "Trusted friend" : "Add trusted friend") { trusted.toggle() }
                        moreMenu(store: store, id: id, close: close)
                    }
                    .padding(.top, 20)
                    if let worn = them?.wearing, !worn.isEmpty {
                        Text("Currently Wearing").font(.builder(20, .bold)).padding(.top, 28).padding(.bottom, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(worn) { item in Button { open(.item(item)) } label: { ItemCard(item: item).frame(width: 136) }.buttonStyle(PressStyle()) }
                            }
                        }
                        .padding(.horizontal, -24).contentMargins(.horizontal, 24)
                    }
                    Button { open(.person(id)) } label: {
                        Text("View full profile").font(.builder(16, .medium)).frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ink, lineWidth: 1))
                    }
                    .accessibilityIdentifier("friendFullProfile")
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
        .foregroundStyle(Color.ink)
        .background(LinearGradient(colors: [Color.rgb(41, 40, 44), Color.rgb(77, 87, 100), Color.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)),
                    in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .offset(y: max(pull, 0))
        .gesture(DragGesture(minimumDistance: 6).updating($pull) { g, p, _ in p = g.translation.height }
            .onEnded { g in if g.predictedEndTranslation.height > 140 { close() } }, including: .gesture)
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: pull == 0)
        .task {
            async let t = Roblox.someone(id)
            async let f = Roblox.headshots([id])
            them = await t
            face = await f[id]
        }
    }

    private func grey(_ title: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            Text(title).font(.builder(14.5, .medium)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).frame(height: 40)
                .background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressStyle())
    }
}
