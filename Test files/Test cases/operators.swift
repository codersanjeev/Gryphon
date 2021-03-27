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

let x = 0
let y = x + 1
let z = 2 + 3

print(x)
print(y)
print(z)

//
let multiplication = 0 * 1
let division = 10 / 2
let subtraction = 3 - 1
let sum = 4 + 1

print(multiplication)
print(division)
print(subtraction)
print(sum)

// Without spaces
let multiplication2 = 0*1
let division2 = 10/2
let subtraction2 = 3-1
let sum2 = 4+1

print(multiplication2)
print(division2)
print(subtraction2)
print(sum2)

// With negative numbers
var multiplication3 = 0 * -1
var division3 = -10 / 2
var subtraction3 = -3 - 1
var sum3 = 4 + -1

print(multiplication3)
print(division3)
print(subtraction3)
print(sum3)

// In assignments (as opposed to variable declarations)
multiplication3 = 1 * 2
division3 = 1 / 2
subtraction3 = 1 - 2
sum3 = 1 + 2

print(multiplication3)
print(division3)
print(subtraction3)
print(sum3)

// Equality
if x == 0 {
	print("true")
}

if x == 1 {
	print("false")
}

if x != 1 {
	print("true")
}

// Precedence (equality above ternary)
let precedenceResult = 0 == 1 ? 2 == 3 : 4 == 5
print(precedenceResult)

// Precedence (support `as`, `as?` and `is`)
let castResult1 = precedenceResult as Any
print(castResult1)
let castResult2 = precedenceResult as? Any
print(castResult2)
let castResult3 = precedenceResult is Bool
print(castResult3)

// Precedence (same precedence, right associativity)
let a: Int? = nil
let b: Int? = 1
let c = a ?? b ?? 2
print(c)
