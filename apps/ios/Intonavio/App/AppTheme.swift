import SwiftUI

/// Theme is locked to dark mode (Split Spectrum design language).
enum AppTheme: Int, CaseIterable {
    case dark = 2

    var label: String { "Dark" }

    var colorScheme: ColorScheme { .dark }
}
