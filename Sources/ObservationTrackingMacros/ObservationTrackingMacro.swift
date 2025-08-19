import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
        for statement in body.statements {
            if let assignment = findAssignmentInStatement(statement) {
                let observeFunctionName = generateObserverFunctionName(from: assignment.property)
                peerFunctions.append(
                    """
                    private func \(raw: observeFunctionName)() {
                        \(raw: assignment.property) = withObservationTracking {
                            \(raw: assignment.value)
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.\(raw: observeFunctionName)()
                            }
                        }
                    }
                    """
                )
            }
        }

        return peerFunctions
    }

    private static func findAssignmentInStatement(_ statement: CodeBlockItemSyntax) -> (property: String, value: String)? {
        let statementText = statement.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if let equalsRange = statementText.range(of: " = ") {
            let propertyName = String(statementText[..<equalsRange.lowerBound]).trimmingCharacters(in: CharacterSet.whitespaces)
            let valueExpression = String(statementText[equalsRange.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
            if !propertyName.isEmpty && !valueExpression.isEmpty {
                return (propertyName, valueExpression)
            }
        }

        return nil
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
    /// ```
    private static func generateObserverFunctionName(from propertyName: String) -> String {
        let segments = propertyName.components(separatedBy: ".")
        let capitalizedSegments = segments.map { $0.capitalizedFirstLetter }

        return "observe" + capitalizedSegments.joined()
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
        ObservationTrackingMacro.self
    ]
}
