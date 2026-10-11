import SwiftUI
import SalBloxKit

struct FriendsListView: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    @State private var name = ""
    @State private var adding = false
    @State private var note = ""

    var body: some View {
        let listed = store.profile.friendList.count, more = store.profile.friends - listed
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Add a friend by Roblox username", text: $name).font(.builder(14.5))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go).onSubmit(add)
                        .padding(.horizontal, 12).frame(height: 40).background(Color.tile, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("friendsAddField")
                    Button(action: add) {
                        Group { if adding { ProgressView().tint(.white) } else { Text("Add").font(.builder(14.5, .bold)) } }
                            .frame(width: 64, height: 40).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
                    }
                    .disabled(adding || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("friendsAddButton")
                }
                .padding(.top, 12)
                if !note.isEmpty { Text(note).font(.builder(12)).foregroundStyle(Color.faint).padding(.top, 8).accessibilityIdentifier("friendsAddNote") }
                Text("Friends (\(grouped(max(store.profile.friends, listed))))").font(.builder(20, .bold)).padding(.top, 20).padding(.bottom, 8)
                ForEach(store.profile.friendList) { f in
                    Button { open(.friend(f.id)) } label: {
                        HStack(spacing: 12) {
                            RemoteCircle(url: f.headshot, size: 48)
                                .overlay(alignment: .bottomTrailing) {
                                    if f.online {
                                        Circle().fill(Color.bg).frame(width: 16, height: 16)
                                            .overlay(Circle().fill(Color.online).frame(width: 11, height: 11))
                                    }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.displayName).font(.builder(16, .bold)).lineLimit(1)
                                Text(f.status.isEmpty ? (f.online ? "Online" : "Offline") : f.status)
                                    .font(.builder(14.5)).foregroundStyle(f.online && !f.status.isEmpty ? Color.online : Color.faint).lineLimit(1)
                            }
                            Spacer()
                            Icon("chevron-large-right", size: 18).foregroundStyle(Color.faint)
                        }
                        .frame(height: 68).contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("friendRowPage")
                    Divider().overlay(Color.tile)
                }
                if more > 0 {
                    Text("and \(grouped(more)) more").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 20)
        }
        .page("Friends")
    }

    private func add() {
        let who = name.trimmingCharacters(in: .whitespaces)
        guard !who.isEmpty, !adding else { return }
        adding = true
        note = ""
        Task {
            do {
                note = try await store.addFriend(who) ? "Added \(who)." : "\(who) is already in your friends."
                name = ""
            } catch {
                note = error.localizedDescription
            }
            adding = false
        }
    }
}
