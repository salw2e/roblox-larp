import SwiftUI
import SalBloxKit

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
