import SwiftUI

extension Color {
    /// Primary background: iOS `.systemBackground`, macOS `.windowBackgroundColor`.
    static var platformBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Grouped content background: iOS `.systemGroupedBackground`, macOS `.controlBackgroundColor`.
    static var platformGroupedBackground: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Tertiary fill: iOS `.tertiarySystemFill`, macOS `.controlColor`.
    static var platformTertiaryFill: Color {
        #if os(iOS)
        Color(.tertiarySystemFill)
        #else
        Color(nsColor: .controlColor)
        #endif
    }
}
