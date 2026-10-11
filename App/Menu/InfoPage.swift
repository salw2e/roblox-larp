import SwiftUI
import SalBloxKit

struct InfoPage: View {
    @EnvironmentObject var store: Store
    let kind: Info

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Icon(kind.icon, size: 56).padding(.top, 50)
                Text(kind.title).font(.builder(22, .bold))
                Text(text).font(.builder(14.5)).foregroundStyle(Color.faint).multilineTextAlignment(.center)
                if kind == .plus {
                    let on = store.profile.badge == .plus
                    WideButton(title: on ? "Cancel Roblox Plus" : "Subscribe", main: !on) { store.profile.badge = on ? .none : .plus }
                        .accessibilityIdentifier("plusSubscribe").padding(.top, 10)
                    Text(on ? "The Plus mark is on your profile." : "Subscribing here is free and only adds the Plus mark to your profile.")
                        .font(.builder(12)).foregroundStyle(Color.faint).multilineTextAlignment(.center)
                }
                if kind == .accounts {
                    HStack(spacing: 12) {
                        Headshot(image: store.avatar, crop: store.profile.crop, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.profile.shownName).font(.builder(16, .bold))
                            Text("@\(store.profile.shownUsername)").font(.builder(14.5)).foregroundStyle(Color.faint)
                        }
                        Spacer()
                        Icon("circle-check", size: 22, filled: true).foregroundStyle(Color.bloxBlue)
                    }
                    .padding(12).background(Color.tile, in: RoundedRectangle(cornerRadius: 8)).padding(.top, 10)
                }
            }
            .padding(.horizontal, 28)
        }
        .page(kind.title)
    }

    private var text: String {
        switch kind {
        case .communities: "You haven't joined any communities."
        case .messages: store.profile.messages > 0 ? "You have \(grouped(store.profile.messages)) unread messages." : "Your inbox is empty."
        case .plus: "More fun for less Robux: a monthly Robux stipend, discounts in the Marketplace, and trading."
        case .help: "Help and safety settings live on the Roblox website."
        case .learn: "Guides for building on Roblox live on the Creator Hub."
        case .create: "Experiences are made in Roblox Studio on a computer."
        case .accounts: "This phone is signed in to one account."
        }
    }
}
