import SwiftUI
import SalBloxKit

enum Page: Hashable, Identifiable {
    case profile, fullProfile, favorites, continuePlaying, friends, inventory, robux, transactions, notifications, trades
    case search, settings, momentsTab
    case game(Game), item(Item), trade(Int), chat(Int64), friend(Int64), person(Int64), info(Info)
    var id: String { "\(self)" }
}

enum Info: String, Hashable {
    case communities, messages, plus, help, learn, create, accounts

    var title: String {
        switch self {
        case .communities: "Communities"
        case .messages: "Messages"
        case .plus: "Roblox Plus"
        case .help: "Help & Safety"
        case .learn: "Learn"
        case .create: "Create"
        case .accounts: "Switch Accounts"
        }
    }

    var icon: String {
        switch self {
        case .communities: "three-people"
        case .messages: "envelope"
        case .plus: "roblox-plus"
        case .help: "shield-lock"
        case .learn: "person-graduate"
        case .create: "studio"
        case .accounts: "two-people"
        }
    }
}

extension View {
    func page(_ title: String) -> some View {
        background(Color.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bg, for: .navigationBar)
    }
}
