import SwiftUI

/// Full-screen onboarding flow shown on first launch.
/// Linear progression — no skipping individual screens.
struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView(onContinue: viewModel.advance)

            case .headphones:
                HeadphonesStepView(
                    detected: viewModel.headphonesDetected,
                    onContinue: viewModel.advance
                )

            case .micPermission:
                MicPermissionStepView(
                    granted: viewModel.micPermissionGranted,
                    denied: viewModel.micPermissionDenied,
                    onRequestPermission: viewModel.requestMicPermission,
                    onContinue: viewModel.advance
                )

            case .pitchTest:
                PitchTestStepView(
                    noteName: viewModel.detectedNoteName,
                    onContinue: {
                        viewModel.stopPitchTest()
                        viewModel.advance()
                    }
                )

            case .addSong:
                AddSongStepView(onComplete: {
                    viewModel.complete()
                    onComplete()
                })
            }
        }
        .background(Color.intonavioBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        .onChange(of: viewModel.currentStep) { oldStep, newStep in
            if newStep == .headphones { viewModel.checkHeadphones() }
            if newStep == .pitchTest { viewModel.startPitchTest() }
            if oldStep == .pitchTest { viewModel.stopPitchTest() }
        }
    }
}

#Preview {
    OnboardingContainerView(onComplete: {})
}
