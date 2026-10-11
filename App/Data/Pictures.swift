import SwiftUI
import SalBloxKit

actor Pictures {
    static let shared = Pictures()
    static let kept: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()
    private var loading: [String: Task<UIImage?, Never>] = [:]

    func image(_ link: String) async -> UIImage? {
        if let have = Self.kept.object(forKey: link as NSString) { return have }
        if let running = loading[link] { return await running.value }
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: link) else { return nil }
            for attempt in 0..<2 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(1.5)) }
                if let reply = try? await URLSession.shared.data(from: url), (reply.1 as? HTTPURLResponse)?.statusCode == 200,
                   let image = UIImage(data: reply.0) {
                    return image
                }
            }
            return nil
        }
        loading[link] = task
        let image = await task.value
        loading[link] = nil
        if let image { Self.kept.setObject(image, forKey: link as NSString) }
        return image
    }
}
