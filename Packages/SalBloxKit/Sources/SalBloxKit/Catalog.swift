import Foundation

public struct Item: Codable, Identifiable, Hashable, Sendable {
    public var id: Int64
    public var bundle: Bool
    public var name: String
    public var creator: String
    public var price: Int?
    public var thumb: String?
    public var wearing: Bool
    public var creatorVerified: Bool?
    public var limited: Bool?
    public var copied: Bool?
    public var kind: Int?

    public static let background = 92
    public var isBackground: Bool { kind == Item.background }

    public init(id: Int64, bundle: Bool = false, name: String, creator: String = "Roblox", price: Int?,
                thumb: String? = nil, wearing: Bool = false, creatorVerified: Bool? = nil, limited: Bool? = nil, kind: Int? = nil) {
        self.id = id; self.bundle = bundle; self.name = name; self.creator = creator
        self.price = price; self.thumb = thumb; self.wearing = wearing; self.creatorVerified = creatorVerified
        self.limited = limited; self.kind = kind
    }

    public func same(_ other: Item) -> Bool { id == other.id && bundle == other.bundle }
    public var key: String { (bundle ? "b" : "") + "\(id)" }

    public var showsCreatorCheck: Bool { creatorVerified ?? (creator == "Roblox") }
}

public struct Outfit: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var keys: [String]
    public init(id: Int, name: String, keys: [String]) { self.id = id; self.name = name; self.keys = keys }
}

public enum Shelf: String, CaseIterable, Sendable {
    case avatars = "Avatars", body = "Body", clothing = "Clothing", accessories = "Accessories", backgrounds = "Backgrounds"
    case animations = "Animations"

    public static func of(_ item: Item) -> Shelf {
        if item.bundle { return .avatars }                      // whole avatars and body bundles
        switch item.kind ?? 0 {
        case 17, 18, 27...31, 41, 76...79: return .body
        case 2, 11, 12, 64...72: return .clothing
        case Item.background: return .backgrounds
        case 48...56, 61: return .animations                    // walk, run, jump... and emotes
        default: return .accessories
        }
    }

    public var slots: [Slot] { Slot.all.filter { $0.shelf == self } }
}

public struct Slot: Hashable, Sendable {
    public let name: String
    public let shelf: Shelf
    public let kinds: Set<Int>
    public let taxonomy: String

    public func holds(_ item: Item) -> Bool {
        guard !item.bundle else { return false }
        guard let kind = item.kind else { return shelf == .accessories && name == "Other" }
        return kinds.contains(kind)
    }

    public static let all: [Slot] = [
        Slot(name: "Full Body", shelf: .body, kinds: [27, 28, 29, 30, 31], taxonomy: "kfHzJwaNYM8s2CWRqYUhRa"),
        Slot(name: "Hair", shelf: .body, kinds: [41], taxonomy: "d6a7M7r9MMrpf7z7VxW9ZS"),
        Slot(name: "Head", shelf: .body, kinds: [17, 79, 18, 76, 77, 78], taxonomy: "s5NLP7BS9PRLKvUVca4XKg"),
        Slot(name: "Build", shelf: .body, kinds: [], taxonomy: ""),
        Slot(name: "Skin", shelf: .body, kinds: [], taxonomy: ""),       // its colour
        Slot(name: "Top", shelf: .clothing, kinds: [64, 65], taxonomy: "pJ71PxerdfEuarTNRtSZYs"),
        Slot(name: "Outerwear", shelf: .clothing, kinds: [67, 68], taxonomy: "kPZpEVNdProGcqMbj1jDKJ"),
        Slot(name: "Bottom", shelf: .clothing, kinds: [66, 69, 72], taxonomy: "1MvRtnnsy2FJWmkErSBxBa"),
        Slot(name: "Shoes", shelf: .clothing, kinds: [70, 71], taxonomy: "uLRgNoJ1awZkhpVw9WyvKo"),
        Slot(name: "Shirt Classic", shelf: .clothing, kinds: [11], taxonomy: "2a2rf9qyeTd8W5iegK2Prc"),
        Slot(name: "Pants Classic", shelf: .clothing, kinds: [12], taxonomy: "49cFNAJWuwiJJVUSADG6DR"),
        Slot(name: "T-Shirt Classic", shelf: .clothing, kinds: [2], taxonomy: "43H35nJKHzCQM63q3wPaJG"),
        Slot(name: "Head", shelf: .accessories, kinds: [8], taxonomy: "thukPQUFe5EHxRrtsgq43u"),
        Slot(name: "Face", shelf: .accessories, kinds: [42], taxonomy: "b5rkQhGSfwhfTK177y6ERa"),
        Slot(name: "Neck", shelf: .accessories, kinds: [43], taxonomy: "tvckLAbtDAGwF9Y2sph2Ce"),
        Slot(name: "Back", shelf: .accessories, kinds: [46], taxonomy: "7yGywzp5JeDsNjhXWJqSw3"),
        Slot(name: "Waist", shelf: .accessories, kinds: [47], taxonomy: "6jYQPDtkVwQZcKtvVpyYAN"),
        Slot(name: "Shoulder", shelf: .accessories, kinds: [44], taxonomy: "8i1sggNTrxoN799hpRrR1S"),
        Slot(name: "Front", shelf: .accessories, kinds: [45], taxonomy: "kj535RzJxHTCnXPBLo5KaE"),
        Slot(name: "Gear", shelf: .accessories, kinds: [19], taxonomy: "gUtxkR951g3VPgRkb5ay8u"),
        Slot(name: "Other", shelf: .accessories, kinds: [], taxonomy: "wNYJso48d1XnhMyFWT3oX3"),   // type not known (yet)
        Slot(name: "Emotes", shelf: .animations, kinds: [61], taxonomy: "ioNxAT977DFP2hMnAJbsbF"),
        Slot(name: "Animations", shelf: .animations, kinds: [48, 49, 50, 51, 52, 53, 54, 55, 56], taxonomy: "whf6kUVBwk2xdwKUmRYN6G"),
    ]
}

public struct ItemDetail: Equatable, Sendable {
    public var item: Item
    public var favorites: Int
    public var type: String
    public var description: String
    public var parts: [Item]
    public var bundleType: Int?

    public var placement: String {
        if item.bundle { return bundleType == 1 ? "Body | Full Body" : "Avatars" }
        let shelf = Shelf.of(item)
        guard let slot = shelf.slots.first(where: { $0.holds(item) }), slot.name != "Other" else { return shelf.rawValue }
        return "\(shelf.rawValue) | \(slot.name)"
    }
}

public struct ItemInfo: Equatable, Sendable {
    public var description: String
    public var type: String
    public var limited: Bool
    public var created: String
}
