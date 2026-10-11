import SwiftUI
import SalBloxKit

struct ChatPage: View {
    @EnvironmentObject var store: Store
    let friendId: Int64
    @State private var draft = ""
    @State private var asThem = false
    @FocusState private var typing: Bool

    var body: some View {
        let friend = store.profile.friendList.first { $0.id == friendId }
        let lines = store.profile.chat(with: friendId)
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.element.key) { i, line in
                            HStack(alignment: .bottom, spacing: 8) {
                                if line.mine { Spacer(minLength: 60) } else { RemoteCircle(url: friend?.headshot, size: 28) }
                                Text(line.text).font(.builder(14.5)).padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(line.mine ? Color.bloxBlue : Color.tile, in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(line.mine ? .white : Color.ink)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            store.profile.chats["\(friendId)"]?.removeAll { $0 == line }
                                        }
                                    }
                                if !line.mine { Spacer(minLength: 60) }
                            }
                            .id(i)
                            .accessibilityIdentifier(line.mine ? "myLine" : "theirLine")
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lines.count) { _, n in withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) } }
                .onChange(of: typing) { _, on in
                    if on { withAnimation { proxy.scrollTo(lines.count - 1, anchor: .bottom) } }
                }
                .onAppear { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
            }
            HStack(spacing: 10) {
                Button { asThem.toggle() } label: {
                    Icon(asThem ? "person" : "two-arrows-switch-right", size: 22, filled: asThem)
                        .frame(width: 40, height: 40).background(asThem ? Color.bloxBlue : Color.tile, in: Circle())
                }
                .accessibilityIdentifier("sendAsThem").accessibilityLabel(asThem ? "Sending as them" : "Sending as you")
                TextField(asThem ? "Their message" : "Say something", text: $draft).font(.builder(14.5))
                    .padding(.horizontal, 14).frame(height: 40).background(Color.tile, in: Capsule())
                    .focused($typing)
                    .submitLabel(.send).onSubmit(send)
                    .accessibilityIdentifier("chatField")
                Button(action: send) { Icon("paper-airplane", size: 24, filled: true) }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("chatSend").accessibilityLabel("Send")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .page(friend?.displayName ?? "Chat")
    }

    private func send() {
        store.profile.say(draft, to: friendId, mine: !asThem)
        draft = ""
        typing = true
    }
}

extension ChatLine {
    var key: String { id.map { "#\($0)" } ?? "\(mine)|\(text)" }
}

// MARK: - Trades
