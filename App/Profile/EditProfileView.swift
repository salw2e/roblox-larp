import SwiftUI
import SalBloxKit
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var cropping = false
    @State private var copyName = ""
    @State private var copying = false
    @State private var copyStatus = ""
    @State private var photo: PhotosPickerItem?
    @State private var friendName = ""
    @State private var addingFriend = false
    @State private var friendStatus = ""
    @State private var photoStatus = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    account
                    counts
                    bio
                    badges
                    picture
                    avatarSource
                    friendsRow
                    menuCounts
                    gamesLink
                }
                .padding(22).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bg)
            .safeAreaInset(edge: .top, spacing: 0) { titleBar }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } }
            }
        }
        .sheet(isPresented: $cropping) { CropView() }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), store.usePhoto(data) {
                    photoStatus = "Picture set. It replaces the copied avatar everywhere, 3D model included."
                } else {
                    photoStatus = "That picture couldn't be used. Try another one."
                }
                photo = nil
            }
        }
        .onDisappear(perform: tidyNames)
    }

    private func tidyNames() {
        if store.profile.username.isEmpty { store.profile.username = "Player" }
        if store.profile.displayName.trimmingCharacters(in: .whitespaces).isEmpty { store.profile.displayName = store.profile.username }
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit — Profile").font(.builder(21, .bold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.builder(19, .medium)) }
                    .accessibilityIdentifier("closeEdit").accessibilityLabel("Close")
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            if !store.saveProblem.isEmpty {
                Text(store.saveProblem).font(.builder(12)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.vertical, 8).background(Color.red.opacity(0.8))
                    .accessibilityIdentifier("saveProblem")
            }
            Divider()
        }
        .background(Color.bg)
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Account")
            HStack(spacing: 10) {
                labelled("Username") {
                    TextField("", text: Binding(get: { store.profile.username }, set: { store.profile.username = cleanUsername($0) }))
                        .field().accessibilityIdentifier("usernameField")
                }
                labelled("Display name") {
                    TextField("", text: Binding(get: { store.profile.displayName }, set: { store.profile.displayName = String($0.prefix(20)) }))
                        .field().accessibilityIdentifier("displayNameField")
                }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            labelled("Robux") { NumberField(value: $store.profile.robux, id: "robuxField") }
        }
    }

    private var counts: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Friends, followers & following")
            HStack(spacing: 10) {
                labelled("Friends") { NumberField(value: $store.profile.friends, id: "friendsField") }
                labelled("Followers") { NumberField(value: $store.profile.followers, id: "followersField") }
                labelled("Following") { NumberField(value: $store.profile.following, id: "followingField") }
            }
        }
    }

    private var bio: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Bio")
            labelled("About (up to 1,000 characters)") {
                TextEditor(text: $store.profile.bio)
                    .font(.builder(18)).scrollContentBackground(.hidden)
                    .padding(8).frame(height: 106)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("bioField")
                    .onChange(of: store.profile.bio) { _, b in if b.count > 1000 { store.profile.bio = String(b.prefix(1000)) } }
            }
            caption("Shown in the About section of your profile.")
        }
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Badges")
            Button { store.profile.verified.toggle() } label: {
                HStack(spacing: 14) {
                    Image(systemName: store.profile.verified ? "checkmark.square.fill" : "square")
                        .font(.builder(22)).foregroundStyle(store.profile.verified ? Color.bloxBlue : Color(white: 0.6))
                    Text("Verified (shown first, right after your name)").font(.builder(16)).multilineTextAlignment(.leading)
                }
            }
            .accessibilityIdentifier("verifiedToggle")
            HStack(spacing: 12) {
                ForEach(Badge.allCases, id: \.self) { b in
                    let on = store.profile.badge == b
                    Button { store.profile.badge = b } label: {
                        Text(b == .none ? "No badge" : b.rawValue.capitalized).font(.builder(16, .semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(on ? Color.bloxBlue : Color.field, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .accessibilityIdentifier("badge-\(b.rawValue)")
                }
            }
        }
        .padding(.top, 8)
    }

    private var picture: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Profile picture")
            caption("Drag and zoom the avatar to choose what the round picture shows everywhere.")
            Button { cropping = true } label: { grayButton("Adjust profile picture") }
                .accessibilityIdentifier("adjustPicture")
        }
        .padding(.top, 8)
    }

    private var avatarSource: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Avatar")
            caption("Copy the look of any Roblox user: their avatar picture and what they're wearing. Your name, Robux, counts and badges stay as they are.")
            HStack(spacing: 12) {
                TextField("Roblox username", text: $copyName).field()
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                    .onSubmit(copy)
                    .accessibilityIdentifier("copyUserField")
                Button(action: copy) {
                    Group { if copying { ProgressView().tint(.white) } else { Text("Copy") } }
                        .font(.builder(16, .semibold)).frame(width: 76, height: 40)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                }
                .disabled(copying || copyName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("copyButton")
            }
            if !copyStatus.isEmpty { caption(copyStatus).accessibilityIdentifier("copyStatus") }
            PhotosPicker(selection: $photo, matching: .images) { grayButton("Choose a picture from Photos") }
            if !photoStatus.isEmpty { caption(photoStatus).accessibilityIdentifier("photoStatus") }
        }
        .padding(.top, 8)
    }

    private var friendsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Friends on Home")
            caption("Add real Roblox users by username. They show in the friends row on Home and in Chat.")
            HStack(spacing: 12) {
                TextField("Roblox username", text: $friendName).field()
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                    .onSubmit(addFriend)
                    .accessibilityIdentifier("friendUserField")
                Button(action: addFriend) {
                    Group { if addingFriend { ProgressView().tint(.white) } else { Text("Add") } }
                        .font(.builder(16, .semibold)).frame(width: 76, height: 40)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                }
                .disabled(addingFriend || friendName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("addFriendButton")
            }
            if !friendStatus.isEmpty { caption(friendStatus).accessibilityIdentifier("friendStatus") }
            ForEach($store.profile.friendList) { $f in
                HStack(spacing: 10) {
                    RemoteCircle(url: f.headshot, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $f.displayName).font(.builder(16, .semibold))
                        TextField("Status line (the game they're in)", text: $f.status).font(.builder(14))
                    }
                    Toggle("", isOn: $f.online).labelsHidden().tint(.green)
                    Button { store.profile.removeFriend(f.id) } label: {
                        Image(systemName: "trash").foregroundStyle(Color.faint)
                    }
                    .accessibilityLabel("Remove \(f.displayName)")
                }
                .padding(10).background(Color.field, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("friendRow")
            }
        }
        .padding(.top, 8)
    }

    private var menuCounts: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Badges on Home and the menu")
            HStack(spacing: 10) {
                labelled("Bell") { NumberField(value: $store.profile.notifications, id: "notificationsField") }
                labelled("Add Friends") { NumberField(value: $store.profile.requests, id: "requestsField") }
            }
            HStack(spacing: 10) {
                labelled("Menu: Friends") { NumberField(value: $store.profile.friendsBadge, id: "friendsBadgeField") }
                labelled("Menu: Messages") { NumberField(value: $store.profile.messages, id: "messagesField") }
            }
        }
        .padding(.top, 8)
    }

    private func addFriend() {
        let name = friendName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !addingFriend else { return }
        hideKeyboard()
        addingFriend = true
        friendStatus = ""
        Task {
            do {
                friendStatus = try await store.addFriend(name) ? "Added \(name)." : "\(name) is already in your friends."
                friendName = ""
            } catch {
                friendStatus = error.localizedDescription
            }
            addingFriend = false
        }
    }

    private var gamesLink: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("More to set up")
            NavigationLink { GamesView() } label: {
                grayButton("Games on your profile (\(store.profile.games.count))")
            }
            .accessibilityIdentifier("manageGames")
            NavigationLink { LedgerEditor() } label: { grayButton("Robux & transactions") }
                .accessibilityIdentifier("manageLedger")
            NavigationLink { NoticesEditor() } label: { grayButton("Notifications (\(store.profile.notices.count))") }
                .accessibilityIdentifier("manageNotices")
            NavigationLink { TradesEditor() } label: { grayButton("Trades (\(store.profile.trades.count))") }
                .accessibilityIdentifier("manageTrades")
            caption("Chats are written in the Chat tab itself: open a friend and type. The left button sends as them.")
        }
        .padding(.top, 8)
    }

    private func copy() {
        let name = copyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !copying else { return }
        hideKeyboard()
        copying = true
        copyStatus = ""
        Task {
            do {
                try await store.copyAvatar(from: name)
                copyStatus = "Copied \(name)'s avatar and \(store.profile.wearing.count) worn items."
            } catch {
                copyStatus = error.localizedDescription
            }
            copying = false
        }
    }

    private func heading(_ s: String) -> some View { Text(s).font(.builder(17, .bold)).padding(.top, 8) }
    private func caption(_ s: String) -> some View { Text(s).font(.builder(14)).foregroundStyle(Color.faint) }

    private func labelled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.builder(14)).foregroundStyle(Color.faint).lineLimit(1)
            content()
        }
    }

    private func grayButton(_ s: String) -> some View {
        Text(s).font(.builder(15, .semibold)).padding(.horizontal, 16).frame(minHeight: 40)
            .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
