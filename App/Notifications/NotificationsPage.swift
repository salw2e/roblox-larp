import SwiftUI
import SalBloxKit

struct NotificationsPage: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.profile.notices.isEmpty {
                    Text("You have no notifications.").font(.builder(14.5)).foregroundStyle(Color.faint)
                        .frame(maxWidth: .infinity).padding(.top, 60)
                }
                ForEach(store.profile.notices) { n in
                    let friend = store.profile.friendList.first { $0.id == n.friend }
                    HStack(alignment: .top, spacing: 12) {
                        if let friend {
                            RemoteCircle(url: friend.headshot, size: 48)
                        } else {
                            Circle().fill(Color.tile).frame(width: 48, height: 48).overlay(Icon("tilt", size: 24, filled: true))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            (Text(friend.map { $0.displayName + " " } ?? "").font(.builder(14.5, .bold)) + Text(n.text).font(.builder(14.5)))
                                .accessibilityIdentifier("noticeText")
                            Text(n.when).font(.builder(12)).foregroundStyle(Color.faint)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("noticeRow")
                    Divider().overlay(Color.tile)
                }
            }
            .padding(.horizontal, 20)
        }
        .page("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.profile.notifications > 0 {
                    Button("Mark read") { store.profile.notifications = 0 }
                        .font(.builder(14.5)).accessibilityIdentifier("markRead")
                }
            }
        }
    }
}

// MARK: - Chat
