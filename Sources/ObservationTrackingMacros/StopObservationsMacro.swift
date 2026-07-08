//
//  StopObservationsMacro.swift
//  ObservationTracking
//
//  Created by VAndrJ on 14.09.2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct StopObservationsMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let functionDecl = declaration.as(FunctionDeclSyntax.self),
            let body = functionDecl.body
        else {
            throw MacroExpansionErrorMessage("@StopObservations can only be applied to functions with a body")
        }

        var newStatements: [CodeBlockItemSyntax] = [
            """
            defer {
                stopObservations()
            }
            """
        ]
        newStatements.append(contentsOf: body.statements)

        return newStatements
    }
}
