import SwiftUI
import SalBloxKit

struct SendRobuxSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var to: Friend?
    @State private var amount = "25"
    @State private var refused = false
    @State private var reviewing = false
    @State private var joined: String?
    @State private var detent = PresentationDetent.height(822)
    @State private var anyone: [Friend] = []        // everyone on roblox the search finds, not only friends

    var body: some View {
        let p = store.profile
        let shown = p.friendList.filter { search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Icon("roblox-plus", size: 21)
                Text("Send Robux").font(.builder(19.6, .bold))
                Spacer()
                Icon("robux", size: 16)
                Text(grouped(p.robux)).font(.builder(14.5, .bold)).accessibilityIdentifier("sendBalance")
                if to == nil {
                    Button { dismiss() } label: { Icon("x", size: 26).frame(width: 36, height: 36) }
                        .accessibilityIdentifier("sendClose").accessibilityLabel("Close").padding(.leading, 6)
                }
            }
            .frame(height: 36)
            .padding(.top, to == nil ? 13 : 23)
            if let to, reviewing { reviewPage(to, number(from: amount)) } else if let to { amountPage(to) } else {
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
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 21)
        .presentationDetents([.height(822), .height(560)], selection: $detent)
        .presentationDragIndicator(to == nil ? .hidden : .visible)
        .presentationCornerRadius(16)
        .presentationBackground(Color.rgb(25, 26, 31))
        .task(id: to?.id) {
            joined = nil
            if let id = to?.id { joined = await Roblox.joinedYear(id) }
        }
        .onChange(of: to) { _, picked in
            reviewing = false
            withAnimation { detent = .height(picked == nil ? 822 : 560) }
        }
        .alert("Not sent", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter an amount you have, more than 0.")
        }
    }

    // who, how much, Next: the amount screen of the real app
    // after Next: who it goes to, how much, Send or Edit
    private func reviewPage(_ f: Friend, _ n: Int) -> some View {
        let panel = Color.rgb(32, 33, 38)
        func fact(_ icon: String, _ text: String) -> some View {
            HStack(spacing: 5) {
                Icon(icon, size: 15, filled: true)
                Text(text).font(.builder(13.5))
            }
            .foregroundStyle(Color.faint)
        }
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                RemoteCircle(url: f.headshot, size: 62)
                Text(f.displayName).font(.builder(15.5, .bold)).lineLimit(1).padding(.top, 12)
                Text("@\(f.name)").font(.builder(14)).foregroundStyle(Color.faint).lineLimit(1).padding(.top, 3)
                HStack(spacing: 12) {
                    fact("calendar", store.profile.friendList.contains { $0.id == f.id } ? "Connection" : "New Connection")
                    fact("two-people", "0 mutual Connections")
                }
                .padding(.top, 16)
                if let joined { fact("circle-i", "Joined in \(joined)").padding(.top, 10) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(panel, in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 14)
            HStack(spacing: 8) {
                Icon("robux", size: 30)
                Text(grouped(n)).font(.builder(44, .bold))
            }
            .frame(maxWidth: .infinity).frame(height: 86)
            .background(panel, in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 10)
            HStack(spacing: 8) {
                Button {
                    if store.profile.send(n) {
                        store.say("You sent \(grouped(n)) Robux")
                        dismiss()
                    } else { refused = true }
                } label: {
                    Text("Send").font(.builder(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 41)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("sendConfirm")
                Button { reviewing = false } label: {
                    Text("Edit").font(.builder(16, .bold)).frame(maxWidth: .infinity).frame(height: 41)
                        .background(Color.tile, in: RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("sendEdit")
            }
            .buttonStyle(PressStyle())
            .padding(.top, 12)
            Text("You need an age check or parental consent to send Robux. Once you send, you cannot cancel.")
                .font(.builder(12)).foregroundStyle(Color.faint).frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, -6)
    }

    private func amountPage(_ f: Friend) -> some View {
        let n = number(from: amount)
        return VStack(spacing: 0) {
            RemoteCircle(url: f.headshot, size: 62).padding(.top, 78)
            Text(f.displayName).font(.builder(14.5, .bold)).lineLimit(1).padding(.top, 14)
                .accessibilityIdentifier("sendingTo")
            HStack(spacing: 8) {
                Icon("robux", size: 30)
                TextField("0", text: $amount).keyboardType(.numberPad).font(.builder(44, .bold)).fixedSize()
                    .onChange(of: amount) { _, typed in
                        // 2000 reads 2,000 while you type. changing the text from here is what makes the field redraw it
                        let n = number(from: String(digits(in: typed).prefix(9))), tidy = n == 0 ? "" : grouped(n)
                        if tidy != typed { amount = tidy }
                    }
                    .accessibilityIdentifier("sendAmount")
            }
            .frame(height: 53)
            .padding(.top, 30)
                HStack(spacing: 8) {
                    ForEach([25, 50, 100, 200], id: \.self) { preset in
                        Button { amount = "\(preset)" } label: {
                            HStack(spacing: 8) {
                                Icon("robux", size: 19)
                                Text("\(preset)").font(.builder(15, .bold))
                            }
                            .padding(.horizontal, 14).frame(height: 42)
                            .background(n == preset ? Color.clear : Color.tile, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(n == preset ? Color.ink : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("sendPreset-\(preset)")
                    }
                }
                .padding(.top, 45)
            Button {
                guard n > 0, n <= store.profile.robux else { refused = true; return }
                reviewing = true
            } label: {
                Text("Next").font(.builder(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 41)
                    .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("sendNext")
            .padding(.horizontal, -6).padding(.top, 44)
            Text("Robux are sent instantly with no fees").font(.builder(12)).foregroundStyle(Color.faint).padding(.top, 19)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ f: Friend, id: String) -> some View {
        Button { to = f; amount = "25" } label: {
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
