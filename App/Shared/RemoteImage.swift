import SwiftUI
import SalBloxKit

struct RemoteCircle: View {
    let url: String?
    let size: CGFloat
    var body: some View {
        Circle().fill(Color.tile)
            .overlay {
                Icon("person", size: size * 0.5, filled: true).foregroundStyle(Color.faint)
                RemoteImage(url: url, fill: true)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

struct RemoteImage: View {
    let url: String?
    let fill: Bool
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        let shown = image ?? url.flatMap { Pictures.kept.object(forKey: $0 as NSString) }
        ZStack {
            if let shown {
                Image(uiImage: shown).resizable().aspectRatio(contentMode: fill ? .fill : .fit).transition(.opacity)
            } else if url != nil, !failed {
                Shimmer()
            }
        }
        .task(id: url) {
            guard let url else { return }
            failed = false
            let loaded = await Pictures.shared.image(url)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            failed = loaded == nil
        }
    }
}

struct Shimmer: View {
    static var animated: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return true
        #endif
    }
    @State private var moved = false

    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, Color.white.opacity(0.09), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.7)
                .offset(x: moved ? g.size.width : -g.size.width * 0.7)
        }
        .clipped()
        .onAppear {
            guard Self.animated else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { moved = true }
        }
    }
}
