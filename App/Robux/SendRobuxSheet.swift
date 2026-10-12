import SwiftUI
import SalBloxKit

struct SendRobuxSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var to: Friend?
    @State private var amount = ""
    @State private var refused = false
    @State private var anyone: [Friend] = []        // everyone on roblox the search finds, not only friends

    var body: some View {
        let p = store.profile
        let shown = p.friendList.filter { search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Icon("premium", size: 20)
                Text("Send Robux").font(.builder(19.6, .bold))
                Spacer()
                Icon("robux", size: 16)
                Text(grouped(p.robux)).font(.builder(14.5, .bold)).accessibilityIdentifier("sendBalance")
                Button { dismiss() } label: { Icon("x", size: 26).frame(width: 36, height: 36) }
                    .accessibilityIdentifier("sendClose").accessibilityLabel("Close").padding(.leading, 6)
            }
            .padding(.top, 13)
            HStack(spacing: 10) {
                Icon("magnifying-glass", size: 20)
                TextField("", text: $search, prompt: Text("Search").foregroundStyle(Color.faint))
                    .font(.builder(13.7)).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityIdentifier("sendSearch")
            }
            .padding(.horizontal, 14).frame(height: 39)
            .overlay(Capsule().stroke(Color.tile, lineWidth: 1))
            .padding(.top, 16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if !shown.isEmpty || search.isEmpty {
                        Text("My friends (\(grouped(search.isEmpty ? p.friendList.count : shown.count)))").font(.builder(15.9, .bold)).padding(.top, 4).padding(.bottom, -4)
                    }
                    ForEach(shown) { f in row(f, id: "sendTo") }
                    let others = anyone.filter { a in !shown.contains { $0.id == a.id } }
                    if !others.isEmpty {
                        Text("People").font(.builder(15.9, .bold)).padding(.top, shown.isEmpty ? 4 : 8)
                        ForEach(others) { f in row(f, id: "sendToAnyone") }
                    }
                }
                .padding(.top, 16).padding(.bottom, 24)
            }
            .task(id: search) {
                let q = search.trimmingCharacters(in: .whitespaces)
                guard q.count >= 3 else { anyone = []; return }           // roblox wants three letters
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                let found = await Roblox.people(q)
                if !Task.isCancelled { anyone = found }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 21)
        .presentationDetents([.height(822)])
        .presentationCornerRadius(16)
        .presentationBackground(Color.rgb(25, 26, 31))
        .alert("Send Robux to \(to?.displayName ?? "")", isPresented: Binding(get: { to != nil }, set: { if !$0 { to = nil } })) {
            TextField("Amount", text: $amount).keyboardType(.numberPad)
            Button("Send") { if !store.profile.send(number(from: amount)) { refused = true } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(grouped(store.profile.robux)) Robux.")
        }
        .alert("Not sent", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter an amount you have, more than 0.")
        }
    }

    private func row(_ f: Friend, id: String) -> some View {
        Button { to = f; amount = "" } label: {
            HStack(spacing: 15) {
                RemoteCircle(url: f.headshot, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.displayName).font(.builder(14, .bold)).lineLimit(1)
                    if id == "sendToAnyone" { Text("@\(f.name)").font(.builder(12)).foregroundStyle(Color.faint).lineLimit(1) }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier(id)
    }
}
