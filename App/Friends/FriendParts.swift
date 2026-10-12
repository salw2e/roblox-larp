import SwiftUI
import SalBloxKit

@MainActor
func personName(_ store: Store, _ id: Int64, _ person: Parse.Person?) -> (display: String, user: String, face: String?, online: Bool, status: String) {
    if let f = store.profile.friendList.first(where: { $0.id == id }) { return (f.displayName, f.name, f.headshot, f.online, f.status) }
    return (person?.displayName ?? "", person?.name ?? "", nil, false, "")
}

@MainActor
func counts(_ them: Roblox.Someone?) -> some View {
    func chip(_ n: Int, _ what: String) -> some View {
        Text(what == "Following" ? "\(short(n)) Following" : counted(n, what)).font(.builder(14.5)).lineLimit(1).fixedSize().padding(.horizontal, 12).frame(height: 31)
            .background(Color.tile.opacity(n == 0 ? 0.6 : 1), in: Capsule())
            .foregroundStyle(n == 0 ? Color.dim.opacity(0.6) : Color.ink)
    }
    return ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            if let n = them?.friends { chip(n, "Friend") }
            if let n = them?.followers { chip(n, "Follower") }
            if let n = them?.following { chip(n, "Following") }
        }
    }
}

@MainActor
func moreMenu(store: Store, id: Int64, close: @escaping () -> Void) -> some View {
    Menu {
        if store.profile.friendList.contains(where: { $0.id == id }) {
            Button("Unfriend", role: .destructive) {
                store.profile.removeFriend(id)
                close()
            }
        } else {
            Button("Add Friend") {
                Task { _ = try? await store.addFriendById(id) }
            }
        }
    } label: {
        Icon("three-dots-horizontal", size: 20).frame(width: 40, height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityIdentifier("friendMore").accessibilityLabel("More")
}
