import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CancellableObservationMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@CancellableObservation can only be applied to classes")
        }

        let observationTrackingFunctions = findObservationTrackingFunctions(in: classDecl)
        let functionCalls = observationTrackingFunctions.map { "\($0)()" }.joined(separator: "\n")
        let startObservationsBody =
            if functionCalls.isEmpty {
                """
                func startObservationsIfNeeded() {
                    guard !isObservingEnabled else {
                        return
                    }
                    isObservingEnabled = true
                }
                """
            } else {
                """
                func startObservationsIfNeeded() {
                    guard !isObservingEnabled else {
                        return
                    }
                    isObservingEnabled = true
                    \(functionCalls)
                }
                """
            }

        return [
            """
            private var observationTokens: [String: String] = [:]
            private var isObservingEnabled = true

            func stopObservations() {
                isObservingEnabled = false
                observationTokens.removeAll()
            }

            \(raw: startObservationsBody)
            """
        ]
    }

    private static func findObservationTrackingFunctions(in classDecl: ClassDeclSyntax) -> [String] {
        var functionNames: [String] = []

        for member in classDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                // Check if this function has the @ObservationTracking attribute
                let hasObservationTracking = functionDecl.attributes.contains { attribute in
                    if case let .attribute(attr) = attribute,
                        let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self)
                    {
                        return identifierType.name.text == "ObservationTracking"
                    }
                    return false
                }

                if hasObservationTracking {
                    functionNames.append(functionDecl.name.text)
                }
            }
        }

        return functionNames
    }
}

public struct ObservationTrackingMacro: BodyMacro, PeerMacro {
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

        var newStatements: [CodeBlockItemSyntax] = []
        for statement in body.statements {
            if let assignment = findAssignmentInStatement(statement) {
                newStatements.append("\(raw: generateObserverFunctionName(from: assignment.property))()")
            } else if let assignment = findFunctionInStatement(statement) {
                newStatements.append("\(raw: generateObserverFunctionName(from: assignment.function))()")
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

        var peerFunctions: [DeclSyntax] = []
        let hasCancellableObservation = hasParentWithCancellableObservation(context: context)
        for statement in body.statements {
            if let assignment = findAssignmentInStatement(statement) {
                let observeFunctionName = generateObserverFunctionName(from: assignment.property)
                let observerFunction = generateObserverFunction(
                    name: observeFunctionName,
                    assignment: assignment,
                    withCancellation: hasCancellableObservation
                )
                peerFunctions.append(observerFunction)
                if hasCancellableObservation {
                    peerFunctions.append(
                        """
                        func \(raw: generateObserverFunctionName(from: assignment.property, isCancel: true))() {
                            observationTokens.removeValue(forKey: "\(raw: observeFunctionName)")
                        }
                        """
                    )
                }
            }
            if let assignment = findFunctionInStatement(statement) {
                let observeFunctionName = generateObserverFunctionName(from: assignment.function)
                let observerFunction = generateFunctionObserverFunction(
                    name: observeFunctionName,
                    assignment: assignment,
                    withCancellation: hasCancellableObservation
                )
                peerFunctions.append(observerFunction)
                if hasCancellableObservation {
                    peerFunctions.append(
                        """
                        func \(raw: generateObserverFunctionName(from: assignment.function, isCancel: true))() {
                            observationTokens.removeValue(forKey: "\(raw: observeFunctionName)")
                        }
                        """
                    )
                }
            }
        }

        return peerFunctions
    }

    private static func hasParentWithCancellableObservation(
        context: some MacroExpansionContext
    ) -> Bool {
        let lexicalContext: [Syntax] = context.lexicalContext
        for syntax in lexicalContext {
            if let classDecl = syntax.as(ClassDeclSyntax.self),
                classDecl.attributes.contains(where: { $0.description.contains("@CancellableObservation") })
            {
                return true
            }
        }

        return false
    }

    private static func generateFunctionObserverFunction(
        name: String,
        assignment: (function: String, argument: String),
        withCancellation: Bool
    ) -> DeclSyntax {
        let value = "value"
        let functionCall = assignment.function.replacingOccurrences(of: assignment.argument, with: value)
        if withCancellation {
            return """
                func \(raw: name)() {
                    guard isObservingEnabled else { 
                        return
                    }
                    
                    let token = UUID().uuidString
                    observationTokens["\(raw: name)"] = token
                    let \(raw: value) = withObservationTracking {
                        \(raw: assignment.argument)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, token == self.observationTokens["\(raw: name)"] else {
                                return
                            }
                            self.\(raw: name)()
                        }
                    }
                    \(raw: functionCall)
                }
                """
        } else {
            return """
                private func \(raw: name)() {
                    let \(raw: value) = withObservationTracking {
                        \(raw: assignment.argument)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.\(raw: name)()
                        }
                    }
                    \(raw: functionCall)
                }
                """
        }
    }

    private static func generateObserverFunction(
        name: String,
        assignment: (property: String, value: String),
        withCancellation: Bool
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
                        Task { @MainActor in
                            guard let self, token == self.observationTokens["\(raw: name)"] else {
                                return
                            }
                            self.\(raw: name)()
                        }
                    }
                }
                """
        } else {
            return """
                private func \(raw: name)() {
                    \(raw: assignment.property) = withObservationTracking {
                        \(raw: assignment.value)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.\(raw: name)()
                        }
                    }
                }
                """
        }
    }

    private static func findFunctionInStatement(_ statement: CodeBlockItemSyntax) -> (function: String, argument: String)? {
        if let functionCall = statement.item.as(FunctionCallExprSyntax.self) {
            let nonLiteralArguments = functionCall.arguments.compactMap { argument -> String? in
                if !isLiteralExpression(argument.expression) {
                    return argument.description.trimmingCharacters(in: functionArgumentDescriptionTrimSet)
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
    }

    private static func findAssignmentInStatement(_ statement: CodeBlockItemSyntax) -> (property: String, value: String)? {
        let statementText = statement.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let patterns = [" = ", " ="]
        for pattern in patterns {
            if let equalsRange = statementText.range(of: pattern) {
                let propertyName = String(statementText[..<equalsRange.lowerBound]).trimmingCharacters(in: CharacterSet.whitespaces)
                let valueExpression = String(statementText[equalsRange.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)

                let cleanPropertyName = removeComments(from: propertyName)
                let cleanValueExpression = removeComments(from: valueExpression)

                if !cleanPropertyName.isEmpty && !cleanValueExpression.isEmpty {
                    return (cleanPropertyName, cleanValueExpression)
                }
            }
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

extension String {
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
    ]
}
