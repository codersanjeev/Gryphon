//
// Copyright 2018 Vinicius Jorge Vendramini
//
// Licensed under the Hippocratic License, Version 2.1;
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://firstdonoharm.dev/version/2/1/license.md
//
// To the full extent allowed by law, this software comes "AS IS,"
// WITHOUT ANY WARRANTY, EXPRESS OR IMPLIED, and licensor and any other
// contributor shall not be liable to anyone for any damages or other
// liability arising from, out of, or in connection with the sotfware
// or this license, under any kind of legal claim.
// See the License for the specific language governing permissions and
// limitations under the License.
//

@testable import GryphonLib
import XCTest

class ShellTest: XCTestCase {
	/// Tests to be run when using Swift on Linux
	static var allTests = [
		("testEcho", testEcho),
		("testSwiftc", testSwiftc),
	]

	// MARK: - Tests
	func testEcho() {
		let command: List = ["echo", "foo bar baz"]
		let commandResult = Shell.runShellCommand(command)
		XCTAssertEqual(commandResult.standardOutput, "foo bar baz\n")
		XCTAssertEqual(commandResult.standardError, "")
		XCTAssertEqual(commandResult.status, 0)
	}

	func testSwiftc() {
		let command1: List = ["swiftc", "-dump-ast"]
		let command1Result = Shell.runShellCommand(command1)
		XCTAssertEqual(command1Result.standardOutput, "")
		XCTAssert(command1Result.standardError.contains("<unknown>:0: error: no input files\n"))
		XCTAssertNotEqual(command1Result.status, 0)

		let command2: List = ["swiftc", "--help"]
		let command2Result = Shell.runShellCommand(command2)
		XCTAssert(command2Result.standardOutput.contains("-dump-ast"))
		XCTAssertEqual(command2Result.standardError, "")
		XCTAssertEqual(command2Result.status, 0)
	}
}
