import XCTest
@testable import XPostingCore

final class CharacterLimitServiceTests: XCTestCase {
    func testWeightedCountIncludesURLAndCJK() {
        let service = CharacterLimitService(postLimit: 280, weightedURLLength: 23)
        let text = "hello 你好 https://example.com"

        let count = service.weightedCount(for: text)

        XCTAssertEqual(count, 34)
    }

    func testAnalyzeUnderLimit() {
        let service = CharacterLimitService(postLimit: 20)
        let analysis = service.analyze("short text")

        XCTAssertTrue(analysis.isWithinLimit)
        XCTAssertEqual(analysis.estimatedPosts, 1)
    }

    func testSplitOverLimitText() {
        let service = CharacterLimitService(postLimit: 40)
        let text = "This is a long draft message that should be split into more than one post for readability and limit compliance."

        let segments = service.split(text)

        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertTrue(segments.allSatisfy { $0.weightedCharacterCount <= 40 })
    }

    func testSplitLongToken() {
        let service = CharacterLimitService(postLimit: 10)
        let text = "supercalifragilisticexpialidocious"

        let segments = service.split(text)

        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertTrue(segments.allSatisfy { $0.weightedCharacterCount <= 10 })
    }
}
