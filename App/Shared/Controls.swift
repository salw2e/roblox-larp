import SwiftUI
import SalBloxKit

struct WideButton: View {
    let title: String
    var main = true
    var icon: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Icon(icon, size: 20, filled: true) }
                Text(title).font(.builder(16, .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(main ? Color.bloxBlue : Color.tile, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(main ? .white : Color.ink)
        }
        .buttonStyle(PressStyle())
    }
}

struct RobuxAmount: View {
    let amount: Int
    var size: CGFloat = 14.5
    var weight: Font.Weight = .regular
    var body: some View {
        HStack(spacing: 4) {
            Icon("robux", size: size * 1.15)
            Text(grouped(amount)).font(.builder(size, weight))
        }
    }
}

// MARK: - Robux

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.builder(18)).padding(.horizontal, 12).frame(minHeight: 40)
            .background(Color.field, in: RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func field() -> some View { modifier(FieldStyle()) }
}

struct NumberField: View {
    @Binding var value: Int
    let id: String
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad)
            .field()
            .accessibilityIdentifier(id)
            .onAppear { text = value == 0 ? "" : "\(value)" }   // empty at 0, so typing doesn't give "011"
            .onChange(of: text) { _, t in
                let kept = digits(in: t)
                if kept != t { text = kept }
                value = number(from: kept)
            }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
