import SwiftUI
import SalBloxKit
import PhotosUI

struct CropView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var dragStart: Crop?
    @State private var pinchStart: Crop?
    private let size: CGFloat = 280

    var body: some View {
        VStack(spacing: 28) {
            Text("Adjust profile picture").font(.builder(26, .bold)).padding(.top, 30)
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
            .font(.builder(20, .semibold))
            .padding(.horizontal, 22)
            Spacer()
        }
        .presentationDetents([.large])
    }

    private var drag: some Gesture {
        DragGesture().onChanged { g in
            let s = dragStart ?? store.profile.crop
            dragStart = s
            store.profile.crop = Crop(scale: store.profile.crop.scale, x: s.x + g.translation.width / size, y: s.y + g.translation.height / size).clamped
        }
        .onEnded { _ in dragStart = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture().onChanged { g in
            let s = pinchStart ?? store.profile.crop
            pinchStart = s
            store.profile.crop = Crop(scale: s.scale * g.magnification, x: store.profile.crop.x, y: store.profile.crop.y).clamped
        }
        .onEnded { _ in pinchStart = nil }
    }
}
