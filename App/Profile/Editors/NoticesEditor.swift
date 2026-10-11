import SwiftUI
import SalBloxKit

struct NoticesEditor: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var when = "now"
    @State private var friend: Int64?

    var body: some View {
        Form {
            Section("New notification") {
                TextField("Text, e.g. sent you a friend request", text: $text, axis: .vertical).accessibilityIdentifier("noticeText")
                TextField("When, e.g. 2h", text: $when)
                Picker("Whose face", selection: $friend) {
                    Text("Roblox").tag(Int64?.none)
                    ForEach(store.profile.friendList) { Text($0.displayName).tag(Int64?.some($0.id)) }
                }
                Button("Add") {
                    let id = store.profile.newId()
                    store.profile.notices.insert(Notice(id: id, text: text.trimmingCharacters(in: .whitespacesAndNewlines), when: when, friend: friend), at: 0)
                    store.profile.notifications += 1          // the bell counts it
                    text = ""
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("noticeAdd")
            }
            Section("Shown, newest first") {
                ForEach(store.profile.notices) { n in
                    VStack(alignment: .leading) {
                        Text(n.text)
                        Text(n.when).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { gone in
                    store.profile.notices.remove(atOffsets: gone)
                    store.profile.notifications = min(max(store.profile.notifications - gone.count, 0), store.profile.notices.count)
                }
                .onMove { store.profile.notices.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .navigationTitle("Notifications")
        .toolbar { EditButton() }
    }
}
