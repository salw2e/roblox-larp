import SwiftUI
import PhotosUI
import BloxKit

struct EditProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var cropping = false
    @State private var copyName = ""
    @State private var copying = false
    @State private var copyStatus = ""
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    account
                    counts
                    bio
                    badges
                    picture
                    avatarSource
                    gamesLink
                }
                .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { titleBar }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } }
            }
        }
        .sheet(isPresented: $cropping) { CropView() }
        .onChange(of: photo) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    copyStatus = store.setAvatar(data) ? "Picture set from Photos." : "That file isn't a picture."
                }
            }
        }
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit — Profile").font(.system(size: 30, weight: .bold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 24, weight: .medium)) }
                    .accessibilityIdentifier("closeEdit")
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            Divider()
        }
        .background(.white)
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Account")
            HStack(spacing: 16) {
                labelled("Username") { TextField("", text: $store.profile.username).field().accessibilityIdentifier("usernameField") }
                labelled("Display name") { TextField("", text: $store.profile.displayName).field().accessibilityIdentifier("displayNameField") }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            labelled("Robux") { NumberField(value: $store.profile.robux, id: "robuxField") }
        }
    }

    private var counts: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Friends, followers & following")
            HStack(spacing: 16) {
                labelled("Friends") { NumberField(value: $store.profile.friends, id: "friendsField") }
                labelled("Followers") { NumberField(value: $store.profile.followers, id: "followersField") }
                labelled("Following") { NumberField(value: $store.profile.following, id: "followingField") }
            }
        }
    }

    private var bio: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Bio")
            labelled("About (up to 1,000 characters)") {
                TextEditor(text: $store.profile.bio)
                    .font(.system(size: 22)).scrollContentBackground(.hidden)
                    .padding(14).frame(height: 190)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("bioField")
                    .onChange(of: store.profile.bio) { _, b in if b.count > 1000 { store.profile.bio = String(b.prefix(1000)) } }
            }
            caption("Shown in the About section of your profile.")
        }
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Badges")
            Button { store.profile.verified.toggle() } label: {
                HStack(spacing: 14) {
                    Image(systemName: store.profile.verified ? "checkmark.square.fill" : "square")
                        .font(.system(size: 30)).foregroundStyle(store.profile.verified ? Color.bloxBlue : Color(white: 0.6))
                    Text("Verified (shown first, right after your name)").font(.system(size: 20)).multilineTextAlignment(.leading)
                }
            }
            .accessibilityIdentifier("verifiedToggle")
            HStack(spacing: 12) {
                ForEach(Badge.allCases, id: \.self) { b in
                    let on = store.profile.badge == b
                    Button { store.profile.badge = b } label: {
                        Text(b == .none ? "No badge" : b.rawValue.capitalized).font(.system(size: 21, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(on ? Color.bloxBlue : Color.field, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .accessibilityIdentifier("badge-\(b.rawValue)")
                }
            }
        }
        .padding(.top, 8)
    }

    private var picture: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Profile picture")
            caption("Drag and zoom the avatar to choose what the round picture shows everywhere.")
            Button { cropping = true } label: { grayButton("Adjust profile picture") }
                .accessibilityIdentifier("adjustPicture")
        }
        .padding(.top, 8)
    }

    private var avatarSource: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Avatar")
            caption("Copy the look of any Roblox user: their avatar picture and what they're wearing. Your name, Robux, counts and badges stay as they are.")
            HStack(spacing: 12) {
                TextField("Roblox username", text: $copyName).field()
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                    .onSubmit(copy)
                    .accessibilityIdentifier("copyUserField")
                Button(action: copy) {
                    Group { if copying { ProgressView().tint(.white) } else { Text("Copy") } }
                        .font(.system(size: 20, weight: .semibold)).frame(width: 96, height: 66)
                        .background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white)
                }
                .disabled(copying || copyName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("copyButton")
            }
            if !copyStatus.isEmpty { caption(copyStatus).accessibilityIdentifier("copyStatus") }
            PhotosPicker(selection: $photo, matching: .images) { grayButton("Choose a picture from Photos") }
        }
        .padding(.top, 8)
    }

    private var gamesLink: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Games")
            NavigationLink { GamesView() } label: {
                grayButton("Games on your profile (\(store.profile.games.count))")
            }
            .accessibilityIdentifier("manageGames")
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

    private func heading(_ s: String) -> some View { Text(s).font(.system(size: 26, weight: .bold)).padding(.top, 10) }
    private func caption(_ s: String) -> some View { Text(s).font(.system(size: 19)).foregroundStyle(Color.faint) }

    private func labelled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.system(size: 19)).foregroundStyle(Color.faint).lineLimit(1)
            content()
        }
    }

    private func grayButton(_ s: String) -> some View {
        Text(s).font(.system(size: 20, weight: .semibold)).padding(.horizontal, 24).frame(minHeight: 60)
            .background(Color.field, in: RoundedRectangle(cornerRadius: 14))
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct CropView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var dragStart: Crop?
    @State private var pinchStart: Crop?
    private let size: CGFloat = 280

    var body: some View {
        VStack(spacing: 28) {
            Text("Adjust profile picture").font(.system(size: 26, weight: .bold)).padding(.top, 30)
            Headshot(image: store.avatar, crop: store.profile.crop, size: size)
                .overlay(Circle().stroke(Color(white: 0.8), lineWidth: 2))
                .contentShape(Circle())
                .gesture(drag.simultaneously(with: pinch))
                .accessibilityIdentifier("cropCircle")
            Text("Drag to move, pinch to zoom.").foregroundStyle(Color.faint)
            HStack(spacing: 12) {
                Button("Reset") { store.profile.crop = Crop() }
                    .frame(maxWidth: .infinity, minHeight: 56).background(Color.field, in: RoundedRectangle(cornerRadius: 14))
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 56).background(Color.bloxBlue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white).accessibilityIdentifier("cropDone")
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 22)
            Spacer()
        }
        .presentationDetents([.large])
    }

    private var drag: some Gesture {
        DragGesture().onChanged { g in
            let s = dragStart ?? store.profile.crop
            dragStart = s
            store.profile.crop.x = s.x + g.translation.width / size
            store.profile.crop.y = s.y + g.translation.height / size
        }
        .onEnded { _ in dragStart = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture().onChanged { g in
            let s = pinchStart ?? store.profile.crop
            pinchStart = s
            store.profile.crop.scale = min(max(s.scale * g.magnification, 0.8), 8)
        }
        .onEnded { _ in pinchStart = nil }
    }
}
