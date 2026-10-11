import SwiftUI
import BloxKit

extension Color {
    static let bloxBlue = Color(red: 0.2, green: 0.37, blue: 1)       // #335FFF, Roblox's button blue
    static let bg = Color(red: 0.07, green: 0.075, blue: 0.09)          // Roblox's dark background
    static let tile = Color(red: 0.165, green: 0.17, blue: 0.195)       // item and game picture tiles
    static let field = Color(red: 0.19, green: 0.195, blue: 0.22)
    static let faint = Color(white: 0.68)
}

struct RobuxIcon: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Hexagon().stroke(lineWidth: size * 0.13)
            RoundedRectangle(cornerRadius: size * 0.05).stroke(lineWidth: size * 0.13).frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
    }
}

struct Hexagon: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            for i in 0..<6 {
                let a = Double(i) * .pi / 3 - .pi / 2
                let pt = CGPoint(x: r.midX + r.width / 2 * cos(a), y: r.midY + r.height / 2 * sin(a))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }
}

struct VerifiedBadge: View {
    var size: CGFloat = 22
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(Color.bloxBlue)
            .frame(width: size, height: size)
            .overlay(Image(systemName: "checkmark").font(.system(size: size * 0.55, weight: .black)).foregroundStyle(.white))
            .rotationEffect(.degrees(-8))
    }
}

struct MemberBadge: View {
    let badge: Badge
    var size: CGFloat = 22
    var body: some View {
        switch badge {
        case .none: EmptyView()
        case .plus: Image(systemName: "plus.square").font(.system(size: size * 0.95, weight: .semibold)).foregroundStyle(Color(white: 0.85))
        case .pro:
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: size * 0.08).stroke(lineWidth: size * 0.13)
                Path { p in
                    p.move(to: CGPoint(x: size * 0.3, y: size * 0.78))
                    p.addLine(to: CGPoint(x: size * 0.3, y: size * 0.3))
                    p.addLine(to: CGPoint(x: size * 0.7, y: size * 0.3))
                    p.addLine(to: CGPoint(x: size * 0.7, y: size * 0.62))
                    p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.62))
                }
                .stroke(style: StrokeStyle(lineWidth: size * 0.12))
            }
            .frame(width: size, height: size)
            .foregroundStyle(Color(white: 0.85))
        }
    }
}

struct NameLine: View {
    let profile: Profile
    var font: CGFloat = 30
    var body: some View {
        HStack(spacing: 8) {
            Text(profile.displayName).font(.system(size: font, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("displayName")
            if profile.verified { VerifiedBadge(size: font * 0.75) }
            MemberBadge(badge: profile.badge, size: font * 0.75)
        }
    }
}

struct AvatarPicture: View {
    let image: UIImage?
    var body: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("avatarImage")
        } else {
            Image(systemName: "figure.stand").resizable().scaledToFit().padding(40).foregroundStyle(Color(white: 0.3))
        }
    }
}

struct Headshot: View {
    let image: UIImage?
    let crop: Crop
    let size: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.32), Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: size * crop.scale, height: size * crop.scale)
                    .offset(x: crop.x * size, y: crop.y * size)
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.5)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct Thumb: View {
    let url: String?
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.tile)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: url.flatMap(URL.init(string:))) { img in
                    img.resizable().scaledToFit().padding(10)
                } placeholder: { EmptyView() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PriceLine: View {
    let price: Int?
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 5) {
            if let price, price > 0 { RobuxIcon(size: size * 1.05) }
            Text(priceText(price)).font(.system(size: size, weight: .medium))
        }
        .foregroundStyle(.primary)
    }
}

struct ItemCard: View {
    let item: Item
    var showCreator = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Thumb(url: item.thumb)
            Text(item.name).font(.system(size: 14, weight: .bold)).lineLimit(1).padding(.top, 4)
            if showCreator {
                HStack(spacing: 4) {
                    Text(item.creator).foregroundStyle(Color.faint).lineLimit(1)
                    if item.showsCreatorCheck { VerifiedBadge(size: 13) }
                }
                .font(.system(size: 13))
            }
            PriceLine(price: item.price)
        }
    }
}

struct GameCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Thumb(url: game.icon)
            Text(game.name).font(.system(size: 14, weight: .bold)).lineLimit(2, reservesSpace: true)
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                Text("\(short(game.playing)) Playing")
            }
            .font(.system(size: 12)).foregroundStyle(Color.faint)
        }
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 18)).padding(.horizontal, 12).frame(minHeight: 40)
            .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func field() -> some View { modifier(FieldStyle()) }
}

struct NumberField: View {
    @Binding var value: Int
    let id: String
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad)
            .field()
            .accessibilityIdentifier(id)
            .onAppear { text = "\(value)" }
            .onChange(of: text) { _, t in value = number(from: t) }
    }
}

struct WideGameCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            RoundedRectangle(cornerRadius: 8).fill(Color.tile)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    AsyncImage(url: (game.wide ?? game.icon).flatMap(URL.init(string:))) { $0.resizable().scaledToFill() }
                        placeholder: { EmptyView() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(game.name).font(.system(size: 16, weight: .bold)).lineLimit(1).padding(.top, 6)
            HStack(spacing: 5) {
                Image(systemName: "hand.thumbsup.fill")
                Text(game.rating.map { "\($0)% Rating" } ?? "\(short(game.playing)) Playing")
            }
            .font(.system(size: 15)).foregroundStyle(Color.faint)
        }
    }
}

struct RemoteCircle: View {
    let url: String?
    let size: CGFloat
    var body: some View {
        Circle().fill(Color.tile)
            .overlay {
                AsyncImage(url: url.flatMap(URL.init(string:))) { $0.resizable().scaledToFill() } placeholder: {
                    Image(systemName: "person.fill").font(.system(size: size * 0.4)).foregroundStyle(Color.faint)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

struct Wordmark: View {
    var size: CGFloat = 25
    var body: some View {
        HStack(spacing: size * 0.04) {
            Text("R")
            RoundedRectangle(cornerRadius: size * 0.08)
                .frame(width: size * 0.68, height: size * 0.68)
                .overlay(Rectangle().fill(Color.bg).frame(width: size * 0.2, height: size * 0.2))
                .rotationEffect(.degrees(-15))
            Text("BLOX")
        }
        .font(.system(size: size, weight: .black, design: .default).width(.expanded))
        .foregroundStyle(.white)
    }
}

struct CountBubble: View {
    let n: Int
    var size: CGFloat = 22
    var body: some View {
        if n > 0 {
            Text(n > 99 ? "99+" : "\(n)").font(.system(size: size * 0.62, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, size * 0.28).frame(minWidth: size, minHeight: size)
                .background(Color.bloxBlue, in: Capsule())
        }
    }
}
