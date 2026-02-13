// swiftlint:disable implicitly_unwrapped_optional
@testable import Intonavio
import XCTest

final class APIClientTests: XCTestCase {
    private var mockClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockClient = MockAPIClient()
    }

    // MARK: - Mock Client Success

    func testMockLoginReturnsAuthResponse() async throws {
        let response = try await mockClient.login(
            LoginRequest(email: "test@example.com", password: "password123")
        )
        XCTAssertEqual(response.user.email, "test@example.com")
        XCTAssertFalse(response.accessToken.isEmpty)
    }

    func testMockListSongsReturnsPaginated() async throws {
        let response = try await mockClient.listSongs(page: 1, limit: 20)
        XCTAssertGreaterThan(response.data.count, 0)
        XCTAssertEqual(response.meta.page, 1)
    }

    func testMockCreateSongReturnsQueued() async throws {
        let response = try await mockClient.createSong(
            CreateSongRequest(youtubeUrl: "https://youtube.com/watch?v=test")
        )
        XCTAssertEqual(response.status, .queued)
    }

    func testMockListSessionsReturnsPaginated() async throws {
        let response = try await mockClient.listSessions(page: 1, limit: 20)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].overallScore, 72.5)
    }

    func testMockGetSessionReturnsDetail() async throws {
        let detail = try await mockClient.getSession(id: "sess1")
        XCTAssertGreaterThan(detail.pitchLog.count, 0)
    }

    func testMockStemDownloadURLReturnsURL() async throws {
        let result = try await mockClient.stemDownloadURL(songId: "s1", stemId: "st1")
        XCTAssertFalse(result.url.isEmpty)
    }

    // MARK: - Mock Client Failures

    func testMockClientFailureThrowsAPIError() async {
        mockClient.shouldFail = true

        do {
            _ = try await mockClient.login(
                LoginRequest(email: "test@example.com", password: "pass")
            )
            XCTFail("Expected error")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Endpoint Construction

    func testEndpointPaths() {
        XCTAssertEqual(
            APIEndpoint.appleSignIn(AppleSignInRequest(
                identityToken: "t", authorizationCode: "c", fullName: nil
            )).path,
            "/auth/apple"
        )
        XCTAssertEqual(APIEndpoint.getSong(id: "abc").path, "/songs/abc")
        XCTAssertEqual(
            APIEndpoint.stemDownloadURL(songId: "s1", stemId: "st1").path,
            "/songs/s1/stems/st1/url"
        )
        XCTAssertEqual(APIEndpoint.getSession(id: "sess1").path, "/sessions/sess1")
    }

    func testEndpointMethods() {
        XCTAssertEqual(APIEndpoint.createSong(CreateSongRequest(youtubeUrl: "url")).method, "POST")
        XCTAssertEqual(APIEndpoint.getSong(id: "id").method, "GET")
        XCTAssertEqual(APIEndpoint.deleteSong(id: "id").method, "DELETE")
        XCTAssertEqual(APIEndpoint.deleteAccount.method, "DELETE")
    }

    func testEndpointAuthRequirements() {
        XCTAssertFalse(APIEndpoint.login(LoginRequest(email: "e", password: "p")).requiresAuth)
        XCTAssertFalse(APIEndpoint.register(RegisterRequest(email: "e", password: "p", displayName: "n")).requiresAuth)
        XCTAssertTrue(APIEndpoint.listSongs(page: 1, limit: 20).requiresAuth)
        XCTAssertTrue(APIEndpoint.deleteAccount.requiresAuth)
    }

    func testEndpointQueryItems() {
        let items = APIEndpoint.listSongs(page: 2, limit: 10).queryItems
        XCTAssertEqual(items?.count, 2)
        XCTAssertEqual(items?.first?.name, "page")
        XCTAssertEqual(items?.first?.value, "2")
    }
}
