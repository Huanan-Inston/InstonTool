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
        let result = try await downloader.download(keys: ["calories"])

        print("batchQuery(keys:) result:", result)
        #expect(!result.isEmpty)
    }
}
