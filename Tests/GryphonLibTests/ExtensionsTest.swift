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

struct TestableRange: Equatable {
	let lowerBound: Int
	let upperBound: Int

	init(_ string: String, _ range: Range<String.Index>) {
		self.lowerBound = range.lowerBound.utf16Offset(in: string)
		self.upperBound = range.upperBound.utf16Offset(in: string)
	}

	init(_ lowerBound: Int, _ upperBound: Int) {
		self.lowerBound = lowerBound
		self.upperBound = upperBound
	}
}

class ExtensionsTest: XCTestCase {
	/// Tests to be run when using Swift on Linux
	static var allTests = [
		("testStringSplit", testStringSplit),
		("testOccurrencesOfSubstring", testOccurrencesOfSubstring),
		("testSplitUsingUnescapedSpaces", testSplitUsingUnescapedSpaces),
		("testRemoveTrailingWhitespace", testRemoveTrailingWhitespace),
		("testUpperSnakeCase", testUpperSnakeCase),
		("testCapitalizedAsCamelCase", testCapitalizedAsCamelCase),
		("testRemovingBackslashEscapes", testRemovingBackslashEscapes),
		("testIsNumberAndIsUppercase", testIsNumberAndIsUppercase),
		("testSafeIndex", testSafeIndex),
		("testSecondToLast", testSecondToLast),
		("testRotated", testRotated),
		("testGroupBy", testGroupBy),
		("testRemovingDuplicates", testRemovingDuplicates),
		("testContainsCollection", testContainsCollection),
	]

	// MARK: - Tests
	func testStringSplit() {
		XCTAssertEqual(
			"->".split(withStringSeparator: "->"),
			[])
		XCTAssertEqual(
			"->->".split(withStringSeparator: "->"),
			[])
		XCTAssertEqual(
			"a->b".split(withStringSeparator: "->"),
			["a", "b"])
		XCTAssertEqual(
			"a->b->c".split(withStringSeparator: "->"),
			["a", "b", "c"])
		XCTAssertEqual(
			"->b->c".split(withStringSeparator: "->"),
			["b", "c"])
		XCTAssertEqual(
			"->->c".split(withStringSeparator: "->"),
			["c"])
		XCTAssertEqual(
			"a->b->".split(withStringSeparator: "->"),
			["a", "b"])
		XCTAssertEqual(
			"a->->".split(withStringSeparator: "->"),
			["a"])
		XCTAssertEqual(
			"a->->b".split(withStringSeparator: "->"),
			["a", "b"])
		XCTAssertEqual(
			"abc".split(withStringSeparator: "->"),
			["abc"])
		XCTAssertEqual(
			"->(Int, (String) -> Int) ->-> Int ->"
				.split(withStringSeparator: "->"),
			["(Int, (String) ", " Int) ", " Int "])

		// Omit empty subsequences
		XCTAssertEqual(
			"->".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["", ""])
		XCTAssertEqual(
			"->->".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["", "", ""])
		XCTAssertEqual(
			"a->b".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["a", "b"])
		XCTAssertEqual(
			"a->b->c".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["a", "b", "c"])
		XCTAssertEqual(
			"->b->c".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["", "b", "c"])
		XCTAssertEqual(
			"->->c".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["", "", "c"])
		XCTAssertEqual(
			"a->b->".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["a", "b", ""])
		XCTAssertEqual(
			"a->->".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["a", "", ""])
		XCTAssertEqual(
			"a->->b".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["a", "", "b"])
		XCTAssertEqual(
			"abc".split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["abc"])
		XCTAssertEqual(
			"->(Int, (String) -> Int) ->-> Int ->"
				.split(withStringSeparator: "->", omittingEmptySubsequences: false),
			["", "(Int, (String) ", " Int) ", "", " Int ", ""])

		// Max splits
		XCTAssertEqual(
			"->".split(withStringSeparator: "->", maxSplits: 3, omittingEmptySubsequences: false),
			["", ""])
		XCTAssertEqual(
			"->->".split(withStringSeparator: "->", maxSplits: 1, omittingEmptySubsequences: false),
			["", "->"])
		XCTAssertEqual(
			"a->b".split(withStringSeparator: "->", maxSplits: 0, omittingEmptySubsequences: false),
			["a->b"])
		XCTAssertEqual(
			"a->b->c".split(
				withStringSeparator: "->", maxSplits: 2, omittingEmptySubsequences: false),
			["a", "b", "c"])
		XCTAssertEqual(
			"a->b->c->d".split(
				withStringSeparator: "->", maxSplits: 2, omittingEmptySubsequences: false),
			["a", "b", "c->d"])
		XCTAssertEqual(
			"a->b->c->d".split(
				withStringSeparator: "->", maxSplits: 1, omittingEmptySubsequences: false),
			["a", "b->c->d"])
		XCTAssertEqual(
			"->b->c".split(withStringSeparator: "->", maxSplits: 1),
			["b->c"])
		XCTAssertEqual(
			"->->c".split(withStringSeparator: "->", maxSplits: 1),
			["->c"])
		XCTAssertEqual(
			"a->b->".split(withStringSeparator: "->", maxSplits: 1),
			["a", "b->"])
		XCTAssertEqual(
			"a->->".split(withStringSeparator: "->", maxSplits: 1),
			["a", "->"])
		XCTAssertEqual(
			"a->->b".split(withStringSeparator: "->", maxSplits: 1),
			["a", "->b"])
		XCTAssertEqual(
			"abc".split(withStringSeparator: "->", maxSplits: 0),
			["abc"])
		XCTAssertEqual(
			"abc".split(withStringSeparator: "->", maxSplits: 1),
			["abc"])
		XCTAssertEqual(
			"->(Int, (String) -> Int) ->-> Int ->"
				.split(withStringSeparator: "->", maxSplits: 3, omittingEmptySubsequences: false),
			["", "(Int, (String) ", " Int) ", "-> Int ->"])
		XCTAssertEqual(
			"->(Int, (String) -> Int) ->-> Int ->"
				.split(withStringSeparator: "->", maxSplits: 3),
			["(Int, (String) ", " Int) ", "-> Int ->"])
	}

	func testOccurrencesOfSubstring() {
		XCTAssertEqual(
			"->".occurrences(of: "->").map { TestableRange("->", $0) },
			List<TestableRange>(
				[TestableRange(0, 2)]))
		XCTAssertEqual(
			"a->b".occurrences(of: "->").map { TestableRange("a->b", $0) },
			List<TestableRange>(
				[TestableRange(1, 3)]))
		XCTAssertEqual(
			"a->b->c".occurrences(of: "->").map { TestableRange("a->b->c", $0) },
			List<TestableRange>(
				[TestableRange(1, 3),
				 TestableRange(4, 6),
			]))
		XCTAssertEqual(
			"->b->c".occurrences(of: "->").map { TestableRange("->b->c", $0) },
			List<TestableRange>(
				[TestableRange(0, 2),
				 TestableRange(3, 5),
			]))
		XCTAssertEqual(
			"->->c".occurrences(of: "->").map { TestableRange("->->c", $0) },
			List<TestableRange>(
				[TestableRange(0, 2),
				 TestableRange(2, 4),
			]))
		XCTAssertEqual(
			"a->b->".occurrences(of: "->").map { TestableRange("a->b->", $0) },
			List<TestableRange>(
				[TestableRange(1, 3),
				 TestableRange(4, 6),
			]))
		XCTAssertEqual(
			"a->->".occurrences(of: "->").map { TestableRange("a->->", $0) },
			List<TestableRange>(
				[TestableRange(1, 3),
				 TestableRange(3, 5),
			]))
		XCTAssertEqual(
			"a->->b".occurrences(of: "->").map { TestableRange("a->->b", $0) },
			List<TestableRange>(
				[TestableRange(1, 3),
				 TestableRange(3, 5),
			]))
		XCTAssertEqual(
			"abc".occurrences(of: "->").map { TestableRange("abc", $0) },
			List<TestableRange>([]))
		XCTAssertEqual(
			"->(Int, (String) -> Int) ->-> Int ->".occurrences(of: "->").map {
					TestableRange("->(Int, (String) -> Int) ->-> Int ->", $0)
				},
			List<TestableRange>([
				TestableRange(0, 2),
				TestableRange(17, 19),
				TestableRange(25, 27),
				TestableRange(27, 29),
				TestableRange(34, 36),
			]))
	}

	func testSplitUsingUnescapedSpaces() {
		XCTAssertEqual(
			"foo bar baz".splitUsingUnescapedSpaces(),
			["foo", "bar", "baz"])
		XCTAssertEqual(
			"foo\\ bar baz".splitUsingUnescapedSpaces(),
			["foo\\ bar", "baz"])
		XCTAssertEqual(
			"foo\\ bar\\ baz".splitUsingUnescapedSpaces(),
			["foo\\ bar\\ baz"])
		XCTAssertEqual(
			"foo bar\\ baz".splitUsingUnescapedSpaces(),
			["foo", "bar\\ baz"])
	}

	func testRemoveTrailingWhitespace() {
		XCTAssertEqual("", "".removeTrailingWhitespace())
		XCTAssertEqual("a", "a".removeTrailingWhitespace())
		XCTAssertEqual("abcde", "abcde".removeTrailingWhitespace())
		XCTAssertEqual("abcde", "abcde".removeTrailingWhitespace())
		XCTAssertEqual("abcde", "abcde  \t\t  ".removeTrailingWhitespace())
		XCTAssertEqual("abcde  \t\t  abcde", "abcde  \t\t  abcde".removeTrailingWhitespace())
		XCTAssertEqual("abcde  \t\t  abcde", "abcde  \t\t  abcde  ".removeTrailingWhitespace())
		XCTAssertEqual("abcde  \t\t  abcde", "abcde  \t\t  abcde \t ".removeTrailingWhitespace())
	}

	func testUpperSnakeCase() {
		XCTAssertEqual("ABC", "abc".upperSnakeCase())
		XCTAssertEqual("FOO_BAR", "fooBar".upperSnakeCase())
		XCTAssertEqual("FOO_BAR", "FooBar".upperSnakeCase())
		XCTAssertEqual("HTTPS_BAR", "HTTPSBar".upperSnakeCase())
	}

	func testCapitalizedAsCamelCase() {
		XCTAssertEqual("Abc", "abc".capitalizedAsCamelCase())
		XCTAssertEqual("FooBar", "fooBar".capitalizedAsCamelCase())
	}

	func testRemovingBackslashEscapes() {
		XCTAssertEqual("a b", "a b".removingBackslashEscapes)
		XCTAssertEqual("a b\n", "a b\\n".removingBackslashEscapes)
		XCTAssertEqual("a\tb\n", "a\\tb\\n".removingBackslashEscapes)
		XCTAssertEqual("\\a\tb\n", "\\\\a\\tb\\n".removingBackslashEscapes)
	}

	func testIsNumberAndIsUppercase() {
		let numbers = "0123456789"
		let uppercaseCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		let lowercaseCharacters = "abcdefghijklmnopqrstuvwxyz"
		XCTAssertEqual(numbers.count, 10)
		XCTAssertEqual(uppercaseCharacters.count, 26)
		XCTAssertEqual(lowercaseCharacters.count, 26)

		for character in numbers {
			XCTAssert(character.isNumber)
			XCTAssertFalse(character.isUppercase)
		}

		for character in uppercaseCharacters {
			XCTAssert(character.isUppercase)
			XCTAssertFalse(character.isNumber)
		}

		for character in lowercaseCharacters {
			XCTAssertFalse(character.isUppercase)
			XCTAssertFalse(character.isNumber)
		}
	}

	func testSafeIndex() {
		let array: List = [1, 2, 3]
		XCTAssert(array[safe: 0] == 1)
		XCTAssert(array[safe: 1] == 2)
		XCTAssert(array[safe: 2] == 3)
		XCTAssert(array[safe: 3] == nil)
		XCTAssert(array[safe: -1] == nil)

		XCTAssert(array.getSafe(0) == 1)
		XCTAssert(array.getSafe(1) == 2)
		XCTAssert(array.getSafe(2) == 3)
		XCTAssert(array.getSafe(3) == nil)
		XCTAssert(array.getSafe(-1) == nil)
	}

	func testSecondToLast() {
		let array1: List = [1, 2, 3]
		let array2: List = [1]
		XCTAssert(array1.secondToLast == 2)
		XCTAssert(array2.secondToLast == nil)
	}

	func testRotated() {
		let array: List = [1, 2, 3]
		let array1 = array.rotated()
		let array2 = array1.rotated()
		let array3 = array2.rotated()
		XCTAssertEqual(array1, [2, 3, 1])
		XCTAssertEqual(array2, [3, 1, 2])
		XCTAssertEqual(array3, [1, 2, 3])
	}

	func testGroupBy() {
		let array: List = [1, 2, 3, 2, 3, 1, 2, 3]
		let histogram = array.group(by: { "\($0)" })
		XCTAssertEqual(
			histogram,
			["1": [1, 1],
			 "2": [2, 2, 2],
			 "3": [3, 3, 3], ])

		let isEvenHistogram = array.group(by: { $0 % 2 == 0 })
		XCTAssertEqual(
			isEvenHistogram,
			[true: [2, 2, 2],
			 false: [1, 3, 3, 1, 3], ])
	}

	func testRemovingDuplicates() {
		let array1: List = [1, 2, 3]
		let array2: List = [1, 2, 3, 1, 2, 2]
		let array3: List<Int> = []

		XCTAssertEqual(array1.removingDuplicates(), [1, 2, 3])
		XCTAssertEqual(array2.removingDuplicates(), [1, 2, 3])
		XCTAssertEqual(array3.removingDuplicates(), [])
	}

	func testContainsCollection() {
		let array1 = [1, 2, 3]
		let array2 = [1, 2, 3, 4]
		let array3 = [1]
		let array4: [Int] = []
		let array5 = [3, 2, 1]

		XCTAssert(array2.contains(collection: array1))
		XCTAssert(array2.contains(collection: array3))
		XCTAssert(array2.contains(collection: array4))
		XCTAssert(array2.contains(collection: array3))

		XCTAssertFalse(array3.contains(collection: array1))
		XCTAssertFalse(array4.contains(collection: array3))
		XCTAssertFalse(array1.contains(collection: array2))
		XCTAssertFalse(array2.contains(collection: array5))
	}
}
