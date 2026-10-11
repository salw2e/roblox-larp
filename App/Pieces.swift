import SwiftUI
import BloxKit

extension Color {
    static let bloxBlue = Color(red: 0.2, green: 0.37, blue: 1)       // #335FFF, Roblox's button blue
    static let bg = Color(red: 0.07, green: 0.075, blue: 0.09)          // Roblox's dark background
    static let tile = Color(red: 0.165, green: 0.17, blue: 0.195)       // item and game picture tiles
    static let field = Color(red: 0.19, green: 0.195, blue: 0.22)
    static let faint = Color(white: 0.68)
}

struct Icon: View {
    let name: String
    var size: CGFloat
    var filled: Bool

    init(_ name: String, size: CGFloat = 22, filled: Bool = false) {
        self.name = name; self.size = size; self.filled = filled
    }

    var body: some View {
        Text(name).font(.custom(filled ? "BuilderIcons-Filled" : "BuilderIcons-Regular", fixedSize: size))
            .lineLimit(1).fixedSize().accessibilityHidden(true)
    }
}

extension Font {
    static func builder(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .black, .heavy: face = "BuilderSans-ExtraBold"
        case .bold, .semibold: face = "BuilderSans-Bold"
        case .medium: face = "BuilderSans-Medium"
        default: face = "BuilderSans-Regular"
        }
        return .custom(face, fixedSize: size)
    }
}

struct RobuxIcon: View {
    var size: CGFloat = 16
    var body: some View { Icon("robux", size: size * 1.2) }
}

struct VerifiedBadge: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            Icon("verified-backplate", size: size * 1.2, filled: true).foregroundStyle(Color.bloxBlue)
            Icon("verified-check", size: size * 1.2, filled: true).foregroundStyle(.white)
        }
    }
}

struct MemberBadge: View {
    let badge: Badge
    var size: CGFloat = 22
    var body: some View {
        switch badge {
        case .none: EmptyView()
        case .plus: Icon("roblox-plus", size: size * 1.2).foregroundStyle(Color(white: 0.85))
        case .pro: Icon("premium", size: size * 1.2).foregroundStyle(Color(white: 0.85))
        }
    }
}

struct NameLine: View {
    let profile: Profile
    var font: CGFloat = 30
    var body: some View {
        HStack(spacing: 8) {
            Text(profile.displayName).font(.builder(font, .bold)).lineLimit(1).minimumScaleFactor(0.6)
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
            Icon("person-standing", size: 150).foregroundStyle(Color(white: 0.3)).frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Icon("person", size: size * 0.6, filled: true).foregroundStyle(.white)
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
            Text(priceText(price)).font(.builder(size, .medium))
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
            Text(item.name).font(.builder(14, .bold)).lineLimit(1).padding(.top, 4)
            if showCreator {
                HStack(spacing: 4) {
                    Text(item.creator).foregroundStyle(Color.faint).lineLimit(1)
                    if item.showsCreatorCheck { VerifiedBadge(size: 13) }
                }
                .font(.builder(13))
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
            Text(game.name).font(.builder(14, .bold)).lineLimit(2, reservesSpace: true)
            HStack(spacing: 4) {
                Icon("two-people", size: 15, filled: true)
                Text("\(short(game.playing)) Playing")
            }
            .font(.builder(12)).foregroundStyle(Color.faint)
        }
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.builder(18)).padding(.horizontal, 12).frame(minHeight: 40)
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
            .onAppear { text = value == 0 ? "" : "\(value)" }   // empty at 0, so typing doesn't give "011"
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
            Text(game.name).font(.builder(16, .bold)).lineLimit(1).padding(.top, 6)
            HStack(spacing: 5) {
                Icon("thumb-up", size: 18, filled: true)
                Text(game.rating.map { "\($0)% Rating" } ?? "\(short(game.playing)) Playing")
            }
            .font(.builder(15)).foregroundStyle(Color.faint)
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
                    Icon("person", size: size * 0.5, filled: true).foregroundStyle(Color.faint)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

struct Wordmark: View {
    var size: CGFloat = 20
    var body: some View {
        Image("wordmark").resizable().scaledToFit().frame(height: size).accessibilityLabel("Roblox")
    }
}

struct CountBubble: View {
    let n: Int
    var size: CGFloat = 22
    var body: some View {
        if n > 0 {
            Text(n > 99 ? "99+" : "\(n)").font(.builder(size * 0.62, .semibold)).foregroundStyle(.white)
                .padding(.horizontal, size * 0.28).frame(minWidth: size, minHeight: size)
                .background(Color.bloxBlue, in: Capsule())
        }
    }
}
