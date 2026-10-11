import SwiftUI
import BloxKit

@MainActor
final class Store: ObservableObject {
    @Published var profile: Profile { didSet { save() } }
    @Published private(set) var avatar: UIImage?
    @Published private(set) var modelVersion = 0
    @Published private(set) var drawing = false      // Roblox is drawing a new outfit
    @Published var drawNote = ""                     // what came of the last drawing ("2 more this hour", or why not)

    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let profileFile = dir.appendingPathComponent("profile.json")
    static let avatarFile = dir.appendingPathComponent("avatar.png")

    init() {
        profile = (try? Data(contentsOf: Self.profileFile)).flatMap(Profile.load) ?? Profile()
        avatar = UIImage(contentsOfFile: Self.avatarFile.path)
        modelVersion = ModelFiles.exists ? 1 : 0
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: profileFile)
        try? FileManager.default.removeItem(at: avatarFile)
        ModelFiles.wipe()
    }

    private func save() {
        try? JSONEncoder().encode(profile).write(to: Self.profileFile, options: .atomic)
    }

    @discardableResult
    func setAvatar(_ data: Data) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        try? data.write(to: Self.avatarFile, options: .atomic)
        avatar = image
        return true
    }

    func copyAvatar(from username: String) async throws {
        let user = try await Roblox.user(username)
        async let asked = Roblox.look(lookRequest(user: user.name))
        async let worn = Roblox.wearing(user.id)
        let (look, items) = try await (asked, worn)
        try await install(look)
        profile.definition = look.definition
        for i in profile.items.indices { profile.items[i].wearing = false }
        for item in items { profile.wear(item) }
        profile.drawn = wearSignature(profile.items)
    }

    func redraw() async {
        guard !drawing else { return }
        drawing = true
        drawNote = ""
        do {
            let look = try await Roblox.look(lookRequest(definition: profile.definition, wear: profile.wearing))
            try await install(look)
            profile.definition = look.definition
            profile.drawn = wearSignature(profile.items)
            drawNote = look.drawingsLeft.map { "\($0) more this hour" } ?? ""
        } catch {
            drawNote = error.localizedDescription
        }
        drawing = false
    }

    private func install(_ look: Look) async throws {
        try await ModelFiles.install(look)
        let photographed = ProcessInfo.processInfo.arguments.contains("-photograph-avatar")   // UI tests check the photo path
        if let link = look.image, let url = URL(string: link), !photographed {
            guard setAvatar(try await Roblox.fetch(url)) else { throw BloxError.noPicture }
        } else if let photo = AvatarScene.snapshot()?.pngData() {
            setAvatar(photo)
        }
        modelVersion += 1
    }

    func addFriend(_ username: String) async throws {
        let user = try await Roblox.user(username)
        let face = try? await Roblox.headshot(user.id)
        if let i = profile.friendList.firstIndex(where: { $0.id == user.id }) { profile.friendList[i].headshot = face; return }
        profile.friendList.append(Friend(id: user.id, name: user.name, displayName: user.displayName, headshot: face))
    }
}
