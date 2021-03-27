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

public class KotlinTranslator {
	// MARK: - Constants
	static let errorTranslation = "<<Error>>"
	static let lineLimit = 100

	// MARK: - Properties
	private let context: TranspilationContext
	private var sourceFile: SourceFile?

	/// Stores the list of matches of any templates that are currently being translated.
	private let templateMatchesStack: MutableList<List<(String, Expression)>> = []

	// MARK: - Interface

	public init(context: TranspilationContext) {
		self.context = context
	}

	public func translateAST(_ gryphonAST: GryphonAST) throws -> KotlinTranslation {
		sourceFile = gryphonAST.sourceFile

		let declarationsTranslation =
			try translateSubtrees(gryphonAST.declarations, withIndentation: "")

		let indentation = increaseIndentation("")
		let statementsTranslation =
			try translateSubtrees(gryphonAST.statements, withIndentation: indentation)

		let result = declarationsTranslation

		guard !statementsTranslation.isEmpty else {
			return result
		}

		// Add newline between declarations and the main function, if needed
		if !declarationsTranslation.isEmpty {
			result.append("\n")
		}

		result.append("fun main(args: Array<String>) {\n")
		result.append(statementsTranslation)
		result.append("}\n")

		return result
	}

	// MARK: - Statement translations

	struct TreeAndTranslation {
		let subtree: Statement
		let translation: KotlinTranslation
	}

	private func translateSubtrees(
		_ subtrees: List<Statement>,
		withIndentation indentation: String,
		limitForAddingNewlines: Int = 0)
		throws -> KotlinTranslation
	{
		let subtreesRange: SourceFileRange?

		let startRange = subtrees.first(where: { $0.range != nil })?.range
		let endRange = subtrees.last(where: { $0.range != nil })?.range

		if let startRange = startRange, let endRange = endRange {
			subtreesRange = SourceFileRange(
				lineStart: startRange.start.line,
				lineEnd: endRange.end.line,
				columnStart: startRange.start.column,
				columnEnd: endRange.end.column)
		}
		else {
			subtreesRange = nil
		}

		let treesAndTranslations = try subtrees.map {
			TreeAndTranslation(
				subtree: $0,
				translation: try translateSubtree($0, withIndentation: indentation))
			}.filter {
				!$0.translation.isEmpty
			}

		if treesAndTranslations.count <= limitForAddingNewlines {
			let result = KotlinTranslation(range: subtreesRange)
			for translation in treesAndTranslations.map({ $0.translation }) {
				result.append(translation)
			}
			return result
		}

		let treesAndTranslationsWithoutFirst = treesAndTranslations.dropFirst()

		let result = KotlinTranslation(range: subtreesRange)

		for (currentSubtree, nextSubtree)
			in zip(treesAndTranslations, treesAndTranslationsWithoutFirst)
		{
			result.append(currentSubtree.translation)

			// Cases that should go together
			if currentSubtree.subtree is CommentStatement {
				continue
			}
			if currentSubtree.subtree is VariableDeclaration,
				nextSubtree.subtree is VariableDeclaration
			{
				continue
			}
			if let currentExpressionStatement = currentSubtree.subtree as? ExpressionStatement,
				let nextExpressionStatement = nextSubtree.subtree as? ExpressionStatement
			{
				if currentExpressionStatement.expression is CallExpression,
					nextExpressionStatement.expression is CallExpression
				{
					continue
				}
				if currentExpressionStatement.expression is LiteralCodeExpression,
					nextExpressionStatement.expression is LiteralCodeExpression
				{
					continue
				}
				if currentExpressionStatement.expression is LiteralCodeExpression,
					nextExpressionStatement.expression is LiteralCodeExpression
				{
					continue
				}
			}
			if currentSubtree.subtree is AssignmentStatement,
				nextSubtree.subtree is AssignmentStatement
			{
				continue
			}
			if currentSubtree.subtree is TypealiasDeclaration,
				nextSubtree.subtree is TypealiasDeclaration
			{
				continue
			}
			if currentSubtree.subtree is DoStatement,
				nextSubtree.subtree is CatchStatement
			{
				continue
			}
			if currentSubtree.subtree is CatchStatement,
				nextSubtree.subtree is CatchStatement
			{
				continue
			}

			result.append("\n")
		}

		if let lastSubtree = treesAndTranslations.last {
			result.append(lastSubtree.translation)
		}

		return result
	}

	private func translateSubtree(
		_ subtree: Statement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		if let commentStatement = subtree as? CommentStatement {
			return KotlinTranslation(
				range: subtree.range,
				string: "\(indentation)//\(commentStatement.value)\n")
		}
		if subtree is ImportDeclaration {
			return KotlinTranslation(range: subtree.range)
		}
		if subtree is ExtensionDeclaration {
			return try unexpectedASTStructureError(
				"Extension structure should have been removed in a transpilation pass",
				AST: subtree)
		}
		if subtree is DeferStatement {
			return try unexpectedASTStructureError(
				"Defer statements are only supported as top-level statements in function bodies",
				AST: subtree)
		}
		if let typealiasDeclaration = subtree as? TypealiasDeclaration {
			return try translateTypealias(typealiasDeclaration, withIndentation: indentation)
		}
		if let classDeclaration = subtree as? ClassDeclaration {
			return try translateClassDeclaration(classDeclaration, withIndentation: indentation)
		}
		if let structDeclaration = subtree as? StructDeclaration {
			return try translateStructDeclaration(structDeclaration, withIndentation: indentation)
		}
		if let companionObject = subtree as? CompanionObject {
			return try translateCompanionObject(companionObject, withIndentation: indentation)
		}
		if let enumDeclaration = subtree as? EnumDeclaration {
			return try translateEnumDeclaration(enumDeclaration, withIndentation: indentation)
		}
		if let doStatement = subtree as? DoStatement {
			return try translateDoStatement(doStatement, withIndentation: indentation)
		}
		if let catchStatement = subtree as? CatchStatement {
			return try translateCatchStatement(catchStatement, withIndentation: indentation)
		}
		if let forEachStatement = subtree as? ForEachStatement {
			return try translateForEachStatement(forEachStatement, withIndentation: indentation)
		}
		if let whileStatement = subtree as? WhileStatement {
			return try translateWhileStatement(whileStatement, withIndentation: indentation)
		}
		if let functionDeclaration = subtree as? FunctionDeclaration {
			return try translateFunctionDeclaration(
				functionDeclaration: functionDeclaration, withIndentation: indentation)
		}
		if let protocolDeclaration = subtree as? ProtocolDeclaration {
			return try translateProtocolDeclaration(
				protocolDeclaration, withIndentation: indentation)
		}
		if let throwStatement = subtree as? ThrowStatement {
			return try translateThrowStatement(throwStatement, withIndentation: indentation)
		}
		if let variableDeclaration = subtree as? VariableDeclaration {
			return try translateVariableDeclaration(
				variableDeclaration, withIndentation: indentation)
		}
		if let assignmentStatement = subtree as? AssignmentStatement {
			return try translateAssignmentStatement(
				assignmentStatement, withIndentation: indentation)
		}
		if let ifStatement = subtree as? IfStatement {
			return try translateIfStatement(ifStatement, withIndentation: indentation)
		}
		if let switchStatement = subtree as? SwitchStatement {
			return try translateSwitchStatement(switchStatement, withIndentation: indentation)
		}
		if let returnStatement = subtree as? ReturnStatement {
			return try translateReturnStatement(returnStatement, withIndentation: indentation)
		}
		if subtree is BreakStatement {
			return KotlinTranslation(
				range: subtree.range,
				string: "\(indentation)break\n")
		}
		if subtree is ContinueStatement {
			return KotlinTranslation(
				range: subtree.range,
				string: "\(indentation)continue\n")
		}
		if let expressionStatement = subtree as? ExpressionStatement {
			let expressionTranslation = try translateExpression(
				expressionStatement.expression,
				withIndentation: indentation)
			if !expressionTranslation.isEmpty {
				let result = KotlinTranslation(range: subtree.range)
				result.append(indentation)
				result.append(expressionTranslation)
				result.append("\n")
				return result
			}
			else {
				return KotlinTranslation(
					range: subtree.range,
					string: "\n")
			}
		}
		if subtree is ErrorStatement {
			return KotlinTranslation(
				range: subtree.range,
				string: KotlinTranslator.errorTranslation)
		}

		fatalError("This should never be reached.")
	}

	private func translateEnumDeclaration(
		_ enumDeclaration: EnumDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let isEnumClass = self.context.hasEnumClass(named: enumDeclaration.enumName)

		let enumString = isEnumClass ? "enum" : "sealed"

		let result = KotlinTranslation(range: enumDeclaration.range)
		result.append(indentation)

		if !enumDeclaration.annotations.isEmpty {
			result.append("\(enumDeclaration.annotations.joined(separator: " ")) ")
		}

		if let access = enumDeclaration.access {
			result.append("\(access) ")
		}

		result.append("\(enumString) class \(enumDeclaration.enumName)")

		if isEnumClass {
			let maybeRawValueDeclaration = enumDeclaration.members.compactMap
				{ (member: Statement) -> VariableDeclaration? in
					if let variableDeclaration = member as? VariableDeclaration,
					   variableDeclaration.identifier == "rawValue",
					   variableDeclaration.getter == nil,
					   variableDeclaration.setter == nil

					{
						return variableDeclaration
					}
					return nil
			}.first

			if let rawValueDeclaration = maybeRawValueDeclaration,
			   let typeAnnotation = rawValueDeclaration.typeAnnotation
			{
				enumDeclaration.members.remove(rawValueDeclaration)
				result.append("(val rawValue: \(typeAnnotation))")
			}
		}

		if !enumDeclaration.inherits.isEmpty {
			var translatedInheritedTypes = enumDeclaration.inherits.map { translateType($0) }
			translatedInheritedTypes = translatedInheritedTypes.map {
				self.context.protocols.atomic.contains($0) ?
					$0 :
					$0 + "()"
			}
			result.append(": \(translatedInheritedTypes.joined(separator: ", "))")
		}

		result.append(" {\n")

		let increasedIndentation = increaseIndentation(indentation)

		if isEnumClass {
			let translations = try enumDeclaration.elements.map
				{ (element: EnumElement) -> KotlinTranslation in
					let result = KotlinTranslation(range: enumDeclaration.range)
					result.append(increasedIndentation)

					if !element.annotations.isEmpty {
						result.append(element.annotations.joined(separator: " "))
						result.append(" ")
					}

					result.append(element.name)

					if let rawValue = element.rawValue {
						result.append("(rawValue = ")
						try result.append(translateExpression(
							rawValue,
							withIndentation: increaseIndentation(increasedIndentation)))
						result.append(")")
					}

					return result
				}

			result.appendTranslations(translations, withSeparator: ",\n")

			if !enumDeclaration.elements.isEmpty {
				result.append(";\n")
			}
			else {
				result.append(increaseIndentation(indentation))
				result.append(";\n")
			}
		}
		else {
			for element in enumDeclaration.elements {
				let translation = translateEnumElementDeclaration(
					enumName: enumDeclaration.enumName,
					element: element,
					withIndentation: increasedIndentation)
				result.append(translation)
			}
		}

		let membersTranslation =
			try translateSubtrees(enumDeclaration.members, withIndentation: increasedIndentation)

		// Add a newline between cases and members if needed
		if !membersTranslation.isEmpty {
			result.append("\n")
		}

		result.append(membersTranslation)
		result.append("\(indentation)}\n")

		return result
	}

	private func translateEnumElementDeclaration(
		enumName: String,
		element: EnumElement,
		withIndentation indentation: String) -> KotlinTranslation
	{
		let capitalizedElementName = element.name.capitalizedAsCamelCase()
		let annotationsString = element.annotations.isEmpty ?
			"" :
			"\(element.annotations.joined(separator: " ")) "

		let result = KotlinTranslation(range: nil)
		result.append("\(indentation)\(annotationsString)class \(capitalizedElementName)")

		if element.associatedValues.isEmpty {
			result.append(": \(enumName)()\n")
			return result
		}
		else {
			let associatedValuesString =
				element.associatedValues
					.map { "val \($0.label): \(translateType($0.typeName))" }
					.joined(separator: ", ")
			result.append("(\(associatedValuesString)): \(enumName)()\n")
			return result
		}
	}

	private func translateProtocolDeclaration(
		_ protocolDeclaration: ProtocolDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: protocolDeclaration.range)
		result.append("\(indentation)")

		if !protocolDeclaration.annotations.isEmpty {
			result.append("\(protocolDeclaration.annotations.joined(separator: " ")) ")
		}

		if let access = protocolDeclaration.access {
			result.append("\(access) ")
		}

		result.append("interface \(protocolDeclaration.protocolName)")

		if !protocolDeclaration.inherits.isEmpty {
			let translatedInheritances = protocolDeclaration.inherits.map { translateType($0) }
			result.append(": " + translatedInheritances.joined(separator: ", "))
		}

		result.append(" {\n")

		let contents = try translateSubtrees(
			protocolDeclaration.members,
			withIndentation: increaseIndentation(indentation))
		result.append(contents)

		result.append("\(indentation)}\n")

		return result
	}

	private func translateTypealias(
		_ typealiasDeclaration: TypealiasDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let translatedType = translateType(typealiasDeclaration.typeName)
		let result = KotlinTranslation(range: typealiasDeclaration.range)
		result.append(indentation)

		if let access = typealiasDeclaration.access {
			result.append("\(access) ")
		}

		result.append("typealias \(typealiasDeclaration.identifier) = \(translatedType)\n")

		return result
	}

	private func translateClassDeclaration(
		_ classDeclaration: ClassDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: classDeclaration.range)
		result.append(indentation)

		if !classDeclaration.annotations.isEmpty {
			let annotationsString = classDeclaration.annotations.joined(separator: " ")
			result.append("\(annotationsString) ")
		}

		if let access = classDeclaration.access {
			result.append("\(access) ")
		}

		if classDeclaration.isOpen {
			result.append("open ")
		}

		result.append("class \(classDeclaration.className)")

		if !classDeclaration.inherits.isEmpty {
			let translatedInheritances = classDeclaration.inherits.map { translateType($0) }
			result.append(": " + translatedInheritances.joined(separator: ", "))
		}

		result.append(" {\n")

		let increasedIndentation = increaseIndentation(indentation)

		let classContents = try translateSubtrees(
			classDeclaration.members,
			withIndentation: increasedIndentation)

		result.append(classContents)
		result.append("\(indentation)}\n")
		return result
	}

	/// If a value type's members are all immutable, that value type can safely be translated as a
	/// class. Source: https://forums.swift.org/t/are-immutable-structs-like-classes/16270
	private func translateStructDeclaration(
		_ structDeclaration: StructDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let increasedIndentation = increaseIndentation(indentation)

		let result = KotlinTranslation(range: structDeclaration.range)
		result.append(indentation)

		if !structDeclaration.annotations.isEmpty {
			result.append("\(structDeclaration.annotations.joined(separator: " ")) ")
		}

		if let access = structDeclaration.access {
			result.append("\(access) ")
		}

		result.append("data class \(structDeclaration.structName)(\n")

		let properties = structDeclaration.members.filter { statementIsStructProperty($0) }
		let otherMembers = structDeclaration.members.filter { !statementIsStructProperty($0) }

		// Translate properties individually, dropping the newlines at the end
		let propertyTranslations = try properties.map { property -> KotlinTranslation in
			return try translatePropertyWithoutNewline(property, indentation: increasedIndentation)
		}
		result.appendTranslations(propertyTranslations, withSeparator: ",\n")
		result.append("\n\(indentation))")

		if !structDeclaration.inherits.isEmpty {
			var translatedInheritedTypes = structDeclaration.inherits.map { translateType($0) }
			translatedInheritedTypes = translatedInheritedTypes.map {
				self.context.protocols.atomic.contains($0) ?
					$0 :
					$0 + "()"
			}
			result.append(": \(translatedInheritedTypes.joined(separator: ", "))")
		}

		let otherMembersTranslation = try translateSubtrees(
			otherMembers,
			withIndentation: increasedIndentation)

		if !otherMembersTranslation.isEmpty {
			result.append(" {\n")
			result.append(otherMembersTranslation)
			result.append("\(indentation)}\n")
		}
		else {
			result.append("\n")
		}

		return result
	}

	private func translatePropertyWithoutNewline(
		_ property: Statement,
		indentation: String)
		throws -> KotlinTranslation
	{
		let translation = try translateSubtree(property, withIndentation: indentation)
		translation.dropLast("\n")
		return translation
	}

	private func statementIsStructProperty(
		_ statement: Statement)
		-> Bool
	{
		if let variableDeclaration = statement as? VariableDeclaration {
			if variableDeclaration.getter == nil,
				variableDeclaration.setter == nil,
				!variableDeclaration.isStatic
			{
				return true
			}
		}

		return false
	}

	private func translateCompanionObject(
		_ companionObject: CompanionObject,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: companionObject.range)
		result.append("\(indentation)companion object {\n")

		let increasedIndentation = increaseIndentation(indentation)

		let contents = try translateSubtrees(
			companionObject.members,
			withIndentation: increasedIndentation)

		result.append(contents)
		result.append("\(indentation)}\n")
		return result
	}

	private func translateFunctionDeclaration(
		functionDeclaration: FunctionDeclaration,
		withIndentation indentation: String,
		shouldAddNewlines: Bool = false)
		throws -> KotlinTranslation
	{
		var indentation = indentation

		let result = KotlinTranslation(range: functionDeclaration.range)
		result.append(indentation)

		if !functionDeclaration.annotations.isEmpty {
			let annotationsString = functionDeclaration.annotations.joined(separator: " ")
			result.append("\(annotationsString) ")
		}

		if let access = functionDeclaration.access {
			result.append("\(access) ")
		}

		if functionDeclaration.isOpen {
			result.append("open ")
		}

		let isInit = (functionDeclaration is InitializerDeclaration)
		if isInit {
			result.append("constructor(")
		}
		else if functionDeclaration.prefix == "invoke" {
			result.append("operator fun invoke(")
		}
		else {
			result.append("fun ")

			if !functionDeclaration.genericTypes.isEmpty {
				result.append("<\(functionDeclaration.genericTypes.joined(separator: ", "))> ")
			}

			if let extensionType = functionDeclaration.extendsType {
				let translatedExtensionType = translateType(extensionType)
				let companionString = functionDeclaration.isStatic ? "Companion." : ""

				result.append(translatedExtensionType + "." + companionString)
			}

			result.append(functionDeclaration.prefix + "(")
		}

		// Check if we need to call a superclass initializer or if we need to specify a return type
		// after the parameters
		var returnTypeString: String?
		var superCallTranslation: KotlinTranslation?
		if let initializerDeclaration = functionDeclaration as? InitializerDeclaration {
			if let superCall = initializerDeclaration.superCall {
				superCallTranslation = try translateCallExpression(
					superCall,
					withIndentation: increaseIndentation(indentation))
			}
		}
		else if functionDeclaration.returnType != "()",
			functionDeclaration.returnType != "Void",
			!isInit
		{
			// If it doesn't, that place might be used for the return type

			let translatedReturnType = translateType(functionDeclaration.returnType)
			returnTypeString = translatedReturnType
		}

		let parameterStrings = try functionDeclaration.parameters
			.map { try translateFunctionDeclarationParameter($0, withIndentation: indentation) }

		let singleExpressionStatement: ExpressionStatement?
		if functionDeclaration.returnType != "Void",
			functionDeclaration.returnType != "()",
			functionDeclaration.returnType != "Unit"
		{
			singleExpressionStatement =
				self.getSingleExpressionStatement(functionDeclaration.statements)
		}
		else {
			singleExpressionStatement = nil
		}

		if !shouldAddNewlines {
			result.appendTranslations(parameterStrings, withSeparator: ", ")
			result.append(")")
			if let returnTypeString = returnTypeString {
				result.append(": ")
				result.append(returnTypeString)
			}
			else if let superCallTranslation = superCallTranslation {
				result.append(": ")
				result.append(superCallTranslation)
			}
			guard functionDeclaration.isJustProtocolInterface == false else {
				result.append("\n")
				return result
			}

			if singleExpressionStatement == nil {
				result.append(" {\n")
			} else {
				result.append(" = ")
			}

			if result.resolveTranslation().translation.count >= KotlinTranslator.lineLimit {
				return try translateFunctionDeclaration(
					functionDeclaration: functionDeclaration, withIndentation: indentation,
					shouldAddNewlines: true)
			}
		}
		else {
			let parameterIndentation = increaseIndentation(indentation)
			result.append("\n\(parameterIndentation)")
			result.appendTranslations(parameterStrings, withSeparator: ",\n\(parameterIndentation)")
			result.append(")\n")

			if let returnTypeString = returnTypeString {
				result.append(parameterIndentation)
				result.append(": ")
				result.append(returnTypeString)
				result.append("\n")
			}
			else if let superCallTranslation = superCallTranslation {
				result.append(parameterIndentation)
				result.append(": ")
				result.append(superCallTranslation)
				result.append("\n")
			}

			if singleExpressionStatement == nil {
				result.append("\(indentation){\n")
			} else {
				result.append("\( increaseIndentation(indentation) )= ")
			}
		}

		guard let statements = functionDeclaration.statements else {
			result.append("\n\(indentation)}\n")
			return result
		}

		// Get all statements that have been deferred
		let innerDeferStatements = statements.flatMap { extractInnerDeferStatements($0) }
		// Get all other statements
		let nonDeferStatements = statements.filter { !isDeferStatement($0) }

		indentation = increaseIndentation(indentation)

		if !innerDeferStatements.isEmpty {
			let increasedIndentation = increaseIndentation(indentation)
			result.append("\(indentation)try {\n")
			result.append(try translateSubtrees(
				nonDeferStatements,
				withIndentation: increasedIndentation,
				limitForAddingNewlines: 3))
			result.append("\(indentation)}\n")
			result.append("\(indentation)finally {\n")
			result.append(try translateSubtrees(
				innerDeferStatements,
				withIndentation: increasedIndentation,
				limitForAddingNewlines: 3))
			result.append("\(indentation)}\n")
		}
		else {
			if let singleExpressionStatement = singleExpressionStatement {
				result.append(try translateExpression(
					singleExpressionStatement.expression,
					withIndentation: indentation))
				result.append("\n")
			} else {
				result.append(try translateSubtrees(
					statements,
					withIndentation: indentation,
					limitForAddingNewlines: 3))
			}
		}

		indentation = decreaseIndentation(indentation)
		if singleExpressionStatement == nil {
			result.append(indentation + "}\n")
		}

		return result
	}

	/// Used to determine if the function is a single-expression function.
	/// Returns the single expression if it is, or `nil` otherwise.
	/// Makes an exception for ConcatenationExpressions and LiteralCodeExpression, which may
	/// translate as more than one expression (e.g. `a(); b()`) causing Kotlin compilation to fail.
	private func getSingleExpressionStatement(
		_ statements: List<Statement>?)
		-> ExpressionStatement?
	{
		guard let statements = statements,
			statements.count == 1,
			let expressionStatement = statements.first as? ExpressionStatement,
			!(expressionStatement.expression is ConcatenationExpression),
			!(expressionStatement.expression is LiteralCodeExpression) else
		{
			return nil
		}

		return expressionStatement
	}

	private func isDeferStatement(
		_ maybeDeferStatement: Statement)
		-> Bool
	{
		if maybeDeferStatement is DeferStatement {
			return true
		}
		else {
			return false
		}
	}

	private func extractInnerDeferStatements(
		_ maybeDeferStatement: Statement)
		-> MutableList<Statement>
	{
		if let deferStatement = maybeDeferStatement as? DeferStatement {
			return deferStatement.statements
		}
		else {
			return []
		}
	}

	private func translateFunctionDeclarationParameter(
		_ parameter: FunctionParameter,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: nil)

		if parameter.isVariadic {
			result.append("vararg ")
		}

		result.append(parameter.label + ": " + translateType(parameter.typeName))

		if let defaultValue = parameter.value {
			result.append(" = ")
			result.append(try translateExpression(defaultValue, withIndentation: indentation))
			return result
		}
		else {
			return result
		}
	}

	private func translateDoStatement(
		_ doStatement: DoStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let translatedStatements = try translateSubtrees(
			doStatement.statements,
			withIndentation: increaseIndentation(indentation),
			limitForAddingNewlines: 3)
		let result = KotlinTranslation(range: doStatement.range)
		result.append("\(indentation)try {\n")
		result.append(translatedStatements)
		result.append("\(indentation)}\n")
		return result
	}

	private func translateCatchStatement(
		_ catchStatement: CatchStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: catchStatement.range)

		if let variableDeclaration = catchStatement.variableDeclaration {
			if let typeAnnotation = variableDeclaration.typeAnnotation {
				let translatedType = translateType(typeAnnotation)
				result.append("\(indentation)catch " +
					"(\(variableDeclaration.identifier): \(translatedType)) {\n")
			}
			else {
				result.append("\(indentation)catch " +
				"(\(variableDeclaration.identifier)) {\n")
			}
		}
		else {
			result.append("\(indentation)catch {\n")
		}

		let translatedStatements = try translateSubtrees(
			catchStatement.statements,
			withIndentation: increaseIndentation(indentation),
			limitForAddingNewlines: 3)

		result.append(translatedStatements)
		result.append("\(indentation)}\n")

		return result
	}

	private func translateForEachStatement(
		_ forEachStatement: ForEachStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: forEachStatement.range)
		result.append("\(indentation)for (")

		let variableTranslation: KotlinTranslation
		if let variable = forEachStatement.variable {
			variableTranslation = try translateExpression(variable, withIndentation: indentation)
		}
		else {
			variableTranslation = KotlinTranslation(range: nil, string: "_0")
		}

		result.append(variableTranslation)
		result.append(" in ")

		let collectionTranslation =
			try translateExpression(forEachStatement.collection, withIndentation: indentation)

		result.append(collectionTranslation)
		result.append(") {\n")

		let increasedIndentation = increaseIndentation(indentation)
		let statementsTranslation = try translateSubtrees(
			forEachStatement.statements,
			withIndentation: increasedIndentation,
			limitForAddingNewlines: 3)

		result.append(statementsTranslation)

		result.append(indentation + "}\n")
		return result
	}

	private func translateWhileStatement(
		_ whileStatement: WhileStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: whileStatement.range)
		result.append("\(indentation)while (")

		let expressionTranslation =
			try translateExpression(whileStatement.expression, withIndentation: indentation)
		result.append(expressionTranslation)
		result.append(") {\n")

		let increasedIndentation = increaseIndentation(indentation)
		let statementsTranslation = try translateSubtrees(
			whileStatement.statements,
			withIndentation: increasedIndentation,
			limitForAddingNewlines: 3)

		result.append(statementsTranslation)
		result.append(indentation + "}\n")
		return result
	}

	private func translateIfStatement(
		_ ifStatement: IfStatement,
		isElseIf: Bool = false,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let keyword = (ifStatement.conditions.isEmpty && ifStatement.declarations.isEmpty) ?
			"else" :
			(isElseIf ? "else if" : "if")

		let result = KotlinTranslation(range: ifStatement.range)
		result.append(indentation + keyword + " ")

		let increasedIndentation = increaseIndentation(indentation)

		let conditionsTranslation = try ifStatement.conditions.compactMap {
				conditionToExpression($0)
			}.map {
				try translateExpression($0, withIndentation: indentation)
			}

		if keyword != "else" {
			if ifStatement.isGuard {
				result.append("(!(")
				result.appendTranslations(conditionsTranslation, withSeparator: " && ")
				result.append(")) ")
			}
			else {
				result.append("(")
				result.appendTranslations(conditionsTranslation, withSeparator: " && ")
				result.append(") ")
			}
		}

		result.append("{\n")

		let statementsTranslation = try translateSubtrees(
			ifStatement.statements,
			withIndentation: increasedIndentation,
			limitForAddingNewlines: 3)

		result.append(statementsTranslation)
		result.append(indentation + "}\n")

		if let unwrappedElse = ifStatement.elseStatement {
			result.append(try translateIfStatement(
				unwrappedElse, isElseIf: true, withIndentation: indentation))
		}

		return result
	}

	private func conditionToExpression(_ condition: IfStatement.IfCondition) -> Expression? {
		if case let .condition(expression: expression) = condition {
			return expression
		}
		else {
			return nil
		}
	}

	private func translateSwitchStatement(
		_ switchStatement: SwitchStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: switchStatement.range)

		if let convertsToExpression = switchStatement.convertsToExpression {
			if convertsToExpression is ReturnStatement {
				result.append("\(indentation)return when (")
			}
			else if let assignmentStatement = convertsToExpression as? AssignmentStatement {
				let translatedLeftHand = try translateExpression(
					assignmentStatement.leftHand,
					withIndentation: indentation)
				result.append("\(indentation)")
				result.append(translatedLeftHand)
				result.append(" = when (")
			}
			else if let variableDeclaration = convertsToExpression as? VariableDeclaration {
				let newVariableDeclaration = VariableDeclaration(
					syntax: nil,
					range: nil,
					identifier: variableDeclaration.identifier,
					typeAnnotation: variableDeclaration.typeAnnotation,
					expression: NilLiteralExpression(syntax: nil, range: nil),
					getter: nil,
					setter: nil,
					access: nil,
					isOpen: false,
					isLet: variableDeclaration.isLet,
					isStatic: false,
					extendsType: nil,
					annotations: variableDeclaration.annotations)
				let translatedVariableDeclaration = try translateVariableDeclaration(
					newVariableDeclaration,
					withIndentation: indentation)
				let cleanTranslation = String(translatedVariableDeclaration
					.resolveTranslation().translation.dropLast("null\n".count))
				result.append(cleanTranslation)
				result.append("when (")
			}
		}

		if result.isEmpty {
			result.append("\(indentation)when (")
		}

		let expressionTranslation =
			try translateExpression(switchStatement.expression, withIndentation: indentation)
		let increasedIndentation = increaseIndentation(indentation)

		result.append(expressionTranslation)
		result.append(") {\n")

		for switchCase in switchStatement.cases {

			result.append(increasedIndentation)

			let translatedExpressions: MutableList<KotlinTranslation> = []

			for caseExpression in switchCase.expressions {
				let translatedExpression = try translateSwitchCaseExpression(
					caseExpression,
					withSwitchExpression: switchStatement.expression,
					indentation: increasedIndentation)
				translatedExpressions.append(translatedExpression)
			}

			if translatedExpressions.isEmpty {
				result.append("else -> ")
			}
			else {
				result.appendTranslations(translatedExpressions, withSeparator: ", ")
				result.append(" -> ")
			}

			if switchCase.statements.count == 1,
				let onlyStatement = switchCase.statements.first
			{
				let statementTranslation =
					try translateSubtree(onlyStatement, withIndentation: "")
				result.append(statementTranslation)
			}
			else {
				result.append("{\n")
				let statementsIndentation = increaseIndentation(increasedIndentation)
				let statementsTranslation = try translateSubtrees(
					switchCase.statements,
					withIndentation: statementsIndentation,
					limitForAddingNewlines: 3)
				result.append(statementsTranslation)
				result.append("\(increasedIndentation)}\n")
			}
		}

		result.append("\(indentation)}\n")

		return result
	}

	private func translateSwitchCaseExpression(
		_ caseExpression: Expression,
		withSwitchExpression switchExpression: Expression,
		indentation: String)
		throws -> KotlinTranslation
	{
		if let binaryExpression = caseExpression as? BinaryOperatorExpression {
			if binaryExpression.leftExpression == switchExpression,
				binaryExpression.operatorSymbol == "is",
				binaryExpression.typeName == "Bool"
			{
				// If is a check for a cast (`direction is .north`)
				let translatedType = try translateExpression(
					binaryExpression.rightExpression,
					withIndentation: indentation)
				let result = KotlinTranslation(range: caseExpression.range)
				result.append("is ")
				result.append(translatedType)
				return result
			}
		}
		else if let concatenationExpression = caseExpression as? ConcatenationExpression,
			let leftConcatenationExpression =
				concatenationExpression.leftExpression as? ConcatenationExpression,
			let literalOperator =
				leftConcatenationExpression.rightExpression as? LiteralCodeExpression,
			literalOperator.string == ".." || literalOperator.string == " until "
		{
			// If it's a range (`1 in 0..1`)
			let result = KotlinTranslation(range: caseExpression.range)
			result.append("in ")
			let translatedExpression = try translateExpression(
				caseExpression,
				withIndentation: indentation)
			result.append(translatedExpression)
			return result
		}

		let translatedExpression = try translateExpression(
			caseExpression,
			withIndentation: indentation)
		return translatedExpression
	}

	private func translateThrowStatement(
		_ throwStatement: ThrowStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let expressionTranslation =
			try translateExpression(throwStatement.expression, withIndentation: indentation)
		let result = KotlinTranslation(range: throwStatement.range)
		result.append("\(indentation)throw ")
		result.append(expressionTranslation)
		result.append("\n")
		return result
	}

	private func translateReturnStatement(
		_ returnStatement: ReturnStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		if let expression = returnStatement.expression {
			let expressionTranslation =
				try translateExpression(expression, withIndentation: indentation)
			let result = KotlinTranslation(range: returnStatement.range)
			result.append("\(indentation)return")

			if let label = returnStatement.label {
				result.append("@\(label)")
			}

			result.append(" ")
			result.append(expressionTranslation)
			result.append("\n")
			return result
		}
		else {
			if let label = returnStatement.label {
				return KotlinTranslation(
					range: returnStatement.range,
					string: "\(indentation)return@\(label)\n")
			}
			else {
				return KotlinTranslation(
					range: returnStatement.range,
					string: "\(indentation)return\n")
			}

		}
	}

	private func translateVariableDeclaration(
		_ variableDeclaration: VariableDeclaration,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: variableDeclaration.range)
		result.append(indentation)

		if !variableDeclaration.annotations.isEmpty {
			let annotationsString = variableDeclaration.annotations.joined(separator: " ")
			result.append("\(annotationsString) ")
		}

		if let access = variableDeclaration.access {
			result.append("\(access) ")
		}

		if variableDeclaration.isOpen {
			result.append("open ")
		}

		var keyword: String
		if variableDeclaration.getter != nil && variableDeclaration.setter != nil {
			keyword = "var"
		}
		else if variableDeclaration.getter != nil && variableDeclaration.setter == nil {
			keyword = "val"
		}
		else {
			if variableDeclaration.isLet {
				keyword = "val"
			}
			else {
				keyword = "var"
			}
		}

		result.append("\(keyword) ")

		let extensionPrefix: String
		if let extendsType = variableDeclaration.extendsType {
			let translatedExtendedType = translateType(extendsType)

			let genericString: String
			if let genericIndex = translatedExtendedType.firstIndex(of: "<") {
				let genericContents = translatedExtendedType.suffix(from: genericIndex)
				genericString = "\(genericContents) "
			}
			else {
				genericString = ""
			}

			if variableDeclaration.isStatic {
				extensionPrefix = genericString + translatedExtendedType + ".Companion."
			}
			else {
				extensionPrefix = genericString + translatedExtendedType + "."
			}
		}
		else {
			extensionPrefix = ""
		}

		result.append("\(extensionPrefix)\(variableDeclaration.identifier)")

		if let typeAnnotation = variableDeclaration.typeAnnotation {
			// Kotlin doesn't support just "List" as the type annotation.
			// If the type is just "Array", try to get the element type from the expression.
			// If we can't, leave it empty and hope Kotlin figures it out.
			if typeAnnotation == "Array" || typeAnnotation == "Dictionary" {
				if let expressionType = variableDeclaration.expression?.swiftType {
					let translatedType = translateType(expressionType)
					result.append(": \(translatedType)")
				}
			}
			else {
				let translatedType = translateType(typeAnnotation)
				result.append(": \(translatedType)")
			}
		}

		if let expression = variableDeclaration.expression {
			let expressionTranslation =
				try translateExpression(expression, withIndentation: indentation)
			result.append(" = ")
			result.append(expressionTranslation)
		}

		result.append("\n")

		let indentation1 = increaseIndentation(indentation)
		let indentation2 = increaseIndentation(indentation1)
		if let getter = variableDeclaration.getter {
			if let statements = getter.statements {
				result.append("\(indentation1)get() ")

				if let singleExpressionStatement = getSingleExpressionStatement(statements)
				{
					result.append("= ")
					result.append(try translateExpression(singleExpressionStatement.expression,
														  withIndentation: indentation1))
					result.append("\n")
				} else {
					result.append("{\n")
					result.append(try translateSubtrees(
						statements,
						withIndentation: indentation2,
						limitForAddingNewlines: 3))
					result.append(indentation1 + "}\n")
				}
			}
		}

		if let setter = variableDeclaration.setter {
			if let statements = setter.statements {
				result.append(indentation1 + "set(newValue) {\n")
				result.append(try translateSubtrees(
					statements,
					withIndentation: indentation2,
					limitForAddingNewlines: 3))
				result.append(indentation1 + "}\n")
			}
		}

		return result
	}

	private func translateAssignmentStatement(
		_ assignmentStatement: AssignmentStatement,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let leftTranslation =
			try translateExpression(assignmentStatement.leftHand, withIndentation: indentation)
		let rightTranslation =
			try translateExpression(assignmentStatement.rightHand, withIndentation: indentation)
		let result = KotlinTranslation(range: assignmentStatement.range)
		result.append(indentation)
		result.append(leftTranslation)
		result.append(" = ")
		result.append(rightTranslation)
		result.append("\n")
		return result
	}

	// MARK: - Expression translations

	internal func translateExpression(
		_ expression: Expression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		if let literalCodeExpression = expression as? LiteralCodeExpression {
			return try translateLiteralCodeExpression(
				literalCodeExpression,
				withIndentation: indentation)
		}
		if let concatenationExpression = expression as? ConcatenationExpression {
			return try translateConcatenationExpression(
				concatenationExpression,
				withIndentation: indentation)
		}
		if let arrayExpression = expression as? ArrayExpression {
			return try translateArrayExpression(arrayExpression, withIndentation: indentation)
		}
		if let dictionaryExpression = expression as? DictionaryExpression {
			return try translateDictionaryExpression(
				dictionaryExpression, withIndentation: indentation)
		}
		if let binaryOperatorExpression = expression as? BinaryOperatorExpression {
			return try translateBinaryOperatorExpression(
				binaryOperatorExpression, withIndentation: indentation)
		}
		if let callExpression = expression as? CallExpression {
			return try translateCallExpression(callExpression, withIndentation: indentation)
		}
		if let closureExpression = expression as? ClosureExpression {
			return try translateClosureExpression(closureExpression, withIndentation: indentation)
		}
		if let declarationReferenceExpression = expression as? DeclarationReferenceExpression {
			return translateDeclarationReferenceExpression(declarationReferenceExpression)
		}
		if let returnExpression = expression as? ReturnExpression {
			return try translateReturnExpression(returnExpression, withIndentation: indentation)
		}
		if let dotExpression = expression as? DotExpression {
			return try translateDotSyntaxCallExpression(dotExpression, withIndentation: indentation)
		}
		if let literalStringExpression = expression as? LiteralStringExpression {
			return translateStringLiteral(literalStringExpression)
		}
		if let literalCharacterExpression = expression as? LiteralCharacterExpression {
			return translateCharacterLiteral(literalCharacterExpression)
		}
		if let interpolatedStringLiteralExpression =
			expression as? InterpolatedStringLiteralExpression
		{
			return try translateInterpolatedStringLiteralExpression(
				interpolatedStringLiteralExpression, withIndentation: indentation)
		}
		if let prefixUnaryExpression = expression as? PrefixUnaryExpression {
			return try translatePrefixUnaryExpression(
				prefixUnaryExpression, withIndentation: indentation)
		}
		if let postfixUnaryExpression = expression as? PostfixUnaryExpression {
			return try translatePostfixUnaryExpression(
				postfixUnaryExpression, withIndentation: indentation)
		}
		if let ifExpression = expression as? IfExpression {
			return try translateIfExpression(ifExpression, withIndentation: indentation)
		}
		if let typeExpression = expression as? TypeExpression {
			return KotlinTranslation(
				range: typeExpression.range,
				string: translateType(typeExpression.typeName))
		}
		if let subscriptExpression = expression as? SubscriptExpression {
			return try translateSubscriptExpression(
				subscriptExpression, withIndentation: indentation)
		}
		if let parenthesesExpression = expression as? ParenthesesExpression {
			let result = KotlinTranslation(range: parenthesesExpression.range)
			result.append("(")
			result.append(try translateExpression(
				parenthesesExpression.expression,
				withIndentation: indentation))
			result.append(")")
			return result
		}
		if let forceValueExpression = expression as? ForceValueExpression {
			let result = KotlinTranslation(range: forceValueExpression.range)
			result.append(try translateExpression(
				forceValueExpression.expression,
				withIndentation: indentation))
			result.append("!!")
			return result
		}
		if let optionalExpression = expression as? OptionalExpression {
			let result = KotlinTranslation(range: optionalExpression.range)
			result.append(try translateExpression(
				optionalExpression.expression,
				withIndentation: indentation))
			result.append("?")
			return result
		}
		if let literalIntExpression = expression as? LiteralIntExpression {
			return KotlinTranslation(
				range: literalIntExpression.range,
				string: literalIntExpression.radix.prefix +
					String(literalIntExpression.value,
						   radix: literalIntExpression.radix.rawValue))
		}
		if let literalUIntExpression = expression as? LiteralUIntExpression {
			return KotlinTranslation(
				range: literalUIntExpression.range,
				string: literalUIntExpression.radix.prefix +
					String(literalUIntExpression.value,
						   radix: literalUIntExpression.radix.rawValue) +
					"u")
		}
		if let literalDoubleExpression = expression as? LiteralDoubleExpression {
			return KotlinTranslation(
				range: literalDoubleExpression.range,
				string: String(literalDoubleExpression.value))
		}
		if let literalFloatExpression = expression as? LiteralFloatExpression {
			return KotlinTranslation(
				range: literalFloatExpression.range,
				string: String(literalFloatExpression.value) + "f")
		}
		if let literalBoolExpression = expression as? LiteralBoolExpression {
			return KotlinTranslation(
				range: literalBoolExpression.range,
				string: String(literalBoolExpression.value))
		}
		if expression is NilLiteralExpression {
			return KotlinTranslation(
				range: expression.range,
				string: "null")
		}
		if let tupleExpression = expression as? TupleExpression {
			return try translateTupleExpression(tupleExpression, withIndentation: indentation)
		}
		if expression is ErrorExpression {
			return KotlinTranslation(
				range: expression.range,
				string: KotlinTranslator.errorTranslation)
		}

		fatalError("This should never be reached.")
	}

	private func translateSubscriptExpression(
		_ subscriptExpression: SubscriptExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let translatedSubscriptedExpression = try translateExpression(
			subscriptExpression.subscriptedExpression,
			withIndentation: indentation)

		let result = KotlinTranslation(range: subscriptExpression.range)
		result.append(translatedSubscriptedExpression)
		result.append("[")

		// Translate the indices without the labels (subscript expressions in Kotlin don't support
		// labels
		let increasedIndentation = increaseIndentation(indentation)
		let indexTranslations = try subscriptExpression.indexExpression.pairs.map {
			try translateExpression($0.expression, withIndentation: increasedIndentation)
		}
		result.appendTranslations(indexTranslations, withSeparator: ", ")

		result.append("]")
		return result
	}

	private func translateArrayExpression(
		_ arrayExpression: ArrayExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: arrayExpression.range)

		let translations = try arrayExpression.elements.map {
			try translateExpression($0, withIndentation: indentation)
			}

		if arrayExpression.typeName.hasPrefix("MutableList") {
			result.append("mutableListOf")
		}
		else {
			result.append("listOf")
		}

		result.append("(")
		result.appendTranslations(translations, withSeparator: ", ")
		result.append(")")

		return result
	}

	private func translateDictionaryExpression(
		_ dictionaryExpression: DictionaryExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: dictionaryExpression.range)

		if dictionaryExpression.typeName.hasPrefix("MutableMap") {
			result.append("mutableMapOf(")
		}
		else {
			result.append("mapOf(")
		}

		let keyTranslations = try dictionaryExpression.keys.map {
				try translateExpression($0, withIndentation: indentation)
			}
		let valueTranslations = try dictionaryExpression.values.map {
				try translateExpression($0, withIndentation: indentation)
			}

		for (keyTranslation, valueTranslation)
			in zip(keyTranslations, valueTranslations).dropLast()
		{
			result.append(keyTranslation)
			result.append(" to ")
			result.append(valueTranslation)
			result.append(", ")
		}
		if let keyTranslation = keyTranslations.last,
			let valueTranslation = valueTranslations.last
		{
			result.append(keyTranslation)
			result.append(" to ")
			result.append(valueTranslation)
		}

		result.append(")")

		return result
	}

	private func translateReturnExpression(
		_ returnExpression: ReturnExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		if let expression = returnExpression.expression {
			let expressionTranslation =
				try translateExpression(expression, withIndentation: indentation)
			let result = KotlinTranslation(range: returnExpression.range)
			result.append("return ")
			result.append(expressionTranslation)
			return result
		}
		else {
			return KotlinTranslation(range: returnExpression.range, string: "return")
		}
	}

	private func translateDotSyntaxCallExpression(
		_ dotExpression: DotExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let leftHandTranslation =
			try translateExpression(dotExpression.leftExpression, withIndentation: indentation)
		let rightHandTranslation =
			try translateExpression(dotExpression.rightExpression, withIndentation: indentation)
		let leftHandString = leftHandTranslation.resolveTranslation().translation
		let rightHandString = rightHandTranslation.resolveTranslation().translation

		if self.context.hasSealedClass(named: leftHandString) {
			let translatedEnumCase = rightHandString.capitalizedAsCamelCase()
			let result = KotlinTranslation(range: dotExpression.range)
			result.append(leftHandTranslation)
			result.append(".")
			result.append(translatedEnumCase)
			result.append("()")
			return result
		}
		else {
			let enumName = leftHandString.split(withStringSeparator: ".").last!
			if self.context.hasEnumClass(named: enumName) {
				let translatedEnumCase = rightHandString.upperSnakeCase()
				let result = KotlinTranslation(range: dotExpression.range)
				result.append(leftHandTranslation)
				result.append(".")
				result.append(translatedEnumCase)
				return result
			}
			else {
				let result = KotlinTranslation(range: dotExpression.range)
				result.append(leftHandTranslation)
				result.append(".")
				result.append(rightHandTranslation)
				return result
			}
		}
	}

	private func translateBinaryOperatorExpression(
		_ binaryOperatorExpression: BinaryOperatorExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let leftTranslation = try translateExpression(
			binaryOperatorExpression.leftExpression,
			withIndentation: indentation)
		let rightTranslation = try translateExpression(
			binaryOperatorExpression.rightExpression,
			withIndentation: indentation)

		let result = KotlinTranslation(range: binaryOperatorExpression.range)
		result.append(leftTranslation)
		result.append(" ")
		result.append(binaryOperatorExpression.operatorSymbol)
		result.append(" ")
		result.append(rightTranslation)
		return result
	}

	private func translatePrefixUnaryExpression(
		_ prefixUnaryExpression: PrefixUnaryExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let expressionTranslation = try translateExpression(
			prefixUnaryExpression.subExpression,
			withIndentation: indentation)
		let result = KotlinTranslation(range: prefixUnaryExpression.range)
		result.append(prefixUnaryExpression.operatorSymbol)
		result.append(expressionTranslation)
		return result
	}

	private func translatePostfixUnaryExpression(
		_ postfixUnaryExpression: PostfixUnaryExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let expressionTranslation = try translateExpression(
			postfixUnaryExpression.subExpression,
			withIndentation: indentation)
		let result = KotlinTranslation(range: postfixUnaryExpression.range)
		result.append(expressionTranslation)
		result.append(postfixUnaryExpression.operatorSymbol)
		return result
	}

	private func translateIfExpression(
		_ ifExpression: IfExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let conditionTranslation =
			try translateExpression(ifExpression.condition, withIndentation: indentation)
		let trueExpressionTranslation =
			try translateExpression(ifExpression.trueExpression, withIndentation: indentation)
		let falseExpressionTranslation =
			try translateExpression(ifExpression.falseExpression, withIndentation: indentation)

		let result = KotlinTranslation(range: ifExpression.range)
		result.append("if (")
		result.append(conditionTranslation)
		result.append(") { ")
		result.append(trueExpressionTranslation)
		result.append(" } else { ")
		result.append(falseExpressionTranslation)
		result.append(" }")
		return result
	}

	private func translateCallExpression(
		_ callExpression: CallExpression,
		withIndentation indentation: String,
		shouldAddNewlines: Bool = false)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: callExpression.range)

		var functionExpression = callExpression.function
		while true {
			if let expression = functionExpression as? DotExpression {
				result.append(try translateExpression(
					expression.leftExpression,
					withIndentation: indentation))
				result.append(".")
				functionExpression = expression.rightExpression
			}
			else {
				break
			}
		}

		result.append(try translateExpression(functionExpression, withIndentation: indentation))

		let parametersTranslation: KotlinTranslation
		parametersTranslation = try translateParameters(
			forCallExpression: callExpression,
			withIndentation: indentation,
			shouldAddNewlines: shouldAddNewlines)

		result.append(parametersTranslation)

		let lineSize = result.resolveTranslation().translation.count

		if !shouldAddNewlines, lineSize >= KotlinTranslator.lineLimit {
			return try translateCallExpression(
				callExpression,
				withIndentation: indentation,
				shouldAddNewlines: true)
		}
		else {
			return result
		}
	}

	private func translateParameters(
		forCallExpression callExpression: CallExpression,
		withIndentation indentation: String,
		shouldAddNewlines: Bool)
		throws -> KotlinTranslation
	{
		if callExpression.allowsTrailingClosure,
		   let closurePair = callExpression.arguments.pairs.last,
		   let closureExpression = closurePair.expression as? ClosureExpression,
		   closureExpression.isTrailing
		{
			let closureTranslation = try translateClosureExpression(
				closureExpression,
				withIndentation: indentation)
			if callExpression.arguments.pairs.count > 1 {
				let newTupleExpression = TupleExpression(
					syntax: callExpression.arguments.syntax,
					range: callExpression.arguments.range,
					pairs: callExpression.arguments.pairs.dropLast().toMutableList())

				let firstParametersTranslation = try translateTupleExpression(
					newTupleExpression,
					withIndentation: increaseIndentation(indentation),
					shouldAddNewlines: shouldAddNewlines)

				let result = KotlinTranslation(range: callExpression.range)
				result.append(firstParametersTranslation)
				result.append(" ")
				result.append(closureTranslation)
				return result
			}
			else {
				let result = KotlinTranslation(range: callExpression.range)
				result.append(" ")
				result.append(closureTranslation)
				return result
			}
		}

		return try translateTupleExpression(
			callExpression.arguments,
			withIndentation: increaseIndentation(indentation),
			shouldAddNewlines: shouldAddNewlines)
	}

	private func translateClosureExpression(
		_ closureExpression: ClosureExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		guard !closureExpression.statements.isEmpty else {
			return KotlinTranslation(range: closureExpression.range, string: "{ }")
		}

		let result = KotlinTranslation(range: closureExpression.range)
		result.append("{")

		let parametersString = closureExpression.parameters.map{ $0.label }.joined(separator: ", ")

		if !parametersString.isEmpty {
			result.append(" ")
			result.append(parametersString)
			result.append(" ->")
		}

		let firstStatement = closureExpression.statements.first
		if closureExpression.statements.count == 1,
			let firstStatement = firstStatement,
			let expressionStatement = firstStatement as? ExpressionStatement
		{
			result.append(" ")
			result.append(try translateExpression(
				expressionStatement.expression,
				withIndentation: indentation))
			result.append(" }")
		}
		else {
			result.append("\n")
			let closingBraceIndentation = increaseIndentation(indentation)
			let contentsIndentation = increaseIndentation(closingBraceIndentation)
			result.append(try translateSubtrees(
				closureExpression.statements,
				withIndentation: contentsIndentation))
			result.append(closingBraceIndentation + "}")
		}

		return result
	}

	private func translateLiteralCodeExpression(
		_ literalCodeExpression: LiteralCodeExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		return KotlinTranslation(
			range: literalCodeExpression.range,
			string: literalCodeExpression.string.removingBackslashEscapes)
	}

	private func translateConcatenationExpression(
		_ expression: ConcatenationExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let result = KotlinTranslation(range: expression.range)
		try result.append(
			translateExpression(expression.leftExpression, withIndentation: indentation))
		try result.append(
			translateExpression(expression.rightExpression, withIndentation: indentation))
		return result
	}

	private func translateDeclarationReferenceExpression(
		_ declarationReferenceExpression: DeclarationReferenceExpression)
		-> KotlinTranslation
	{
		return KotlinTranslation(
			range: declarationReferenceExpression.range,
			string: String(declarationReferenceExpression.identifier.prefix { $0 != "(" }))
	}

	private func translateTupleExpression(
		_ tupleExpression: TupleExpression,
		withIndentation indentation: String,
		shouldAddNewlines: Bool = false)
		throws -> KotlinTranslation
	{
		guard !tupleExpression.pairs.isEmpty else {
			return KotlinTranslation(
				range: tupleExpression.range,
				string: "()")
		}

		let expressionIndentation =
			shouldAddNewlines ? increaseIndentation(indentation) : indentation

		let translations = try tupleExpression.pairs
			.map { pair -> KotlinTranslation in
				try translateParameter(
					withLabel: pair.label,
					expression: pair.expression,
					indentation: expressionIndentation)
			}

		let result = KotlinTranslation(range: tupleExpression.range)
		result.append("(")

		if !shouldAddNewlines {
			result.appendTranslations(translations, withSeparator: ", ")
		}
		else {
			result.append("\n\(indentation)")
			result.appendTranslations(translations, withSeparator: ",\n\(indentation)")
		}

		result.append(")")

		return result
	}

	private func translateParameter(
		withLabel label: String?,
		expression: Expression,
		indentation: String)
		throws -> KotlinTranslation
	{
		let translatedExpression = try translateExpression(expression, withIndentation: indentation)

		if let label = label {
			let result = KotlinTranslation(range: expression.range)
			result.append(label)
			result.append(" = ")
			result.append(translatedExpression)
			return result
		}
		else {
			return translatedExpression
		}
	}

	private func indexIsVariadic(_ index: TupleShuffleIndex) -> Bool {
		if case .variadic = index {
			return true
		}
		else {
			return false
		}
	}

	private func translateStringLiteral(
		_ literalStringExpression: LiteralStringExpression)
		-> KotlinTranslation
	{
		if literalStringExpression.isMultiline {
			let processedString = literalStringExpression.value.removingBackslashEscapes
			let result = KotlinTranslation(range: literalStringExpression.range)
			result.append("\"\"\"")
			result.append(processedString)
			result.append("\"\"\"")
			return result
		}
		else {
			let result = KotlinTranslation(range: literalStringExpression.range)
			result.append("\"")
			result.append(literalStringExpression.value)
			result.append("\"")
			return result
		}
	}

	private func translateCharacterLiteral(
		_ literalCharacterExpression: LiteralCharacterExpression)
		-> KotlinTranslation
	{
		let result = KotlinTranslation(range: literalCharacterExpression.range)
		result.append("'")
		result.append(literalCharacterExpression.value)
		result.append("'")
		return result
	}

	private func translateInterpolatedStringLiteralExpression(
		_ interpolatedStringLiteralExpression: InterpolatedStringLiteralExpression,
		withIndentation indentation: String)
		throws -> KotlinTranslation
	{
		let isMultiline = interpolatedStringLiteralExpression.isMultiline
		let delimiter = isMultiline ? "\"\"\"" : "\""

		let result = KotlinTranslation(
			range: interpolatedStringLiteralExpression.range,
			string: delimiter)

		for expression in interpolatedStringLiteralExpression.expressions {
			if let literalStringExpression = expression as? LiteralStringExpression {
				if isMultiline {
					let processedString = literalStringExpression.value.removingBackslashEscapes
					result.append(processedString)
				}
				else {
					result.append(literalStringExpression.value)
				}
			}
			else {
				result.append("${")
				result.append(try translateExpression(expression, withIndentation: indentation))
				result.append("}")
			}
		}

		result.append(delimiter)
		return result
	}

	// MARK: - Supporting methods

	internal func translateType(_ typeName: String) -> String {
		let typeName = typeName
				.replacingOccurrences(of: "()", with: "Unit")
				.replacingOccurrences(of: "Void", with: "Unit")

		if let mappedType = Utilities.getTypeMapping(for: typeName) {
			return mappedType
		}
		else if typeName.hasSuffix("?") {
			// Optionals
			return translateType(String(typeName.dropLast())) + "?"
		}
		else if typeName.hasPrefix("[") {
			if typeName.contains(":") {
				// Dictionaries
				let innerType = String(typeName.dropLast().dropFirst())
				let innerTypes = Utilities.splitTypeList(innerType)
				let keyType = innerTypes[0]
				let valueType = innerTypes[1]
				let translatedKey = translateType(keyType)
				let translatedValue = translateType(valueType)
				return "Map<\(translatedKey), \(translatedValue)>"
			}
			else {
				// Arrays
				let innerType = String(typeName.dropLast().dropFirst())
				let translatedInnerType = translateType(innerType)
				return "List<\(translatedInnerType)>"
			}
		}
		else if typeName.hasPrefix("Array<"), typeName.hasSuffix(">") {
			let innerType = String(typeName.dropFirst("Array<".count).dropLast())
			let translatedInnerType = translateType(innerType)
			return "List<\(translatedInnerType)>"
		}
		else if typeName.hasPrefix("Dictionary<"), typeName.hasSuffix(">") {
			let innerType = String(typeName.dropFirst("Dictionary<".count).dropLast())
			let innerTypes = Utilities.splitTypeList(innerType, separators: [","])
			let keyType = innerTypes[0]
			let valueType = innerTypes[1]
			let translatedKey = translateType(keyType)
			let translatedValue = translateType(valueType)
			return "Map<\(translatedKey), \(translatedValue)>"
		}
		else if let genericInformation = getGenericTypeInformation(for: typeName) {
			// Generics

			// Example: "Map<Int, Int>"
			let baseType = genericInformation.0 // "Map"
			let genericTypesString = genericInformation.1 // "Int, Int"

			let translatedBastType = translateType(baseType)

			let genericTypes = Utilities.splitTypeList(genericTypesString, separators: [","])
			let translatedGenerics = genericTypes.map { translateType($0) }
			let translatedGenericsString = translatedGenerics.joined(separator: ", ")

			return "\(translatedBastType)<\(translatedGenericsString)>"
		}
		else if Utilities.isInEnvelopingParentheses(typeName) {
			// Tuples
			let innerTypeString = String(typeName.dropFirst().dropLast())
			let innerTypes = Utilities.splitTypeList(innerTypeString, separators: [", "])
			if innerTypes.count == 2 {
				// If it's a named tuple, use only the types
				let translatedTypes = innerTypes.map {
					translateType(Utilities.splitTypeList($0, separators: [":"]).last!)
				}

				return "Pair<\(translatedTypes.joined(separator: ", "))>"
			}
			else {
				return "(" + translateType(String(typeName.dropFirst().dropLast())) + ")"
			}
		}
		else if typeName.contains(" -> ") {
			// Functions
			let functionComponents = Utilities.splitTypeList(typeName, separators: [" -> "])
			let translatedComponents = functionComponents.map {
				translateFunctionTypeComponent($0)
			}

			let firstTypes = translatedComponents.dropLast()
				.map { $0 == "Unit" ? "" : $0 }
				.map { "(\($0))" }
			let lastType = translatedComponents.last!

			let allTypes = firstTypes.toMutableList()
			allTypes.append(lastType)
			return allTypes.joined(separator: " -> ")
		}
		else if typeName.hasSuffix(" throws") {
			let cleanType = typeName.dropLast(" throws".count)
			return translateType(String(cleanType))
		}
		else {
			return typeName
		}
	}

	// If the given string represents a generic type, returns its base type and generic contents
	// (e.g. returns `("A", "Int, Int")` for `A<Int, Int>`). Otherwise, returns `nil`.
	private func getGenericTypeInformation(for typeName: String) -> (String, String)? {
		let baseType = String(typeName.prefix(while: {
			!$0.isPunctuation &&
			$0 != "<" &&
			$0 != "[" &&
			$0 != "," &&
			$0 != ":" }))
		let genericsWithBrackets = typeName.dropFirst(baseType.count)

		if genericsWithBrackets.first == "<",
			genericsWithBrackets.last == ">"
		{
			let generics = String(genericsWithBrackets.dropFirst().dropLast())
			return (baseType, generics)
		}
		else {
			return nil
		}
	}

	private func translateFunctionTypeComponent(_ component: String) -> String {
		if component.hasSuffix(")throws") {
			return translateFunctionTypeComponent(String(component.dropLast("throws".count)))
		}

		if Utilities.isInEnvelopingParentheses(component) {
			let openComponent = String(component.dropFirst().dropLast())
			let componentParts = Utilities.splitTypeList(openComponent, separators: [", "])
			let translatedParts = componentParts.map { translateType($0) }
			return translatedParts.joined(separator: ", ")
		}
		else {
			return translateType(component)
		}
	}

	private func increaseIndentation(_ indentation: String) -> String {
		return indentation + self.context.indentationString
	}

	private func decreaseIndentation(_ indentation: String) -> String {
		return String(indentation.dropLast(self.context.indentationString.count))
	}

	private func unexpectedASTStructureError(
		_ errorMessage: String,
		AST ast: Statement)
		throws -> KotlinTranslation
	{
		let message = "failed to translate Gryphon AST into Kotlin: " + errorMessage + "."

		try Compiler.handleError(
			message: message,
			ast: ast,
			sourceFile: sourceFile,
			sourceFileRange: ast.range)
		return KotlinTranslation(range: ast.range, string: KotlinTranslator.errorTranslation)
	}
}
