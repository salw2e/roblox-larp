import SwiftUI
import BloxKit

extension Color {
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
    static let bloxBlue = rgb(51, 95, 255)        // buttons and count bubbles
    static let verifiedBlue = rgb(0, 102, 255)
    static let online = rgb(57, 197, 130)
    static let bg = rgb(18, 18, 21)
    static let tile = rgb(40, 41, 48)
    static let field = rgb(40, 41, 48)
    static let pill = rgb(22, 22, 25)
    static let ink = rgb(247, 247, 248)           // main text
    static let faint = rgb(213, 215, 221)         // secondary text
    static let dim = rgb(188, 190, 200)           // unselected category tabs
}

struct Icon: View {
    let name: String
    var size: CGFloat
    var filled: Bool

    init(_ name: String, size: CGFloat = 22, filled: Bool = false) {
        self.name = name; self.size = size; self.filled = filled
    }

    static let available = UIFont(name: "BuilderIcons-Regular", size: 12) != nil

    var body: some View {
        if Self.available {
            Text(name).font(.custom(filled ? "BuilderIcons-Filled" : "BuilderIcons-Regular", fixedSize: size))
                .lineLimit(1).fixedSize().accessibilityHidden(true)
        } else {
            Color.clear.frame(width: size, height: size).accessibilityHidden(true)
        }
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
            Icon("verified-backplate", size: size * 1.2, filled: true).foregroundStyle(Color.verifiedBlue)
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
            Text(profile.shownName).font(.builder(font, .bold)).lineLimit(1).truncationMode(.tail).minimumScaleFactor(0.75)
                .accessibilityIdentifier("displayName")
            if profile.verified { VerifiedBadge(size: font * 0.75).fixedSize().accessibilityLabel("Verified") }
            MemberBadge(badge: profile.badge, size: font * 0.75).fixedSize()
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
                    .frame(width: size * crop.clamped.scale, height: size * crop.clamped.scale)
                    .offset(x: crop.clamped.x * size, y: crop.clamped.y * size)
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
                RemoteImage(url: url, fill: false).padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PriceLine: View {
    let price: Int?
    var size: CGFloat = 14.5
    var body: some View {
        HStack(spacing: 3) {
            if let price, price > 0 { Icon("robux", size: size * 1.15) }
            Text(priceText(price)).font(.builder(size))
        }
        .foregroundStyle(Color.ink)
    }
}

struct ItemCard: View {
    let item: Item
    var showCreator = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Thumb(url: item.thumb)
            Text(item.name).font(.builder(14.5, .bold)).lineLimit(1).frame(height: 18).padding(.top, 10)
            if showCreator {
                HStack(spacing: 4) {
                    Text(item.creator).foregroundStyle(Color.faint).lineLimit(1)
                    if item.showsCreatorCheck { VerifiedBadge(size: 12) }
                }
                .font(.builder(14.5)).frame(height: 18).padding(.top, 3)
            }
            PriceLine(price: item.price).frame(height: 18).padding(.top, showCreator ? 6 : 3)
        }
    }
}

struct GameCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Thumb(url: game.icon)
            Text(game.name).font(.builder(14, .bold)).lineLimit(2, reservesSpace: true)
            GameStats(game: game)
        }
    }
}

struct GameStats: View {
    let game: Game
    var body: some View {
        HStack(spacing: 3) {
            Icon("thumb-up", size: 13, filled: true)
            Text(game.rating.map { "\($0)%" } ?? "--")
            Icon("two-people", size: 13, filled: true).padding(.leading, 6)
            Text(short(game.playing))
        }
        .font(.builder(12)).foregroundStyle(Color.faint)
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
            .onChange(of: text) { _, t in
                let kept = digits(in: t)
                if kept != t { text = kept }
                value = number(from: kept)
            }
    }
}

struct WideGameCard: View {
    let game: Game
    var stats = false           // profiles show the small rating-and-players line instead of "86% Rating"
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 8).fill(Color.tile)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    RemoteImage(url: game.wide ?? game.icon, fill: true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(game.name).font(.builder(14.5, .bold)).lineLimit(1).frame(height: 18).padding(.top, 12)
            if stats {
                GameStats(game: game).frame(height: 16).padding(.top, 3)
            } else {
                HStack(spacing: 3) {
                    Icon(game.rating == nil ? "two-people" : "thumb-up", size: 15, filled: true)
                    Text(game.rating.map { "\($0)% Rating" } ?? "\(short(game.playing)) Playing")
                }
                .font(.builder(14.5)).foregroundStyle(Color.faint).frame(height: 18).padding(.top, 3)
            }
        }
    }
}

struct RemoteCircle: View {
    let url: String?
    let size: CGFloat
    var body: some View {
        Circle().fill(Color.tile)
            .overlay {
                Icon("person", size: size * 0.5, filled: true).foregroundStyle(Color.faint)
                RemoteImage(url: url, fill: true)
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
            Text(n > 99 ? "99+" : "\(n)").font(.builder(size * 0.68, .bold)).foregroundStyle(.white)
                .padding(.horizontal, size * 0.28).frame(minWidth: size, minHeight: size)
                .background(Color.bloxBlue, in: Capsule())
        }
    }
}

struct BackdropPicture: View {
    @EnvironmentObject var store: Store
    @State private var sharp: [Int64: String] = [:]
    var body: some View {
        if let item = store.profile.backdrop {
            Color.clear
                .overlay { RemoteImage(url: sharp[item.id] ?? item.thumb, fill: true) }
                .clipped()
                .allowsHitTesting(false)
                .task(id: item.id) { if sharp[item.id] == nil, let url = await Roblox.bigThumb(item) { sharp[item.id] = url } }
        }
    }
}

struct RemoteImage: View {
    let url: String?
    let fill: Bool
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        let shown = image ?? url.flatMap { Pictures.kept.object(forKey: $0 as NSString) }
        ZStack {
            if let shown {
                Image(uiImage: shown).resizable().aspectRatio(contentMode: fill ? .fill : .fit).transition(.opacity)
            } else if url != nil, !failed {
                Shimmer()
            }
        }
        .task(id: url) {
            guard let url else { return }
            failed = false
            let loaded = await Pictures.shared.image(url)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            failed = loaded == nil
        }
    }
}

struct Shimmer: View {
    static var animated: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return true
        #endif
    }
    @State private var moved = false

    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, Color.white.opacity(0.09), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.7)
                .offset(x: moved ? g.size.width : -g.size.width * 0.7)
        }
        .clipped()
        .onAppear {
            guard Self.animated else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { moved = true }
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
