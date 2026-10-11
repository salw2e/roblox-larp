import SwiftUI
import SalBloxKit

struct MenuView: View {
    @EnvironmentObject var store: Store
    let open: (Page?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button { open(.profile) } label: {
                    HStack(spacing: 18) {
                        Headshot(image: store.avatar, crop: store.profile.crop, size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.profile.shownName).font(.builder(14.6, .bold)).lineLimit(1)
                            Text("@\(store.profile.shownUsername)").font(.builder(14.4)).foregroundStyle(Color(white: 0.85)).lineLimit(1)
                        }
                    }
                }
                .accessibilityIdentifier("menuProfile")
                .padding(.top, 10)
                robuxCard.padding(.top, 14)
                VStack(alignment: .leading, spacing: 0) {
                    row("bookmark", "Favorites", page: .favorites)
                    row("clock-spin-reverse", "Continue Playing", page: .continuePlaying)
                    row("two-people", "Friends", count: store.profile.friendsBadge, page: .friends)
                    row("three-people", "Communities", page: .info(.communities))
                    row("backpack", "Inventory", page: .inventory)
                    row("hand-two-arrows-horizontal", "Trades", page: .trades)
                    row("envelope", "Messages", count: store.profile.messages, page: .info(.messages))
                    row("roblox-plus", "Roblox Plus", page: .info(.plus))
                    row("gear", "Settings", page: .settings)
                    row("shield-lock", "Help & Safety", page: .info(.help))
                    Divider().overlay(Color(white: 0.25)).padding(.vertical, 8)
                    row("moments", "Moments", page: .momentsTab)
                    row("person-graduate", "Learn", page: .info(.learn))
                    row("studio", "Create", page: .info(.create))
                }
                .padding(.top, 14)
                Button { open(.info(.accounts)) } label: {
                    Text("Switch Accounts").font(.builder(16)).frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("menu-Switch Accounts")
                .padding(.top, 14).padding(.bottom, 20)
            }
            .padding(.horizontal, 18)
        }
        .containerRelativeFrame(.horizontal) { w, _ in w * 0.8 }
        .background(Color(red: 0.06, green: 0.065, blue: 0.08).ignoresSafeArea())
        .foregroundStyle(.white)
    }

    private var robuxCard: some View {
        VStack(spacing: 0) {
            Button { open(.robux) } label: {
                HStack(spacing: 12) {
                    RobuxIcon(size: 20)
                    Text(grouped(store.profile.robux)).font(.builder(15, .bold)).accessibilityIdentifier("menuRobux")
                    Spacer()
                    Text("Buy Robux").font(.builder(14)).padding(.horizontal, 10).frame(height: 36)
                        .background(Color.field, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 14).frame(height: 56).contentShape(Rectangle())     // measured from Sal's screenshot
            }
            .accessibilityIdentifier("menuBuyRobux")
            Divider().overlay(Color(white: 0.25))
            Button { open(.info(.plus)) } label: {
                HStack(spacing: 18) {
                    Icon("roblox-plus", size: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("More fun for less Robux.")
                        Text("Subscribe to Roblox Plus.")
                    }
                    .font(.builder(12.1))
                    Spacer()
                    Icon("chevron-large-right", size: 20)
                }
                .padding(.horizontal, 14).frame(height: 58).contentShape(Rectangle())
            }
            .accessibilityIdentifier("menuPlus")
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.25), lineWidth: 1))
    }

    private func row(_ icon: String, _ title: String, count: Int = 0, page: Page? = nil) -> some View {
        Button { if page != nil { open(page) } } label: {
            HStack(spacing: 22) {
                Icon(icon, size: 21).frame(width: 26)
                Text(title).font(.builder(16, .bold))
                Spacer()
                CountBubble(n: count, size: 17)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("menu-\(title)")
    }
}

// MARK: - Simple pages
