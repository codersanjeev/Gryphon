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

class IntegrationTest: XCTestCase {
	/// Tests to be run when using Swift on Linux
	static var allTests = [
		("test", test),
		("testWarnings", testWarnings),
	]

	// MARK: - Tests
	func test() {
		do {
			Compiler.clearIssues()

			let tests = TestUtilities.sortedTests
			for testName in tests {
				// Generate kotlin code using the whole compiler
				let testCasePath = TestUtilities.testCasesPath + testName
				let defaultsToFinal = testName.contains("-default-final")

				print("- Testing \(testName) (Swift Syntax)...")
				let generatedKotlinCode = try Compiler.transpileKotlinCode(
					fromInputFiles: [testCasePath.withExtension(.swift)],
					withContext: TranspilationContext(
						indentationString: "\t",
						defaultsToFinal: defaultsToFinal,
						compilationArguments: TranspilationContext.SwiftCompilationArguments(
							absoluteFilePathsAndOtherArguments:
								[testCasePath.withExtension(.swift)]),
						xcodeProjectPath: nil,
						target: nil))
					.first!

				// Load the previously stored kotlin code from file
				let expectedKotlinCode =
					try! Utilities.readFile((testCasePath).withExtension(.kt))

				XCTAssert(
					generatedKotlinCode == expectedKotlinCode,
					"Test \(testName) (Swift Syntax): the transpiler failed to produce " +
						"expected result. Printing diff ('<' means generated, '>' means " +
						"expected):" +
						TestUtilities.diff(generatedKotlinCode, expectedKotlinCode))
			}

			let unexpectedWarnings = Compiler.issues.filter {
					!$0.isError &&
					!$0.fullMessage.contains("Native type") &&
					!$0.fullMessage.contains("fileprivate declarations")
				}
			XCTAssert(
				unexpectedWarnings.isEmpty,
				"Unexpected warnings in integration tests:\n" +
				"\(unexpectedWarnings.map { $0.fullMessage }.joined(separator: "\n\n"))")

			if Compiler.numberOfErrors != 0 {
				XCTFail("🚨 Integration test found errors:\n")
				Compiler.printIssues()
			}
		}
		catch let error {
			XCTFail("🚨 Test failed with error:\n\(error)")
		}
	}

	func testWarnings() {
		do {
			Compiler.clearIssues()

			// Generate kotlin code using the whole compiler
			let testCasePath = TestUtilities.testCasesPath + "warnings.swift"
			_ = try Compiler.transpileKotlinCode(
				fromInputFiles: [testCasePath],
				withContext: TranspilationContext(
					indentationString: "\t",
					defaultsToFinal: false,
					compilationArguments: TranspilationContext.SwiftCompilationArguments(
						absoluteFilePathsAndOtherArguments: [testCasePath]),
					xcodeProjectPath: nil,
					target: nil))
				.first!

			XCTAssert(
				Compiler.numberOfErrors == 0,
				"Expected no errors, found \(Compiler.numberOfErrors):\n" +
					Compiler.issues.filter { $0.isError }.map { $0.fullMessage }
						.joined(separator: "\n"))

			// Make sure the comment for muting warnings is working
			let numberOfExpectedWarnings = 22
			XCTAssert(
				Compiler.numberOfWarnings == numberOfExpectedWarnings,
				"Expected \(numberOfExpectedWarnings) warnings, found " +
					"\(Compiler.numberOfWarnings):\n" +
					Compiler.issues.filter { !$0.isError }.map { $0.fullMessage }
						.joined(separator: "\n"))

			var warnings =
				Compiler.issues.filter { $0.fullMessage.contains("mutable variables") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warning containing \"mutable variables\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings = Compiler.issues.filter { $0.fullMessage.contains("mutating methods") }
			XCTAssertEqual(
				warnings.count, 2,
				"Expected 2 warnings containing \"mutating methods\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			// 2 warnings here (instead of 2) may indicate a problem with muting warnings
			warnings = Compiler.issues.filter { $0.fullMessage.contains("MutableList") }
			XCTAssertEqual(
				warnings.count, 2,
				"Expected 1 warning containing \"MutableList\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings = Compiler.issues.filter { $0.fullMessage.contains("MutableMap") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warning containing \"MutableMap\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings = Compiler.issues.filter { $0.fullMessage.contains("fileprivate") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warning containing \"fileprivate\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings = Compiler.issues.filter { $0.fullMessage.contains("If condition") }
			XCTAssertEqual(
				warnings.count, 3,
				"Expected 3 warnings containing \"If condition\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings = Compiler.issues.filter { $0.fullMessage.contains("Double optionals") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warning containing \"Double optionals\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings =
				Compiler.issues.filter { $0.fullMessage.contains("superclass's initializer") }
			XCTAssertEqual(
				warnings.count, 2,
				"Expected 2 warnings containing \"superclass's initializer\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings =
				Compiler.issues.filter { $0.fullMessage.contains("initializers in structs") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warnings containing \"initializers in structs\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings =
				Compiler.issues.filter { $0.fullMessage.contains("Unknown operator") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warnings containing \"Unknown operator\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings =
				Compiler.issues.filter { $0.fullMessage.contains("standard library") }
			XCTAssertEqual(
				warnings.count, 1,
				"Expected 1 warnings containing \"standard library\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))

			warnings =
				Compiler.issues.filter { $0.fullMessage.contains("Deprecated") }
			XCTAssertEqual(
				warnings.count, 6,
				"Expected 6 warnings containing \"Deprecated\", " +
					"found \(warnings.count) (printed below, if any).\n" +
					warnings.map { $0.fullMessage }.joined(separator: "\n"))
		}
		catch let error {
			XCTFail("🚨 Test failed with error:\n\(error)")
		}
	}

}
