import Testing
@testable import Today

@MainActor
struct RecordingActionTests {
    @Test func quickActionsRouteBothMediaTypesAndRejectUnknownActions() {
        let router = RecordingActionRouter()
        #expect(router.handle(shortcutType: "record-video-entry"))
        #expect(router.pendingRequest?.destination == .video)
        #expect(router.handle(shortcutType: "record-audio-entry"))
        #expect(router.pendingRequest?.destination == .audio)
        #expect(!router.handle(shortcutType: "unknown"))
        #expect(router.pendingRequest?.destination == .audio)
    }

    @Test func repeatedActionsRemainDistinctAndStaleConsumptionPreservesNewRequest() throws {
        let router = RecordingActionRouter()
        router.request(.audio)
        let first = try #require(router.pendingRequest)
        router.request(.audio)
        let second = try #require(router.pendingRequest)
        #expect(first != second)
        router.consume(first)
        #expect(router.pendingRequest == second)
        router.consume(second)
        #expect(router.pendingRequest == nil)
    }
}
