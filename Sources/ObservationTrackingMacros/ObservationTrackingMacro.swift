import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

private struct Assignment {
    let property: String
    let value: String
}

private struct FunctionCallObservation {
    let function: String
    let functionCall: FunctionCallExprSyntax
    let observedArgumentIndex: Int
}

private struct ControlFlowObservation {
    let observedName: String
    let statement: String
}

public struct ObservationTrackingMacro: BodyMacro, PeerMacro {
    static let cancellableObservation = "CancellableObservation"

    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let functionDecl = declaration.as(FunctionDeclSyntax.self),
            let body = functionDecl.body
        else {
            throw MacroExpansionErrorMessage("@ObservationTracking can only be applied to functions with a body")
        }
        try validateObservationTrackingTarget(functionDecl, context: context)

        var newStatements: [CodeBlockItemSyntax] = []
        var usedObserverNames: [String: Int] = [:]
        for statement in body.statements {
            if let assignment = findAssignmentInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: assignment.property,
                    usedNames: &usedObserverNames
                )
                newStatements.append("\(raw: observeFunctionName)()")
            } else if let assignment = findFunctionInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: assignment.function,
                    usedNames: &usedObserverNames
                )
                newStatements.append("\(raw: observeFunctionName)()")
            } else if let observation = findControlFlowObservationInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: observation.observedName,
                    usedNames: &usedObserverNames
                )
                newStatements.append("\(raw: observeFunctionName)()")
            } else {
                newStatements.append(statement)
            }
        }

        return newStatements
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let functionDecl = declaration.as(FunctionDeclSyntax.self),
            let body = functionDecl.body
        else {
            throw MacroExpansionErrorMessage("@ObservationTracking can only be applied to functions with a body")
        }
        guard isValidObservationTrackingTarget(functionDecl, context: context) else {
            return []
        }

        var peerFunctions: [DeclSyntax] = []
        var usedObserverNames: [String: Int] = [:]
        let hasCancellableObservation = hasParentWithCancellableObservation(context: context)
        let isolation = node.isolation(defaultingToTask: isInActorContext(context: context))
        for statement in body.statements {
            if let assignment = findAssignmentInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: assignment.property,
                    usedNames: &usedObserverNames
                )
                let observerFunction = generateObserverFunction(
                    name: observeFunctionName,
                    assignment: assignment,
                    withCancellation: hasCancellableObservation,
                    isolation: isolation
                )
                peerFunctions.append(observerFunction)
                if hasCancellableObservation {
                    peerFunctions.append(
                        """
                        func \(raw: generateCancelObserverFunctionName(from: observeFunctionName))() {
                            observationTokens.removeValue(forKey: "\(raw: observeFunctionName)")
                        }
                        """
                    )
                }
            }
            if let assignment = findFunctionInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: assignment.function,
                    usedNames: &usedObserverNames
                )
                let observerFunction = generateFunctionObserverFunction(
                    name: observeFunctionName,
                    assignment: assignment,
                    withCancellation: hasCancellableObservation,
                    isolation: isolation
                )
                peerFunctions.append(observerFunction)
                if hasCancellableObservation {
                    peerFunctions.append(
                        """
                        func \(raw: generateCancelObserverFunctionName(from: observeFunctionName))() {
                            observationTokens.removeValue(forKey: "\(raw: observeFunctionName)")
                        }
                        """
                    )
                }
            }
            if let observation = findControlFlowObservationInStatement(statement) {
                let observeFunctionName = makeUniqueObserverFunctionName(
                    from: observation.observedName,
                    usedNames: &usedObserverNames
                )
                let observerFunction = generateControlFlowObserverFunction(
                    name: observeFunctionName,
                    observation: observation,
                    withCancellation: hasCancellableObservation,
                    isolation: isolation
                )
                peerFunctions.append(observerFunction)
                if hasCancellableObservation {
                    peerFunctions.append(
                        """
                        func \(raw: generateCancelObserverFunctionName(from: observeFunctionName))() {
                            observationTokens.removeValue(forKey: "\(raw: observeFunctionName)")
                        }
                        """
                    )
                }
            }
        }

        return peerFunctions
    }

    private static func validateObservationTrackingTarget(
        _ functionDecl: FunctionDeclSyntax,
        context: some MacroExpansionContext
    ) throws {
        guard isValidObservationTrackingTarget(functionDecl, context: context) else {
            throw MacroExpansionErrorMessage("@ObservationTracking can only be applied to instance methods declared in classes, actors, or extensions")
        }
    }

    private static func isValidObservationTrackingTarget(
        _ functionDecl: FunctionDeclSyntax,
        context: some MacroExpansionContext
    ) -> Bool {
        if functionDecl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
            return false
        }

        let lexicalContext = context.lexicalContext
        guard !lexicalContext.isEmpty else {
            return true
        }

        return lexicalContext.contains { syntax in
            syntax.is(ClassDeclSyntax.self) || syntax.is(ActorDeclSyntax.self) || syntax.is(ExtensionDeclSyntax.self)
        }
    }

    private static func isInActorContext(context: some MacroExpansionContext) -> Bool {
        context.lexicalContext.contains { syntax in
            syntax.is(ActorDeclSyntax.self)
        }
    }

    private static func makeUniqueObserverFunctionName(
        from propertyName: String,
        usedNames: inout [String: Int]
    ) -> String {
        let baseName = generateObserverFunctionName(from: propertyName)
        let count = usedNames[baseName, default: 0]
        usedNames[baseName] = count + 1

        if count == 0 {
            return baseName
        }

        return "\(baseName)\(count + 1)"
    }

    private static func generateCancelObserverFunctionName(from observeFunctionName: String) -> String {
        "cancel" + observeFunctionName.capitalizedFirstLetter
    }

    private static func hasParentWithCancellableObservation(
        context: some MacroExpansionContext
    ) -> Bool {
        let lexicalContext: [Syntax] = context.lexicalContext
        for syntax in lexicalContext {
            if let classDecl = syntax.as(ClassDeclSyntax.self),
                classDecl.attributes.contains(where: { $0.hasAttributeName(cancellableObservation) })
            {
                return true
            }
        }

        return false
    }

    private static func generateControlFlowObserverFunction(
        name: String,
        observation: ControlFlowObservation,
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation
    ) -> DeclSyntax {
        let statement = observation.statement.indented(by: 8)
        let task = generateTask(isolation: isolation, withCancellation: withCancellation, name: name)
            .expandedGeneratedTask
            .indented(by: 8)
        if withCancellation {
            return """
                func \(raw: name)() {
                    guard isObservingEnabled else {
                        return
                    }

                    let token = UUID().uuidString
                    observationTokens["\(raw: name)"] = token
                    withObservationTracking {
                \(raw: statement)
                    } onChange: { [weak self] in
                \(raw: task)
                    }
                }
                """
        } else {
            return """
                private func \(raw: name)() {
                    withObservationTracking {
                \(raw: statement)
                    } onChange: { [weak self] in
                \(raw: task)
                    }
                }
                """
        }
    }

    private static func generateFunctionObserverFunction(
        name: String,
        assignment: FunctionCallObservation,
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation
    ) -> DeclSyntax {
        let functionCall = makeObservedFunctionCall(
            assignment.functionCall,
            observedArgumentIndex: assignment.observedArgumentIndex,
            withCancellation: withCancellation,
            isolation: isolation,
            name: name
        )
        if withCancellation {
            return """
                func \(raw: name)() {
                    guard isObservingEnabled else { 
                        return
                    }
                    
                    let token = UUID().uuidString
                    observationTokens["\(raw: name)"] = token
                    \(raw: functionCall)
                }
                """
        } else {
            return """
                private func \(raw: name)() {
                    \(raw: functionCall)
                }
                """
        }
    }

    private static func makeObservedFunctionCall(
        _ functionCall: FunctionCallExprSyntax,
        observedArgumentIndex: Int,
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation,
        name: String
    ) -> String {
        let calledExpression = functionCall.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = Array(functionCall.arguments)
        let renderedArguments = arguments.enumerated().map { index, argument in
            if index == observedArgumentIndex {
                return makeObservedFunctionArgument(
                    argument,
                    withCancellation: withCancellation,
                    isolation: isolation,
                    name: name
                )
            }

            return argument.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "\(calledExpression)(\n\(renderedArguments.map { $0.indented(by: 8) }.joined(separator: ",\n"))\n    )"
    }

    private static func makeObservedFunctionArgument(
        _ argument: LabeledExprSyntax,
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation,
        name: String
    ) -> String {
        let label = argument.label.map { "\($0.text): " } ?? ""
        let observedExpression = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = generateTask(isolation: isolation, withCancellation: withCancellation, name: name)
            .expandedGeneratedTask
            .indented(by: 4)

        return """
            \(label)withObservationTracking {
                \(observedExpression)
            } onChange: { [weak self] in
            \(task)
            }
            """
    }

    private static func generateTask(
        isolation: OnChangeBlockIsolation,
        withCancellation: Bool,
        name: String
    ) -> String {
        return switch isolation {
        case .mainActor:
            if withCancellation {
                "Task { @MainActor in guard let self, token == self.observationTokens[\"\(name)\"] else { return } self.\(name)() }"
            } else {
                "Task { @MainActor in self?.\(name)() }"
            }
        case .task:
            if withCancellation {
                "Task { guard let self, await token == self.observationTokens[\"\(name)\"] else { return } await self.\(name)() }"
            } else {
                "Task { await self?.\(name)() }"
            }
        case .synchronous:
            if withCancellation {
                "guard let self, token == self.observationTokens[\"\(name)\"] else { return } self.\(name)()"
            } else {
                "self?.\(name)()"
            }
        }
    }

    private static func generateObserverFunction(
        name: String,
        assignment: Assignment,
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation
    ) -> DeclSyntax {
        if withCancellation {
            return """
                func \(raw: name)() {
                    guard isObservingEnabled else { 
                        return
                    }
                    
                    let token = UUID().uuidString
                    observationTokens["\(raw: name)"] = token
                    \(raw: assignment.property) = withObservationTracking {
                        \(raw: assignment.value)
                    } onChange: { [weak self] in
                        \(raw: generateTask(isolation: isolation, withCancellation: withCancellation, name: name))
                    }
                }
                """
        } else {
            return """
                private func \(raw: name)() {
                    \(raw: assignment.property) = withObservationTracking {
                        \(raw: assignment.value)
                    } onChange: { [weak self] in
                        \(raw: generateTask(isolation: isolation, withCancellation: withCancellation, name: name))
                    }
                }
                """
        }
    }

    private static func findControlFlowObservationInStatement(_ statement: CodeBlockItemSyntax) -> ControlFlowObservation? {
        guard let ifExpression = ifExpression(from: statement),
            let assignment = firstAssignment(in: ifExpression)
        else {
            return nil
        }

        return ControlFlowObservation(
            observedName: assignment.property,
            statement: ifExpression.description.trimmingCharacters(in: .whitespacesAndNewlines).removingOneIndentLevelFromContinuation
        )
    }

    private static func ifExpression(from statement: CodeBlockItemSyntax) -> IfExprSyntax? {
        if let ifExpression = statement.item.as(IfExprSyntax.self) {
            return ifExpression
        }
        if let ifExpression = statement.item.as(ExprSyntax.self)?.as(IfExprSyntax.self) {
            return ifExpression
        }

        return statement.item.as(ExpressionStmtSyntax.self)?.expression.as(IfExprSyntax.self)
    }

    private static func firstAssignment(in ifExpression: IfExprSyntax) -> Assignment? {
        if let assignment = firstAssignment(in: ifExpression.body.statements) {
            return assignment
        }

        guard let elseBody = ifExpression.elseBody else {
            return nil
        }

        switch elseBody {
        case .ifExpr(let elseIfExpression):
            return firstAssignment(in: elseIfExpression)
        case .codeBlock(let codeBlock):
            return firstAssignment(in: codeBlock.statements)
        }
    }

    private static func firstAssignment(in statements: CodeBlockItemListSyntax) -> Assignment? {
        for statement in statements {
            if let assignment = findAssignmentInStatement(statement) {
                return assignment
            }
            if let ifExpression = ifExpression(from: statement),
                let assignment = firstAssignment(in: ifExpression)
            {
                return assignment
            }
        }

        return nil
    }

    private static func findFunctionInStatement(_ statement: CodeBlockItemSyntax) -> FunctionCallObservation? {
        guard let functionCall = statement.item.as(FunctionCallExprSyntax.self) else {
            return nil
        }

        let nonLiteralArgumentIndexes = functionCall.arguments.enumerated().compactMap { index, argument -> Int? in
            isLiteralExpression(argument.expression) ? nil : index
        }

        guard nonLiteralArgumentIndexes.count == 1, let observedArgumentIndex = nonLiteralArgumentIndexes.first else {
            return nil
        }

        return FunctionCallObservation(
            function: functionCall.description.trimmingCharacters(in: .whitespacesAndNewlines),
            functionCall: functionCall,
            observedArgumentIndex: observedArgumentIndex
        )
    }

    /// Checks if the given expression is a literal (string, int, bool, etc.)
    ///
    /// - Parameter expression: The expression to check
    /// - Returns: True if the expression is a literal, false otherwise
    private static func isLiteralExpression(_ expression: ExprSyntax) -> Bool {
        return expression.is(StringLiteralExprSyntax.self)
            || expression.is(IntegerLiteralExprSyntax.self)
            || expression.is(FloatLiteralExprSyntax.self)
            || expression.is(BooleanLiteralExprSyntax.self)
            || expression.is(NilLiteralExprSyntax.self)
            || expression.is(ArrayExprSyntax.self)
            || expression.is(DictionaryExprSyntax.self)
            || expression.is(TupleExprSyntax.self)
    }

    private static func findAssignmentInStatement(_ statement: CodeBlockItemSyntax) -> Assignment? {
        if let assignment = syntaxAssignment(from: statement) {
            return assignment
        }

        return fallbackTextAssignment(from: statement)
    }

    private static func syntaxAssignment(from statement: CodeBlockItemSyntax) -> Assignment? {
        if let infixExpression = statement.item.as(InfixOperatorExprSyntax.self),
            isSimpleAssignmentOperator(infixExpression.operator)
        {
            return makeAssignment(
                property: infixExpression.leftOperand.description,
                value: infixExpression.rightOperand.description
            )
        }

        guard let sequenceExpression = statement.item.as(SequenceExprSyntax.self) else {
            return nil
        }

        let elements = Array(sequenceExpression.elements)
        guard let assignmentIndex = elements.firstIndex(where: isSimpleAssignmentOperator),
            assignmentIndex > elements.startIndex,
            assignmentIndex < elements.index(before: elements.endIndex)
        else {
            return nil
        }

        return makeAssignment(
            property: elements[..<assignmentIndex].map(\.description).joined(),
            value: elements[elements.index(after: assignmentIndex)...].map(\.description).joined()
        )
    }

    private static func fallbackTextAssignment(from statement: CodeBlockItemSyntax) -> Assignment? {
        let statementText = statement.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !statementText.isUnsupportedAssignmentCandidate,
            let assignmentIndex = statementText.firstSimpleAssignmentOperatorIndex
        else {
            return nil
        }

        return makeAssignment(
            property: String(statementText[..<assignmentIndex]),
            value: String(statementText[statementText.index(after: assignmentIndex)...])
        )
    }

    private static func isSimpleAssignmentOperator(_ expression: ExprSyntax) -> Bool {
        expression.description.trimmingCharacters(in: .whitespacesAndNewlines) == "="
    }

    private static func makeAssignment(property: String, value: String) -> Assignment? {
        let propertyName = removeComments(from: property)
        var valueExpression = removeComments(from: value)
        if valueExpression.hasPrefix("if ") {
            valueExpression = valueExpression.addingOneIndentLevelToContinuation
        }

        if !propertyName.isEmpty && !valueExpression.isEmpty {
            return Assignment(property: propertyName, value: valueExpression)
        }

        return nil
    }

    private static let functionArgumentDescriptionTrimSet = CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ","))

    /// Removes single-line and multi-line comments from the given text.
    ///
    /// This helper function strips both `//` single-line comments and `/* */` multi-line comments
    /// from the input text to ensure proper assignment detection.
    ///
    /// - Parameter text: The input text that may contain comments
    /// - Returns: The text with comments removed
    private static func removeComments(from text: String) -> String {
        var result = text
        if let singleLineCommentRange = result.range(of: "//"),
            let newlineRange = result.range(of: "\n", range: singleLineCommentRange.upperBound..<result.endIndex)
        {
            result = String(result[newlineRange.upperBound...])
        }
        while let startRange = result.range(of: "/*"),
            let endRange = result.range(of: "*/", range: startRange.upperBound..<result.endIndex)
        {
            let commentRange = startRange.lowerBound..<endRange.upperBound
            result.removeSubrange(commentRange)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generates a formatted observer function name from a property name.
    ///
    /// This function takes a property name and converts it into a camelCase observer function name
    /// by prefixing it with "observe" and capitalizing each segment of dot notation properties.
    /// For example, "titleLabel.text" becomes "observeTitleLabelText".
    ///
    /// - Parameter propertyName: The original property name (e.g., "intValue", "userName", "titleLabel.text")
    /// - Returns: A formatted observer function name (e.g., "observeIntValue", "observeUserName", "observeTitleLabelText")
    ///
    /// ## Examples:
    ///
    /// ```swift
    /// generateObserverFunctionName(from: "count") // Returns: "observeCount"
    /// generateObserverFunctionName(from: "userName") // Returns: "observeUserName"
    /// generateObserverFunctionName(from: "isEnabled") // Returns: "observeIsEnabled"
    /// generateObserverFunctionName(from: "titleLabel.text") // Returns: "observeTitleLabelText"
    /// generateObserverFunctionName(from: "array[index]") // Returns: "observeArrayIndex"
    /// generateObserverFunctionName(from: "dictionary[\"key\"]") // Returns: "observeDictionaryKey"
    /// generateObserverFunctionName(from: "settings[\"theme\"]") // Returns: "observeSettingsTheme"
    /// generateObserverFunctionName(from: "data.items[0]") // Returns: "observeDataItems0"
    /// ```
    private static func generateObserverFunctionName(
        from propertyName: String,
        isCancel: Bool = false
    ) -> String {
        var processedPropertyName = propertyName
        let subscriptPattern = #"([a-zA-Z_$][a-zA-Z0-9_$]*)\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: subscriptPattern, options: []) {
            let range = NSRange(processedPropertyName.startIndex..., in: processedPropertyName)
            processedPropertyName = regex.stringByReplacingMatches(
                in: processedPropertyName,
                options: [],
                range: range,
                withTemplate: "$1$2"
            )
        }
        let segments = processedPropertyName.components(separatedBy: ".")
        let capitalizedSegments =
            segments
            .map { segment in
                let cleanSegment = segment.filter { $0.isLetter || $0.isNumber }
                return cleanSegment.capitalizedFirstLetter
            }
            .filter { !$0.isEmpty }

        return (isCancel ? "cancelObserve" : "observe") + capitalizedSegments.joined()
    }
}

extension AttributeSyntax {
    /// Extracts the isolation parameter from the ObservationTracking attribute.
    ///
    /// Parses the attribute arguments to find the isolation parameter and returns
    /// the corresponding OnChangeBlockIsolation value.
    ///
    /// - Parameter defaultingToTask: Uses task isolation when no explicit isolation is provided.
    /// - Returns: The OnChangeBlockIsolation enum value, defaulting to .mainActor for classes and .task for actors.
    fileprivate func isolation(defaultingToTask: Bool) -> OnChangeBlockIsolation {
        guard case let .argumentList(arguments) = arguments else {
            return defaultingToTask ? .task : .mainActor
        }

        for argument in arguments {
            if let label = argument.label, label.text == "isolation" {
                let expressionText = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if expressionText.contains("mainActor") {
                    return .mainActor
                } else if expressionText.contains("synchronous") || expressionText.contains("none") {
                    return .synchronous
                } else if expressionText.contains("task") || expressionText.contains("actor") {
                    return .task
                }
            }
        }

        return defaultingToTask ? .task : .mainActor
    }
}

private enum OnChangeBlockIsolation {
    case mainActor
    case task
    case synchronous
}

extension Character {
    fileprivate var isAssignmentAdjacentOperator: Bool {
        "=!<>+-*/%&|^?".contains(self)
    }
}

extension String {
    fileprivate func indented(by spaces: Int) -> String {
        let indentation = String(repeating: " ", count: spaces)
        return split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : indentation + $0 }
            .joined(separator: "\n")
    }

    fileprivate var removingOneIndentLevelFromContinuation: String {
        let lines = split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else {
            return self
        }

        let normalizedLines = [lines[0]] + lines.dropFirst().map { line in
            line.hasPrefix("    ") ? String(line.dropFirst(4)) : line
        }
        return normalizedLines.joined(separator: "\n")
    }

    fileprivate var addingOneIndentLevelToContinuation: String {
        let lines = split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else {
            return self
        }

        let normalizedLines = [lines[0]] + lines.dropFirst().map { line in
            line.isEmpty ? line : "    " + line
        }
        return normalizedLines.joined(separator: "\n")
    }

    fileprivate var expandedGeneratedTask: String {
        if hasPrefix("Task { @MainActor in "), hasSuffix(" }") {
            let inner = dropPrefix("Task { @MainActor in ").dropSuffix(" }").expandedGeneratedGuard
            return """
                Task { @MainActor in
                \(inner.indented(by: 4))
                }
                """
        }

        if hasPrefix("Task { "), hasSuffix(" }") {
            let inner = dropPrefix("Task { ").dropSuffix(" }").expandedGeneratedGuard
            return """
                Task {
                \(inner.indented(by: 4))
                }
                """
        }

        return expandedGeneratedGuard
    }

    private var expandedGeneratedGuard: String {
        guard let elseRange = range(of: " else { return } ") else {
            return self
        }

        let condition = self[..<elseRange.lowerBound]
        let continuation = self[elseRange.upperBound...]
        return """
            \(condition) else {
                return
            }
            \(continuation)
            """
    }

    private func dropPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    private func dropSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }

    fileprivate var isUnsupportedAssignmentCandidate: Bool {
        let unsupportedPrefixes = [
            "@", "let ", "var ", "private ", "fileprivate ", "internal ", "public ", "open ", "static ", "class ",
            "if ", "guard ", "while ", "for ", "switch ", "defer ", "return ",
        ]
        return unsupportedPrefixes.contains { hasPrefix($0) }
    }

    fileprivate var firstSimpleAssignmentOperatorIndex: String.Index? {
        var index = startIndex
        while index < endIndex {
            guard self[index] == "=" else {
                formIndex(after: &index)
                continue
            }

            let previousCharacter = index > startIndex ? self[self.index(before: index)] : nil
            let nextIndex = self.index(after: index)
            let nextCharacter = nextIndex < endIndex ? self[nextIndex] : nil

            if previousCharacter?.isAssignmentAdjacentOperator != true
                && nextCharacter?.isAssignmentAdjacentOperator != true
            {
                return index
            }

            formIndex(after: &index)
        }

        return nil
    }

    /// Returns a new string with the first letter capitalized while preserving the rest of the string.
    ///
    /// This computed property is specifically designed for converting property names to proper
    /// camelCase format when generating function names.
    ///
    /// - Returns: A string with the first character uppercased
    ///
    /// ## Examples:
    ///
    /// ```swift
    /// "userName".capitalizedFirstLetter // Returns: "UserName"
    /// "count".capitalizedFirstLetter // Returns: "Count"
    /// "isEnabled".capitalizedFirstLetter // Returns: "IsEnabled"
    /// "".capitalizedFirstLetter // Returns: ""
    /// ```
    fileprivate var capitalizedFirstLetter: String {
        return if isEmpty {
            self
        } else {
            prefix(1).uppercased() + dropFirst()
        }
    }
}

@main
struct ObservationTrackingPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservationTrackingMacro.self,
        CancellableObservationMacro.self,
        StartObservationsMacro.self,
        StopObservationsMacro.self,
    ]
}
