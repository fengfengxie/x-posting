import XCTest
@testable import XPostingCore

final class XAuthServiceTests: XCTestCase {
    func testCodeChallengeDeterministic() {
        let verifier = "abc123verifier"
        let challenge1 = XAuthService.codeChallenge(for: verifier)
        let challenge2 = XAuthService.codeChallenge(for: verifier)

        XCTAssertEqual(challenge1, challenge2)
        XCTAssertFalse(challenge1.isEmpty)
    }
}
