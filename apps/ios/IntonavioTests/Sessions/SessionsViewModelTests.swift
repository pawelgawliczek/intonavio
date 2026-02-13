// swiftlint:disable implicitly_unwrapped_optional
@testable import Intonavio
import XCTest

final class SessionsViewModelTests: XCTestCase {
    private var mockClient: MockAPIClient!
    private var viewModel: SessionsViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        mockClient = MockAPIClient()
        viewModel = SessionsViewModel(apiClient: mockClient)
    }

    @MainActor
    func testFetchSessionsLoadsList() async {
        await viewModel.loadSessions(page: 1)

        XCTAssertFalse(viewModel.sessions.isEmpty)
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testFetchSessionsFailure() async {
        mockClient.shouldFail = true
        await viewModel.loadSessions(page: 1)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }

    @MainActor
    func testHasMorePages() async {
        await viewModel.loadSessions(page: 1)
        XCTAssertFalse(viewModel.hasMorePages)
    }
}
