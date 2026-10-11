import SwiftUI
import SalBloxKit

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
