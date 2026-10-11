import SwiftUI
import BloxKit

extension Color {
    static let bloxBlue = Color(red: 0.2, green: 0.37, blue: 1)       // #335FFF, Roblox's button blue
    static let field = Color(white: 0.94)
    static let faint = Color(white: 0.45)
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
        case .plus: Image(systemName: "plus.square").font(.system(size: size * 0.95, weight: .semibold)).foregroundStyle(Color(white: 0.3))
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
            .foregroundStyle(Color(white: 0.3))
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
            Image(systemName: "figure.stand").resizable().scaledToFit().padding(60).foregroundStyle(Color(white: 0.8))
        }
    }
}

struct Headshot: View {
    let image: UIImage?
    let crop: Crop
    let size: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.93), Color(white: 0.82)], startPoint: .top, endPoint: .bottom)
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
        RoundedRectangle(cornerRadius: 12).fill(Color.field)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: url.flatMap(URL.init(string:))) { img in
                    img.resizable().scaledToFit().padding(10)
                } placeholder: { EmptyView() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PriceLine: View {
    let price: Int?
    var size: CGFloat = 17
    var body: some View {
        HStack(spacing: 5) {
            if let price, price > 0 { RobuxIcon(size: size * 1.05) }
            Text(priceText(price)).font(.system(size: size, weight: .medium))
        }
        .foregroundStyle(price == 0 ? Color.primary : Color.faint)
    }
}

struct ItemCard: View {
    let item: Item
    var showCreator = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Thumb(url: item.thumb)
            Text(item.name).font(.system(size: 17, weight: .bold)).lineLimit(1).padding(.top, 6)
            if showCreator {
                HStack(spacing: 4) {
                    Text(item.creator).foregroundStyle(Color.faint).lineLimit(1)
                    if item.creator == "Roblox" { VerifiedBadge(size: 13) }
                }
                .font(.system(size: 15))
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
            Text(game.name).font(.system(size: 16, weight: .bold)).lineLimit(2, reservesSpace: true)
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                Text("\(short(game.playing)) Playing")
            }
            .font(.system(size: 13)).foregroundStyle(Color.faint)
        }
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 22)).padding(.horizontal, 20).frame(minHeight: 66)
            .background(Color.field, in: RoundedRectangle(cornerRadius: 16))
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
