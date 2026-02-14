import SwiftUI

#if os(macOS)
// MARK: - Stub Types for iOS-only APIs

/// Stub so `.navigationBarTitleDisplayMode(.inline)` compiles on macOS.
enum NavigationBarTitleDisplayMode {
    case automatic, inline, large
}

/// Stub so `.keyboardType(.emailAddress)` compiles on macOS.
enum UIKeyboardType {
    case `default`, emailAddress, numberPad, URL, phonePad
}

/// Stub so `.textInputAutocapitalization(.never)` compiles on macOS.
enum TextInputAutocapitalization {
    case never, words, sentences, characters
}

// MARK: - No-Op View Extensions

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }

    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    func textInputAutocapitalization(_ mode: TextInputAutocapitalization?) -> some View {
        self
    }
}
#endif

// MARK: - Cross-Platform Helpers

extension View {
    /// Hides the tab bar on iOS; no-op on macOS (no tab bar).
    @ViewBuilder
    func hideTabBarIfNeeded() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
