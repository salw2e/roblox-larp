import SwiftUI
import BloxKit

@MainActor
final class Store: ObservableObject {
    @Published var profile: Profile { didSet { if profile != oldValue { scheduleSave() } } }
    @Published private(set) var avatar: UIImage?
    @Published private(set) var modelVersion = 0
    @Published private(set) var drawing = false
    @Published var drawNote = ""                     // what came of the last drawing ("2 more this hour", or why not)
    @Published private(set) var saveProblem = ""
    @Published private(set) var undone: [[String]] = []
    @Published private(set) var redone: [[String]] = []

    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let profileFile = dir.appendingPathComponent("profile.json")
    static let avatarFile = dir.appendingPathComponent("avatar.png")
    private var pendingSave: DispatchWorkItem?

    init() {
        var loaded = Profile()
        var problem = ""
        if let data = try? Data(contentsOf: Self.profileFile) {
            if let p = Profile.load(data) {
                loaded = p
            } else {
                let aside = Self.dir.appendingPathComponent("profile.unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: Self.profileFile, to: aside)
                problem = "Your saved profile couldn't be read, so the app started fresh. The old file was kept as \(aside.lastPathComponent)."
            }
        }
        profile = loaded
        saveProblem = problem
        avatar = UIImage(contentsOfFile: Self.avatarFile.path)
        if ModelFiles.exists {
            Task {
                if await AvatarScene.prepare() { modelVersion = 1 }
            }
        }
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: profileFile)
        try? FileManager.default.removeItem(at: avatarFile)
        ModelFiles.wipe()
    }

    // MARK: Saving

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try JSONEncoder().encode(profile).write(to: Self.profileFile, options: .atomic)
            if saveProblem.hasPrefix("Couldn't save") { saveProblem = "" }
        } catch {
            saveProblem = "Couldn't save your changes: \(error.localizedDescription)"
        }
    }

    // MARK: Wearing, with undo

    private var worn: [String] { profile.wearing.map(\.key) }

    func wear(_ item: Item, _ on: Bool) {
        let before = worn
        profile.wear(item, on)
        if worn != before {
            undone.append(before)
            redone = []
            drawSoon()
        }
    }

    func undo() {
        guard let keys = undone.popLast() else { return }
        redone.append(worn)
        setWorn(keys)
        drawSoon()
    }

    func redo() {
        guard let keys = redone.popLast() else { return }
        undone.append(worn)
        setWorn(keys)
        drawSoon()
    }

    func setBody(_ definition: String) {
        guard definition != profile.definition else { return }
        profile.definition = definition
        drawSoon()
    }

    func wear(outfit: Outfit) {
        let before = worn
        setWorn(outfit.keys)
        if worn != before {
            undone.append(before)
            redone = []
            drawSoon()
        }
    }

    // MARK: Drawing on its own

    private var autoDraw: Task<Void, Never>?
    private static let drawsOnItsOwn = !ProcessInfo.processInfo.arguments.contains("-uitest")
        || ProcessInfo.processInfo.arguments.contains("-autodraw")

    private func drawSoon(after seconds: Double = 1.5, tries: Int = 0) {
        guard Self.drawsOnItsOwn else { return }
        autoDraw?.cancel()
        autoDraw = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled, self.profile.needsRedraw, self.modelVersion > 0 else { return }
            if self.drawing { return self.drawSoon(after: 2, tries: tries) }
            if let b = await Roblox.budget(), let left = b.left, left < 2, b.resetIn > 0 {
                guard !Task.isCancelled else { return }
                self.drawNote = "Your avatar updates in \(max(1, (b.resetIn + 59) / 60)) min"
                return self.drawSoon(after: Double(b.resetIn) + 3, tries: tries)
            }
            guard !Task.isCancelled else { return }
            let drew = await self.redraw()
            if !drew, tries < 4 { self.drawSoon(after: 60, tries: tries + 1) }        // busy or offline: try again
            else if drew, self.profile.needsRedraw { self.drawSoon() }                // changed again while drawing
        }
    }

    func saveOutfit(named name: String) {
        let outfit = profile.saveOutfit(named: name)
        if let png = avatar?.pngData() { try? png.write(to: Self.outfitPicture(outfit.id), options: .atomic) }
    }

    func deleteOutfit(_ outfit: Outfit) {
        profile.outfits.removeAll { $0.id == outfit.id }
        try? FileManager.default.removeItem(at: Self.outfitPicture(outfit.id))
    }

    static func outfitPicture(_ id: Int) -> URL { dir.appendingPathComponent("outfit-\(id).png") }

    func fillKinds() async {
        let missing = profile.items.filter { $0.kind == nil && !$0.bundle }.map(\.id)
        for chunk in stride(from: 0, to: missing.count, by: 5).map({ Array(missing[$0..<min($0 + 5, missing.count)]) }) {
            let found = await withTaskGroup(of: (Int64, Int?).self) { group in
                for id in chunk {
                    group.addTask { (id, await Roblox.kind(of: id)) }
                }
                var all: [Int64: Int] = [:]
                for await (id, kind) in group { if let kind { all[id] = kind } }
                return all
            }
            for i in profile.items.indices where !profile.items[i].bundle && profile.items[i].kind == nil {
                profile.items[i].kind = found[profile.items[i].id]
            }
        }
    }

    private func setWorn(_ keys: [String]) {
        for i in profile.items.indices { profile.items[i].wearing = keys.contains(profile.items[i].key) }
    }

    // MARK: Avatar

    @discardableResult
    func setAvatar(_ data: Data) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        try? data.write(to: Self.avatarFile, options: .atomic)
        avatar = image
        return true
    }

    func usePhoto(_ data: Data) -> Bool {
        guard let picked = UIImage(data: data) else { return false }
        let longest = max(picked.size.width, picked.size.height)
        let scale = min(1, 1024 / max(longest, 1))
        let size = CGSize(width: picked.size.width * scale, height: picked.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in picked.draw(in: CGRect(origin: .zero, size: size)) }
        guard let png = small.pngData() else { return false }
        try? png.write(to: Self.avatarFile, options: .atomic)
        avatar = small
        ModelFiles.wipe()
        AvatarScene.forget()
        modelVersion = 0
        profile.crop = Crop(scale: 1.4, x: 0, y: 0)
        return true
    }

    func copyAvatar(from username: String) async throws {
        guard !drawing else { throw BloxError.said("The avatar is still being drawn. Try again in a moment.") }
        drawing = true
        defer { drawing = false }
        let user = try await Roblox.user(username)
        async let asked = Roblox.look(lookRequest(user: user.name))
        async let worn = Roblox.wearing(user.id)
        let (look, items) = try await (asked, worn)
        try await install(look)
        profile.definition = look.definition
        profile.adopt(copiedItems: items)
        profile.drawn = drawSignature(profile.items, profile.definition)
        undone = []
        redone = []
    }

    @discardableResult
    func redraw() async -> Bool {
        guard !drawing else { return false }
        drawing = true
        drawNote = ""
        defer { drawing = false }
        let wear = profile.wearing, body = profile.definition, asked = drawSignature(profile.items, profile.definition)
        do {
            let look = try await Roblox.look(lookRequest(definition: body, wear: wear))
            try await install(look)
            if Build.key(profile.definition) == Build.key(body) { profile.definition = look.definition }
            profile.drawn = asked
            return true
        } catch {
            note(error.localizedDescription)
            return false
        }
    }

    private func note(_ text: String) {
        drawNote = text
        guard !text.isEmpty else { return }
        Task {
            try? await Task.sleep(for: .seconds(12))
            if drawNote == text { drawNote = "" }
        }
    }

    private func install(_ look: Look) async throws {
        var picture: Data?
        if let link = look.image, let url = URL(string: link), !Self.photographs {
            let data = try await Roblox.fetch(url)
            guard UIImage(data: data) != nil else { throw BloxError.noPicture }
            picture = data
        }
        try await ModelFiles.install(look)
        if let picture {
            setAvatar(picture)
        } else if let photo = AvatarScene.snapshot()?.pngData() {
            setAvatar(photo)
        } else {
            note("The round picture couldn't be redrawn, so it still shows the old look.")
        }
        modelVersion += 1
    }

    private static var photographs: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-photograph-avatar")
        #else
        return false
        #endif
    }

    func addFriend(_ username: String) async throws -> Bool {
        let person = try await Roblox.person(username)
        if let i = profile.friendList.firstIndex(where: { $0.id == person.id }) {
            profile.friendList[i].headshot = person.headshot
            return false
        }
        profile.friendList.append(person)
        return true
    }

    // MARK: Keeping saved things fresh

    func refreshSaved() async {
        let games = profile.games + profile.experiences
        if !games.isEmpty, let now = await Roblox.playing(games.map(\.id)) {
            for i in profile.games.indices { profile.games[i].playing = now[profile.games[i].id] ?? profile.games[i].playing }
            for i in profile.experiences.indices { profile.experiences[i].playing = now[profile.experiences[i].id] ?? profile.experiences[i].playing }
        }
        guard Date().timeIntervalSince1970 - (profile.picturesAt ?? 0) > 7 * 86400 else { return }
        let tradeItems = profile.trades.flatMap { $0.giving + $0.receiving }
        let people = Array(Set(profile.friendList.map(\.id) + profile.trades.map(\.partner.id)))
        async let itemsFetched = Roblox.withThumbs(profile.items + tradeItems)
        async let facesFetched = Roblox.headshots(people)
        async let picturesFetched = Roblox.gamePictures(games.map(\.id))
        let (items, faces, pictures) = await (itemsFetched, facesFetched, picturesFetched)
        let thumbs = Dictionary(items.compactMap { i in i.thumb.map { (i.key, $0) } }, uniquingKeysWith: { a, _ in a })
        func renewItems(_ list: inout [Item]) { for i in list.indices { list[i].thumb = thumbs[list[i].key] ?? list[i].thumb } }
        func renewGames(_ list: inout [Game]) {
            for i in list.indices {
                list[i].icon = pictures.icons[list[i].id] ?? list[i].icon
                list[i].wide = pictures.wide[list[i].id] ?? list[i].wide
            }
        }
        var p = profile
        renewItems(&p.items)
        renewGames(&p.games)
        renewGames(&p.experiences)
        for i in p.friendList.indices { p.friendList[i].headshot = faces[p.friendList[i].id] ?? p.friendList[i].headshot }
        for i in p.trades.indices {
            renewItems(&p.trades[i].giving)
            renewItems(&p.trades[i].receiving)
            p.trades[i].partner.headshot = faces[p.trades[i].partner.id] ?? p.trades[i].partner.headshot
        }
        let nothingToRenew = p.items.isEmpty && people.isEmpty && games.isEmpty
        if !thumbs.isEmpty || !faces.isEmpty || !pictures.icons.isEmpty || nothingToRenew {
            p.picturesAt = Date().timeIntervalSince1970
        }
        profile = p
    }
}
