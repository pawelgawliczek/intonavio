// swiftlint:disable implicitly_unwrapped_optional
@testable import Intonavio
import XCTest

final class LibraryViewModelTests: XCTestCase {
    private var mockClient: MockAPIClient!
    private var viewModel: LibraryViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("songs.json")
        try? FileManager.default.removeItem(at: cacheURL)
        mockClient = MockAPIClient()
        viewModel = LibraryViewModel(apiClient: mockClient)
    }

    @MainActor
    func testFetchSongsLoadsList() async {
        await viewModel.loadSongs()

        XCTAssertFalse(viewModel.songs.isEmpty)
        XCTAssertEqual(viewModel.songs.count, 2)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testFetchSongsFailureSetsError() async {
        mockClient.shouldFail = true

        await viewModel.loadSongs()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.songs.isEmpty)
    }

    @MainActor
    func testAddSongValidation() {
        viewModel.addSongURL = ""
        viewModel.addSong()

        XCTAssertEqual(viewModel.addSongError, "Please enter a YouTube URL")
    }

    @MainActor
    func testAddSongInvalidURL() {
        viewModel.addSongURL = "not a url"
        viewModel.addSong()

        XCTAssertEqual(viewModel.addSongError, "Invalid YouTube URL")
    }

    @MainActor
    func testAddSongSuccess() async {
        viewModel.addSongURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        viewModel.addSong()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(viewModel.addSongError)
        XCTAssertNotNil(viewModel.selectedSearchResult)

        viewModel.confirmAddSong()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(viewModel.isAddingSong)
        XCTAssertFalse(viewModel.songs.isEmpty)
    }
}
