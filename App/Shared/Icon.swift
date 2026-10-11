import SwiftUI
import SalBloxKit

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

struct RobuxIcon: View {
    var size: CGFloat = 16
    var body: some View { Icon("robux", size: size * 1.2) }
}

struct Wordmark: View {
    var size: CGFloat = 20
    var body: some View {
        Image("wordmark").resizable().scaledToFit().frame(height: size).accessibilityLabel("Roblox")
    }
}
