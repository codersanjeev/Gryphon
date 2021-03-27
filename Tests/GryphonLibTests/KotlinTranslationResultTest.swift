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

class KotlinTranslationResultTest: XCTestCase {
	/// Tests to be run when using Swift on Linux
	static var allTests = [
		("testShallowTranslation", testShallowTranslation),
		("testDeepTranslation", testDeepTranslation),
		("testDropLast", testDropLast),
		("testIsEmpty", testIsEmpty),
		("testSourceFileUpdatePosition", testSourceFileUpdatePosition),
	]

	// MARK: - Tests
	func testShallowTranslation() {
		let translation = KotlinTranslation(range: SourceFileRange(
			lineStart: 1, lineEnd: 1, columnStart: 1, columnEnd: 5))
		translation.append("fun ")
		translation.append("foo(")
		translation.append("bla: Int")
		translation.append(")")
		translation.append(": Int")
		translation.append(" {\n")
		translation.append("\treturn bla\n")
		translation.append("}\n")
		let result = translation.resolveTranslation()

		XCTAssertEqual(result.translation, "fun foo(bla: Int): Int {\n\treturn bla\n}\n")
		XCTAssertEqual(result.errorMap, "1:1:4:1:1:1:1:5")
	}

	func testDeepTranslation() {
		let translation = getDeepTranslation()
		translation.append("}\n")

		let result = translation.resolveTranslation()

		XCTAssertEqual(result.translation, """
			fun foo(bla: Int): Int {
				return bla
				return bla + 1
			}

			""")
		XCTAssertEqual(result.errorMap, """
			2:1:3:1:2:1:2:5
			3:9:4:1:3:3:3:5
			3:1:4:1:3:1:3:2
			1:1:5:1:1:1:5:1
			""")
	}

	func testDropLast() {
		let translation = getDeepTranslation()

		//
		translation.dropLast(" + 1\n")
		translation.append("\n}\n")

		let result = translation.resolveTranslation()
		XCTAssertEqual(result.translation, """
			fun foo(bla: Int): Int {
				return bla
				return bla
			}

			""")
	}

	func testIsEmpty() {
		let translation = KotlinTranslation(range: SourceFileRange(
			lineStart: 1, lineEnd: 5, columnStart: 1, columnEnd: 1))
		translation.append("")

		let translation2 = KotlinTranslation(range: SourceFileRange(
			lineStart: 2, lineEnd: 2, columnStart: 1, columnEnd: 5))
		translation2.append("")
		translation2.append("")

		translation.append(translation2)

		let translation3 = KotlinTranslation(range: SourceFileRange(
			lineStart: 3, lineEnd: 3, columnStart: 1, columnEnd: 2))
		translation3.append("")

		let translation4 = KotlinTranslation(range: SourceFileRange(
			lineStart: 3, lineEnd: 3, columnStart: 3, columnEnd: 5))
		translation4.append("")

		translation3.append(translation4)
		translation.append(translation3)

		//
		let emptyTranslation = KotlinTranslation(range: SourceFileRange(
			lineStart: 1, lineEnd: 5, columnStart: 1, columnEnd: 1))

		//
		XCTAssert(translation.isEmpty)
		XCTAssert(emptyTranslation.isEmpty)
		XCTAssertFalse(getDeepTranslation().isEmpty)
	}

	func testSourceFileUpdatePosition() {
		let position = SourceFilePosition.beginningOfFile
		XCTAssertEqual(position.line, 1)
		XCTAssertEqual(position.column, 1)

		let position1 = position.updated(withString: "bla")
		XCTAssertEqual(position1.line, 1)
		XCTAssertEqual(position1.column, 4)

		let position2 = position1.updated(withString: "bla")
		XCTAssertEqual(position2.line, 1)
		XCTAssertEqual(position2.column, 7)

		let position3 = position2.updated(withString: "\n")
		XCTAssertEqual(position3.line, 2)
		XCTAssertEqual(position3.column, 1)

		let position4 = position3.updated(withString: "blabla")
		XCTAssertEqual(position4.line, 2)
		XCTAssertEqual(position4.column, 7)

		let position5 = position4.updated(withString: "blabla\n")
		XCTAssertEqual(position5.line, 3)
		XCTAssertEqual(position5.column, 1)

		let position6 = position5.updated(withString: "blabla\nblabla")
		XCTAssertEqual(position6.line, 4)
		XCTAssertEqual(position6.column, 7)
	}

	// MARK: Auxiliary methods
	func getDeepTranslation() -> KotlinTranslation {
		let translation = KotlinTranslation(range: SourceFileRange(
			lineStart: 1, lineEnd: 5, columnStart: 1, columnEnd: 1))
		translation.append("fun foo(bla: Int): Int {\n")

		let translation2 = KotlinTranslation(range: SourceFileRange(
			lineStart: 2, lineEnd: 2, columnStart: 1, columnEnd: 5))
		translation2.append("\treturn ")
		translation2.append("bla\n")

		translation.append(translation2)

		let translation3 = KotlinTranslation(range: SourceFileRange(
			lineStart: 3, lineEnd: 3, columnStart: 1, columnEnd: 2))
		translation3.append("\treturn ")

		let translation4 = KotlinTranslation(range: SourceFileRange(
			lineStart: 3, lineEnd: 3, columnStart: 3, columnEnd: 5))
		translation4.append("bla + 1\n")

		translation3.append(translation4)
		translation.append(translation3)

		return translation
	}
}
