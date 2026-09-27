// Verifies SSH and SCP targets reject option injection and malformed addresses.
import XCTest
@testable import OpenLolaTransport

final class RemoteProcessTargetTests: XCTestCase {
    func testSupportedDestinations() throws {
        for target in ["studio", "operator@studio.example", "127.0.0.1", "[::1]", "operator@[2001:db8::1]"] {
            XCTAssertNoThrow(try RemoteProcessTarget.validate(target))
        }
    }
    func testOptionAndMalformedDestinations() {
        for target in ["", "-Fconfig", "-oProxyCommand=command", "a\nb", "user@-host", "@host", "a@b@c", "host:path", "[invalid]", "a b"] {
            XCTAssertThrowsError(try RemoteProcessTarget.validate(target), target)
        }
    }
}
