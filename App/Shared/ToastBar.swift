import SwiftUI

struct ToastBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack {
            if let text = store.toast {
                HStack(spacing: 10) {
                    Icon("circle-check", size: 22, filled: true)
                    Text(text).font(.builder(15, .medium)).lineLimit(1).accessibilityIdentifier("toastText")
                    Spacer(minLength: 8)
                    Button { store.toast = nil } label: { Icon("x", size: 18).frame(width: 30, height: 30) }
                        .accessibilityIdentifier("toastClose").accessibilityLabel("Close")
                }
                .foregroundStyle(Color.rgb(25, 26, 31))
                .padding(.leading, 14).padding(.trailing, 8).frame(height: 48)
                .background(Color.rgb(247, 247, 248), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16).padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: store.toast)
        .allowsHitTesting(store.toast != nil)
    }
}
