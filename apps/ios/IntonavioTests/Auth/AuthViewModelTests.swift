// swiftlint:disable implicitly_unwrapped_optional
@testable import Intonavio
import XCTest

final class AuthViewModelTests: XCTestCase {
    private var mockClient: MockAPIClient!
    private var viewModel: AuthViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        mockClient = MockAPIClient()
        viewModel = AuthViewModel(apiClient: mockClient)
    }

    // MARK: - Email Login

    @MainActor
    func testLoginSuccess() async {
        var didAuthenticate = false
        viewModel.setOnAuthenticated { _ in didAuthenticate = true }
        viewModel.email = "test@example.com"
        viewModel.password = "password123"

        viewModel.login()

        // Wait for async task
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(didAuthenticate)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testLoginEmptyEmailShowsError() {
        viewModel.email = ""
        viewModel.password = "password123"

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Email is required")
    }

    @MainActor
    func testLoginEmptyPasswordShowsError() {
        viewModel.email = "test@example.com"
        viewModel.password = ""

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Password is required")
    }

    @MainActor
    func testLoginFailureShowsError() async {
        mockClient.shouldFail = true
        viewModel.email = "test@example.com"
        viewModel.password = "password123"

        viewModel.login()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Email Registration

    @MainActor
    func testRegisterSuccess() async {
        var didAuthenticate = false
        viewModel.setOnAuthenticated { _ in didAuthenticate = true }
        viewModel.email = "new@example.com"
        viewModel.password = "password123"
        viewModel.displayName = "New User"

        viewModel.register()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(didAuthenticate)
    }

    @MainActor
    func testRegisterShortPasswordShowsError() {
        viewModel.email = "new@example.com"
        viewModel.password = "short"
        viewModel.displayName = "New User"

        viewModel.register()

        XCTAssertEqual(viewModel.errorMessage, "Password must be at least 8 characters")
    }

    @MainActor
    func testRegisterEmptyDisplayNameShowsError() {
        viewModel.email = "new@example.com"
        viewModel.password = "password123"
        viewModel.displayName = ""

        viewModel.register()

        XCTAssertEqual(viewModel.errorMessage, "Display name is required")
    }
}
