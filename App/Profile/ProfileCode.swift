import SwiftUI
import SalBloxKit
import CoreImage.CIFilterBuiltins

struct ProfileCode: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 16) {
            Text("Share Profile").font(.builder(20, .bold)).padding(.top, 28)
            if let code = Self.code("https://www.roblox.com/users/profile?username=\(store.profile.shownUsername)") {
                Image(uiImage: code).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220)
                    .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("profileCodeImage").accessibilityLabel("QR code")
            }
            Text("@\(store.profile.shownUsername)").font(.builder(14.5)).foregroundStyle(Color.faint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .presentationBackground(Color.bg)
    }

    static func code(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
