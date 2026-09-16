import SwiftUI

enum GraminTheme {
    static let radius: CGFloat = 24
    static let smallRadius: CGFloat = 16
    static let shadow = Color.black.opacity(0.08)
    static let chartPalette: [Color] = [.primary, .primary.opacity(0.78), .primary.opacity(0.58), .primary.opacity(0.42), .primary.opacity(0.28)]
}

struct GraminCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: GraminTheme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GraminTheme.radius, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: GraminTheme.shadow, radius: 18, y: 8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color(.systemBackground))
            .background(.primary.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct AmountText: View {
    let amount: Double
    let currency: String
    var body: some View {
        Text(amount, format: .currency(code: currency).presentation(.narrow).precision(.fractionLength(2)))
            .contentTransition(.numericText(value: amount))
    }
}

extension View {
    func graminBackground() -> some View {
        scrollContentBackground(.hidden).background(Color(.systemGroupedBackground))
    }
}
