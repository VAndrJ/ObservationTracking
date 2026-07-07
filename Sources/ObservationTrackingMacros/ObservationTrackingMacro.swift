import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

private struct Assignment {
    let property: String
    let value: String
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
        let isolation = node.isolation
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
        }

        return peerFunctions
    }

    private static func validateObservationTrackingTarget(
        _ functionDecl: FunctionDeclSyntax,
        context: some MacroExpansionContext
    ) throws {
        guard isValidObservationTrackingTarget(functionDecl, context: context) else {
            throw MacroExpansionErrorMessage("@ObservationTracking can only be applied to instance methods declared in classes")
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
            syntax.is(ClassDeclSyntax.self)
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
                classDecl.attributes.contains(where: { $0.description.contains(cancellableObservation) })
            {
                return true
            }
        }

        return false
    }

    private static func generateFunctionObserverFunction(
        name: String,
        assignment: (function: String, argument: String),
        withCancellation: Bool,
        isolation: OnChangeBlockIsolation
    ) -> DeclSyntax {
        let functionCall = assignment.function.replacingOccurrences(
            of: assignment.argument,
            with: """

                withObservationTracking {
                    \(assignment.argument)
                } onChange: { [weak self] in
                    \(generateTask(isolation: isolation, withCancellation: withCancellation, name: name))
                }

                """
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
        case .actor:
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

    private static func findFunctionInStatement(_ statement: CodeBlockItemSyntax) -> (function: String, argument: String)? {
        if let functionCall = statement.item.as(FunctionCallExprSyntax.self) {
            let nonLiteralArguments = functionCall.arguments.compactMap { argument -> String? in
                let expr = argument.expression
                if !isLiteralExpression(expr) {
                    return expr.description.trimmingCharacters(in: functionArgumentDescriptionTrimSet)
                } else {
                    return nil
                }
            }

            if nonLiteralArguments.count == 1, let argumentDescription = nonLiteralArguments.first {
                return (functionCall.description.trimmingCharacters(in: .whitespacesAndNewlines), argumentDescription)
            }
        }

        return nil
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
        let valueExpression = removeComments(from: value)

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
    /// - Returns: The OnChangeBlockIsolation enum value, defaulting to .mainActor if not specified
    fileprivate var isolation: OnChangeBlockIsolation {
        guard case let .argumentList(arguments) = arguments else {
            return .mainActor
        }

        for argument in arguments {
            if let label = argument.label, label.text == "isolation" {
                let expressionText = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if expressionText.contains("mainActor") {
                    return .mainActor
                } else if expressionText.contains("synchronous") || expressionText.contains("none") {
                    return .synchronous
                } else if expressionText.contains("actor") {
                    return .actor
                }
            }
        }

        return .mainActor
    }
}

private enum OnChangeBlockIsolation {
    case mainActor
    case actor
    case synchronous
}

extension Character {
    fileprivate var isAssignmentAdjacentOperator: Bool {
        "=!<>+-*/%&|^?".contains(self)
    }
}

extension String {
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
