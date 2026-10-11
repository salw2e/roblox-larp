import SwiftUI
import BloxKit

@MainActor
final class Store: ObservableObject {
    @Published var profile: Profile { didSet { save() } }
    @Published private(set) var avatar: UIImage?

    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let profileFile = dir.appendingPathComponent("profile.json")
    static let avatarFile = dir.appendingPathComponent("avatar.png")

    init() {
        profile = (try? Data(contentsOf: Self.profileFile)).flatMap { try? JSONDecoder().decode(Profile.self, from: $0) } ?? Profile()
        avatar = UIImage(contentsOfFile: Self.avatarFile.path)
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: profileFile)
        try? FileManager.default.removeItem(at: avatarFile)
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
        async let png = Roblox.avatarPNG(user.id)
        async let worn = Roblox.wearing(user.id)
        let (picture, items) = try await (png, worn)
        guard setAvatar(picture) else { throw BloxError.noPicture }
        for i in profile.items.indices { profile.items[i].wearing = false }
        for item in items { profile.wear(item) }
    }
}
