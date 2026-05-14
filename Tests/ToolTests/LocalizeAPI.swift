import Foundation
import Testing
@testable import Tool

@Suite
struct LocalizeAPI {
    @Test("batchQuery(keys:) requests the live API")
    func batchQuery() async throws {
        let credential = try #require(
            AuthTokenStore.resolveCredential(),
            "No APIGateway credential found in env or auth.json."
        )

        let downloader = Localize.Downloader(credential: credential)
        let result = try await downloader.download(keys: ["x_hour_x_min_with_music_gpt", "top_listens_gpt", "play_music_for_x_min_gpt"])

        print("batchQuery(keys:) result:", result)
        #expect(!result.isEmpty)
    }
}
