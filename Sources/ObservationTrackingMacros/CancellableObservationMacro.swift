//
//  CancellableObservationMacro.swift
//  ObservationTracking
//
//  Created by VAndrJ on 14.09.2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct CancellableObservationMacro: MemberMacro, MemberAttributeMacro {
    static let viewWillAppear = "viewWillAppear"
    static let viewDidDisappear = "viewDidDisappear"
    static let startObservations = "StartObservations"
    static let stopObservations = "StopObservations"

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@CancellableObservation can only be applied to classes")
        }

        var declarations: [DeclSyntax] = []
        if node.isScreen {
            if !(classDecl.contains(identifier: startObservations) || classDecl.contains(function: viewWillAppear)) {
                declarations.append(
                    """
                    override func viewWillAppear(_ animated: Bool) {
                        super.viewWillAppear(animated)
                        startObservationsIfNeeded()
                    }
                    """
                )
            }
            if !(classDecl.contains(identifier: stopObservations) || classDecl.contains(function: viewDidDisappear)) {
                declarations.append(
                    """
                    override func viewDidDisappear(_ animated: Bool) {
                        super.viewDidDisappear(animated)
                        stopObservations()
                    }
                    """
                )
            }
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
        declarations.append(
            """
            private var observationTokens: [String: String] = [:]
            private var isObservingEnabled = true

            func stopObservations() {
                isObservingEnabled = false
                observationTokens.removeAll()
            }

            \(raw: startObservationsBody)
            """
        )

        return declarations
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self), node.isScreen else {
            return []
        }

        if let functionDecl = member.as(FunctionDeclSyntax.self) {
            if functionDecl.name.text == viewWillAppear, !classDecl.contains(identifier: startObservations) {
                return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier(startObservations)))]
            }
            if functionDecl.name.text == viewDidDisappear, !classDecl.contains(identifier: stopObservations) {
                return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier(stopObservations)))]
            }
        }

        return []
    }

    private static func findObservationTrackingFunctions(in classDecl: ClassDeclSyntax) -> [String] {
        var functionNames: [String] = []
        for member in classDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                let hasObservationTracking = functionDecl.attributes.contains { attribute in
                    if case let .attribute(attr) = attribute, let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self) {
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

extension AttributeSyntax {
    fileprivate var isScreen: Bool {
        guard case let .argumentList(arguments) = arguments else {
            return false
        }

        for argument in arguments {
            if let label = argument.label, label.text == "screen" {
                return argument.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
            }
        }

        return false
    }
}

extension ClassDeclSyntax {
    fileprivate func contains(identifier: String) -> Bool {
        for member in memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                if functionDecl.attributes.contains(where: { attribute in
                    if case let .attribute(attr) = attribute, let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self) {
                        return identifierType.name.text == identifier
                    }

                    return false
                }) {
                    return true
                }
            }
        }

        return false
    }

    fileprivate func contains(function: String) -> Bool {
        for member in memberBlock.members {
            if let decl = member.decl.as(FunctionDeclSyntax.self), decl.name.text == function {
                return true
            }
        }

        return false
    }
}
