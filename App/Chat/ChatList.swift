import SwiftUI
import SalBloxKit

struct ChatList: View {
    @EnvironmentObject var store: Store
    var openMenu: () -> Void = {}
    let open: (Page) -> Void
    @State private var searching = false
    @State private var query = ""
    @FocusState private var typing: Bool

    var body: some View {
        let p = store.profile
        let shown = p.friendList.enumerated()
            .filter { query.isEmpty || $0.element.displayName.localizedCaseInsensitiveContains(query) || $0.element.name.localizedCaseInsensitiveContains(query) }
            .sorted { a, b in
                let x = p.chat(with: a.element.id).last?.at ?? 0, y = p.chat(with: b.element.id).last?.at ?? 0
                return x != y ? x > y : a.offset < b.offset
            }
            .map(\.element)
        VStack(alignment: .leading, spacing: 0) {
            header
            if searching {
                TextField("Search chats", text: $query).focused($typing).autocorrectionDisabled()
                    .font(.builder(16)).padding(.horizontal, 12).frame(height: 40)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20).padding(.bottom, 10)
                    .accessibilityIdentifier("chatSearch")
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !searching {
                        action("person-play", "Start party", "Join experiences together") { open(.friends) }
                        action("three-people", "Communities", "Create and explore communities") { open(.info(.communities)) }
                    }
                    if p.friendList.isEmpty {
                        Text("Add friends and they show up here.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
                        Button { open(.friends) } label: {
                            Text("Add Friends").font(.builder(14.5, .bold)).padding(.horizontal, 20).frame(height: 40)
                                .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(shown) { f in conversation(f) }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bg)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: openMenu) {
                Icon("three-bars-horizontal", size: 25)
                    .overlay(alignment: .topTrailing) { Circle().fill(Color.bloxBlue).frame(width: 8, height: 8).offset(x: 1, y: 1) }
            }
            .accessibilityIdentifier("chatMenu").accessibilityLabel("Menu")
            Text("Chat").font(.builder(28, .bold)).padding(.leading, 13)
            Spacer()
            Button {
                searching.toggle()
                query = ""
                typing = searching
            } label: { Icon(searching ? "x" : "magnifying-glass", size: 25) }
                .accessibilityIdentifier("chatSearchToggle").accessibilityLabel(searching ? "Close search" : "Search")
            Button { open(.friends) } label: { Icon("pencil-square", size: 25) }
                .accessibilityLabel("New chat").padding(.leading, 22)
        }
        .foregroundStyle(Color.ink)
        .frame(height: 28)
        .padding(.leading, 20).padding(.trailing, 24).padding(.top, 6).padding(.bottom, 13)
    }

    private func action(_ icon: String, _ title: String, _ detail: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            HStack(spacing: 10) {
                Icon(icon, size: 22).frame(width: 36, height: 36).background(Color.tile, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.builder(16.2, .bold))
                    Text(detail).font(.builder(12)).foregroundStyle(Color.faint)
                }
                Spacer()
                Icon("arrow-large-right", size: 22)
            }
            .padding(.leading, 20).padding(.trailing, 24).frame(height: 64)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tile).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func conversation(_ f: Friend) -> some View {
        let last = store.profile.chat(with: f.id).last
        return Button { open(.chat(f.id)) } label: {
            HStack(alignment: .center, spacing: 10) {
                RemoteCircle(url: f.headshot, size: 39)
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.displayName).font(.builder(16.1, .bold)).lineLimit(1)
                    Text(last?.text ?? " ").font(.builder(13.1)).foregroundStyle(Color.faint).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let at = last?.at { Text(chatTime(at)).font(.builder(12.3)).foregroundStyle(Color.faint) }
            }
            .padding(.leading, 20).padding(.trailing, 22).frame(height: 64)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tile).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("chatRow")
    }
}
