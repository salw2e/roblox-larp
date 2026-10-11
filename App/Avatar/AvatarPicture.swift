import SwiftUI
import SalBloxKit

struct AvatarPicture: View {
    let image: UIImage?
    var body: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("avatarImage")
        } else {
            Icon("person-standing", size: 150).foregroundStyle(Color(white: 0.3)).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct Headshot: View {
    let image: UIImage?
    let crop: Crop
    let size: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.32), Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: size * crop.clamped.scale, height: size * crop.clamped.scale)
                    .offset(x: crop.clamped.x * size, y: crop.clamped.y * size)
            } else {
                Icon("person", size: size * 0.6, filled: true).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct BackdropPicture: View {
    @EnvironmentObject var store: Store
    @State private var sharp: [Int64: String] = [:]
    var body: some View {
        if let item = store.profile.backdrop {
            Color.clear
                .overlay { RemoteImage(url: sharp[item.id] ?? item.thumb, fill: true) }
                .clipped()
                .allowsHitTesting(false)
                .task(id: item.id) { if sharp[item.id] == nil, let url = await Roblox.bigThumb(item) { sharp[item.id] = url } }
        }
    }
}
