import XCTest
@testable import RcmdApp

final class LoginItemCommandTests: XCTestCase {
    func testParsesEnableFlag() {
        XCTAssertEqual(LoginItemCommand(arguments: ["rcmd", "--enable-login-item"]), .enable)
    }

    func testParsesDisableFlag() {
        XCTAssertEqual(LoginItemCommand(arguments: ["rcmd", "--disable-login-item"]), .disable)
    }

    func testIgnoresExecutablePathAndUnknownArguments() {
        XCTAssertNil(LoginItemCommand(arguments: ["--enable-login-item"]))
        XCTAssertNil(LoginItemCommand(arguments: ["rcmd"]))
        XCTAssertNil(LoginItemCommand(arguments: ["rcmd", "--psn_0_12345"]))
    }
}
