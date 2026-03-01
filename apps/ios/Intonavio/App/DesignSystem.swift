import SwiftUI

// MARK: - Split Spectrum Color Palette

extension Color {
    /// Deep Charcoal — primary backgrounds.
    static let intonavioBackground = Color(hex: 0x0E0F12)

    /// Lighter Charcoal — cards, surfaces, secondary panels.
    static let intonavioSurface = Color(hex: 0x1C1E24)

    /// Magenta — gradient start, branding.
    static let intonavioMagenta = Color(hex: 0xD946EF)

    /// Amber — gradient end, branding.
    static let intonavioAmber = Color(hex: 0xF59E0B)

    /// Ice — functional accent: playheads, selected states, icons.
    static let intonavioIce = Color(hex: 0xE6F6FF)

    /// Primary text — white on dark backgrounds.
    static let intonavioTextPrimary = Color.white

    /// Secondary text — muted labels and metadata.
    static let intonavioTextSecondary = Color(hex: 0xA1A1AA)

    /// Hex initializer (0xRRGGBB).
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Gradient

extension LinearGradient {
    /// Magenta → Amber brand gradient (leading → trailing).
    static let intonavio = LinearGradient(
        colors: [.intonavioMagenta, .intonavioAmber],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Button Styles

/// Gradient capsule CTA button (Sign In, Add Song, Try Again).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule().fill(LinearGradient.intonavio)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Ice border capsule button for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.intonavioIce)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .strokeBorder(Color.intonavioIce.opacity(0.5), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
