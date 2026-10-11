import SwiftUI
import SalBloxKit

struct MomentsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Icon("moments", size: 60)
            Text("Moments").font(.builder(22, .bold))
            Text("Short clips from experiences show up here.").font(.builder(14.5)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}
