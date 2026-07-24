import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct SourceIndentation {
    let spaces: Int
    let tabs: Int

    private init(spaces: Int, tabs: Int) {
        self.spaces = spaces
        self.tabs = tabs
    }

    init(_ trivia: Trivia) {
        var spaces = 0
        var tabs = 0
        for piece in trivia.reversed() {
            switch piece {
            case .spaces(let count):
                spaces += count
            case .tabs(let count):
                tabs += count
            case .newlines, .carriageReturns, .carriageReturnLineFeeds:
                self.spaces = spaces
                self.tabs = tabs
                return
            default:
                spaces = 0
                tabs = 0
            }
        }
        self.spaces = spaces
        self.tabs = tabs
    }

    static func afterLastNewline(in trivia: Trivia) -> SourceIndentation? {
        var spaces = 0
        var tabs = 0
        for piece in trivia.reversed() {
            switch piece {
            case .spaces(let count):
                spaces += count
            case .tabs(let count):
                tabs += count
            case .newlines, .carriageReturns, .carriageReturnLineFeeds:
                return SourceIndentation(spaces: spaces, tabs: tabs)
            default:
                spaces = 0
                tabs = 0
            }
        }
        return nil
    }

    func subtracting(_ indentation: SourceIndentation) -> SourceIndentation {
        SourceIndentation(
            spaces: max(0, spaces - indentation.spaces),
            tabs: max(0, tabs - indentation.tabs)
        )
    }
}

private struct Assignment {
    let property: ExprSyntax
    let assignmentOperator: AssignmentExprSyntax
    let value: ExprSyntax
    let valueSourceIndentation: SourceIndentation

    var observedName: String {
        property.trimmedDescription
    }
}

private struct FunctionCallObservation {
    let function: String
    let functionCall: FunctionCallExprSyntax
    let sourceIndentation: SourceIndentation
}

private struct ControlFlowObservation {
    let observedName: String
    let statement: ExprSyntax
    let sourceIndentation: SourceIndentation
}

private enum ObservationKind {
    case assignment(Assignment)
    case functionCall(FunctionCallObservation)
    case controlFlow(ControlFlowObservation)

    var observedName: String {
        switch self {
        case .assignment(let assignment):
            assignment.observedName
        case .functionCall(let observation):
            observation.function
        case .controlFlow(let observation):
            observation.observedName
        }
    }
}

private struct NamedObservation {
    let name: String
    let kind: ObservationKind
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

        var usedObserverNames: [String: Int] = [:]
        return body.statements.map { statement in
            guard let observation = namedObservation(from: statement, usedNames: &usedObserverNames) else {
                return statement
            }

            return "\(raw: observation.name)()"
        }
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
        let hasCancellableObservation = hasEnclosingClassWithCancellableObservation(context: context)
        let supportsGenerationStorage = !isInExtensionContext(context: context)
        let isolation = try node.isolation(defaultingToTask: isInActorContext(context: context))
        for statement in body.statements {
            guard let observation = namedObservation(from: statement, usedNames: &usedObserverNames) else {
                continue
            }

            if !hasCancellableObservation && supportsGenerationStorage {
                peerFunctions.append(generateGenerationStorage(for: observation.name))
            }
            peerFunctions.append(
                try generateObserverFunction(
                    for: observation,
                    withCancellation: hasCancellableObservation,
                    withGenerationValidation: supportsGenerationStorage,
                    isolation: isolation
                )
            )
            if hasCancellableObservation {
                peerFunctions.append(generateCancelObserverFunction(for: observation.name))
            }
        }

        return peerFunctions
    }

    private static func generateGenerationStorage(for observerName: String) -> DeclSyntax {
        "private var \(raw: generationStorageName(for: observerName)): UInt = 0"
    }

    private static func generationStorageName(for observerName: String) -> String {
        "_observationTrackingGeneration" + observerName.capitalizedFirstLetter
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

        guard let enclosingType = nearestEnclosingType(context: context) else {
            return false
        }

        return enclosingType.is(ClassDeclSyntax.self)
            || enclosingType.is(ActorDeclSyntax.self)
            || enclosingType.is(ExtensionDeclSyntax.self)
    }

    private static func isInActorContext(context: some MacroExpansionContext) -> Bool {
        nearestEnclosingType(context: context)?.is(ActorDeclSyntax.self) == true
    }

    private static func isInExtensionContext(context: some MacroExpansionContext) -> Bool {
        nearestEnclosingType(context: context)?.is(ExtensionDeclSyntax.self) == true
    }

    private static func nearestEnclosingType(
        context: some MacroExpansionContext
    ) -> Syntax? {
        context.lexicalContext.first { syntax in
            syntax.is(ClassDeclSyntax.self)
                || syntax.is(ActorDeclSyntax.self)
                || syntax.is(ExtensionDeclSyntax.self)
                || syntax.is(StructDeclSyntax.self)
                || syntax.is(EnumDeclSyntax.self)
                || syntax.is(ProtocolDeclSyntax.self)
        }
    }

    private static func namedObservation(
        from statement: CodeBlockItemSyntax,
        usedNames: inout [String: Int]
    ) -> NamedObservation? {
        guard let kind = observationKind(from: statement) else {
            return nil
        }

        return NamedObservation(
            name: makeUniqueObserverFunctionName(from: kind.observedName, usedNames: &usedNames),
            kind: kind
        )
    }

    private static func observationKind(from statement: CodeBlockItemSyntax) -> ObservationKind? {
        if let functionCall = findFunctionInStatement(statement) {
            return .functionCall(functionCall)
        }
        if let assignment = findAssignmentInStatement(statement) {
            return .assignment(assignment)
        }
        if let controlFlow = findControlFlowObservationInStatement(statement) {
            return .controlFlow(controlFlow)
        }

        return nil
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

    private static func generateObserverFunction(
        for observation: NamedObservation,
        withCancellation: Bool,
        withGenerationValidation: Bool,
        isolation: OnChangeBlockIsolation
    ) throws -> DeclSyntax {
        let preamble = generateObserverPreamble(
            name: observation.name,
            withCancellation: withCancellation,
            withGenerationValidation: withGenerationValidation
        )
        let tracking = generateTrackingBody(
            for: observation.kind,
            onChange: generateOnChangeBody(
                isolation: isolation,
                withCancellation: withCancellation,
                withGenerationValidation: withGenerationValidation,
                name: observation.name
            )
        )
        let body = CodeBlockItemListSyntax {
            if !preamble.isEmpty {
                preamble.with(\.trailingTrivia, .newline)
            }
            tracking
        }

        let containsAssignment: Bool
        if case .assignment = observation.kind {
            containsAssignment = true
        } else {
            containsAssignment = false
        }

        if withCancellation {
            if containsAssignment {
                return DeclSyntax(
                    try FunctionDeclSyntax("func \(raw: observation.name)()") {
                        body
                    }
                )
            } else {
                return """
                    func \(raw: observation.name)() {
                        \(body)
                    }
                    """
            }
        } else {
            if containsAssignment {
                return DeclSyntax(
                    try FunctionDeclSyntax("private func \(raw: observation.name)()") {
                        body
                    }
                )
            } else {
                return """
                    private func \(raw: observation.name)() {
                        \(body)
                    }
                    """
            }
        }
    }

    private static func generateCancelObserverFunction(for observerName: String) -> DeclSyntax {
        """
        func \(raw: generateCancelObserverFunctionName(from: observerName))() {
            observationTokens.removeValue(forKey: "\(raw: observerName)")
        }
        """
    }

    private static func hasEnclosingClassWithCancellableObservation(
        context: some MacroExpansionContext
    ) -> Bool {
        guard let classDecl = nearestEnclosingType(context: context)?.as(ClassDeclSyntax.self) else {
            return false
        }

        return classDecl.attributes.contains {
            $0.hasAttributeName(cancellableObservation)
        }
    }

    private static func generateObserverPreamble(
        name: String,
        withCancellation: Bool,
        withGenerationValidation: Bool
    ) -> CodeBlockItemListSyntax {
        if withCancellation {
            return """
                guard isObservingEnabled else {
                    return
                }

                observationGeneration &+= 1
                let generation = observationGeneration
                observationTokens["\(raw: name)"] = generation
                """
        } else if withGenerationValidation {
            let generationStorage = generationStorageName(for: name)
            return """
                \(raw: generationStorage) &+= 1
                let generation = \(raw: generationStorage)
                """
        } else {
            return CodeBlockItemListSyntax([])
        }
    }

    private static func generateTrackingBody(
        for observation: ObservationKind,
        onChange: CodeBlockItemListSyntax
    ) -> CodeBlockItemListSyntax {
        switch observation {
        case .assignment(let assignment):
            let value = assignment.value.removingSourceIndentation(assignment.valueSourceIndentation)
            let tracking: CodeBlockItemListSyntax = """
                __observationTrackingProperty = withObservationTracking {
                    __observationTrackingValue
                } onChange: { [weak self] in
                    \(onChange)
                }
                """
            return tracking.replacingExpressions([
                "__observationTrackingProperty": assignment.property,
                "__observationTrackingValue": value,
            ], assignmentOperator: assignment.assignmentOperator)
        case .functionCall(let observation):
            let functionCall = ExprSyntax(observation.functionCall)
                .removingSourceIndentation(observation.sourceIndentation)
            return """
                withObservationTracking {
                    \(functionCall)
                } onChange: { [weak self] in
                    \(onChange)
                }
                """
        case .controlFlow(let observation):
            let statement = observation.statement.removingSourceIndentation(observation.sourceIndentation)
            return """
                withObservationTracking {
                    \(statement)
                } onChange: { [weak self] in
                    \(onChange)
                }
                """
        }
    }

    private static func generateOnChangeBody(
        isolation: OnChangeBlockIsolation,
        withCancellation: Bool,
        withGenerationValidation: Bool,
        name: String
    ) -> CodeBlockItemListSyntax {
        return switch isolation {
        case .mainActor:
            if withCancellation {
                """
                Task { @MainActor in
                    guard let self, generation == self.observationTokens["\(raw: name)"] else {
                        return
                    }
                    self.\(raw: name)()
                }
                """
            } else if withGenerationValidation {
                """
                Task { @MainActor in
                    guard let self, generation == self.\(raw: generationStorageName(for: name)) else {
                        return
                    }
                    self.\(raw: name)()
                }
                """
            } else {
                """
                Task { @MainActor in
                    self?.\(raw: name)()
                }
                """
            }
        case .task:
            if withCancellation {
                """
                Task {
                    guard let self, await generation == self.observationTokens["\(raw: name)"] else {
                        return
                    }
                    await self.\(raw: name)()
                }
                """
            } else if withGenerationValidation {
                """
                Task {
                    guard let self, await generation == self.\(raw: generationStorageName(for: name)) else {
                        return
                    }
                    await self.\(raw: name)()
                }
                """
            } else {
                """
                Task {
                    await self?.\(raw: name)()
                }
                """
            }
        case .synchronous:
            if withCancellation {
                """
                guard let self, generation == self.observationTokens["\(raw: name)"] else {
                    return
                }
                self.\(raw: name)()
                """
            } else if withGenerationValidation {
                """
                guard let self, generation == self.\(raw: generationStorageName(for: name)) else {
                    return
                }
                self.\(raw: name)()
                """
            } else {
                "self?.\(raw: name)()"
            }
        }
    }

    private static func findControlFlowObservationInStatement(_ statement: CodeBlockItemSyntax) -> ControlFlowObservation? {
        if let ifExpression = ifExpression(from: statement),
            let observedName = firstObservedName(in: ifExpression)
        {
            return ControlFlowObservation(
                observedName: observedName,
                statement: ExprSyntax(ifExpression.with(\.leadingTrivia, []).trimmed(matching: \.isWhitespace)),
                sourceIndentation: SourceIndentation(statement.leadingTrivia)
            )
        }

        if let switchExpression = switchExpression(from: statement),
            let observedName = firstObservedName(in: switchExpression)
        {
            return ControlFlowObservation(
                observedName: observedName,
                statement: ExprSyntax(switchExpression.with(\.leadingTrivia, []).trimmed(matching: \.isWhitespace)),
                sourceIndentation: SourceIndentation(statement.leadingTrivia)
            )
        }

        return nil
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

    private static func switchExpression(from statement: CodeBlockItemSyntax) -> SwitchExprSyntax? {
        if let switchExpression = statement.item.as(SwitchExprSyntax.self) {
            return switchExpression
        }
        if let switchExpression = statement.item.as(ExprSyntax.self)?.as(SwitchExprSyntax.self) {
            return switchExpression
        }

        return statement.item.as(ExpressionStmtSyntax.self)?.expression.as(SwitchExprSyntax.self)
    }

    private static func firstObservedName(in syntax: some SyntaxProtocol) -> String? {
        let visitor = FirstObservedOperationVisitor(viewMode: .sourceAccurate)
        visitor.walk(syntax)
        return visitor.observedName
    }

    private static func findFunctionInStatement(_ statement: CodeBlockItemSyntax) -> FunctionCallObservation? {
        guard let functionCall = statement.item.as(FunctionCallExprSyntax.self) else {
            return nil
        }

        return FunctionCallObservation(
            function: functionCall.trimmedDescription,
            functionCall: functionCall.with(\.leadingTrivia, []).trimmed(matching: \.isWhitespace),
            sourceIndentation: SourceIndentation(statement.leadingTrivia)
        )
    }

    private static func findAssignmentInStatement(_ statement: CodeBlockItemSyntax) -> Assignment? {
        syntaxAssignment(from: statement)
    }

    private static func syntaxAssignment(from statement: CodeBlockItemSyntax) -> Assignment? {
        if let infixExpression = statement.item.as(InfixOperatorExprSyntax.self),
            infixExpression.operator.is(AssignmentExprSyntax.self)
        {
            let sourceIndentation = SourceIndentation(statement.leadingTrivia)
            let valueIndentation =
                SourceIndentation.afterLastNewline(in: infixExpression.rightOperand.leadingTrivia)
                ?? SourceIndentation.afterLastNewline(in: infixExpression.operator.trailingTrivia)
                ?? SourceIndentation.afterLastNewline(in: infixExpression.operator.leadingTrivia)
                ?? sourceIndentation
            return Assignment(
                property: infixExpression.leftOperand.with(\.leadingTrivia, []).trimmed(matching: \.isWhitespace),
                assignmentOperator: infixExpression.operator.as(AssignmentExprSyntax.self)!,
                value: infixExpression.rightOperand.trimmed(matching: \.isWhitespace),
                valueSourceIndentation: valueIndentation.subtracting(sourceIndentation)
            )
        }

        guard let sequenceExpression = statement.item.as(SequenceExprSyntax.self) else {
            return nil
        }

        let elements = Array(sequenceExpression.elements)
        guard let assignmentIndex = elements.firstIndex(where: { $0.is(AssignmentExprSyntax.self) }),
            assignmentIndex > elements.startIndex,
            assignmentIndex < elements.index(before: elements.endIndex),
            let property = expression(from: elements[..<assignmentIndex]),
            let value = expression(from: elements[elements.index(after: assignmentIndex)...])
        else {
            return nil
        }

        let sourceIndentation = SourceIndentation(statement.leadingTrivia)
        let assignmentOperator = elements[assignmentIndex]
        let valueIndentation =
            SourceIndentation.afterLastNewline(in: value.leadingTrivia)
            ?? SourceIndentation.afterLastNewline(in: assignmentOperator.trailingTrivia)
            ?? SourceIndentation.afterLastNewline(in: assignmentOperator.leadingTrivia)
            ?? sourceIndentation
        return Assignment(
            property: property.with(\.leadingTrivia, []).trimmed(matching: \.isWhitespace),
            assignmentOperator: assignmentOperator.as(AssignmentExprSyntax.self)!,
            value: value.trimmed(matching: \.isWhitespace),
            valueSourceIndentation: valueIndentation.subtracting(sourceIndentation)
        )
    }

    private static func expression(from elements: ArraySlice<ExprSyntax>) -> ExprSyntax? {
        guard let first = elements.first else {
            return nil
        }
        if elements.count == 1 {
            return first
        }
        return ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
    }

    private final class FirstObservedOperationVisitor: SyntaxVisitor {
        private(set) var observedName: String?

        override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
            guard observedName == nil else {
                return .skipChildren
            }

            if let assignment = ObservationTrackingMacro.findAssignmentInStatement(node) {
                observedName = assignment.observedName
            } else if let functionCall = node.item.as(FunctionCallExprSyntax.self) {
                observedName = functionCall.calledExpression.trimmedDescription
            }

            return observedName == nil ? .visitChildren : .skipChildren
        }

        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }

        override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
            .skipChildren
        }
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
    private static let invalidIsolationMessage = "@ObservationTracking isolation must be nil or one of .mainActor, .task, or .synchronous"

    /// Extracts the isolation parameter from the ObservationTracking attribute.
    ///
    /// Parses the attribute arguments to find the isolation parameter and returns
    /// the corresponding OnChangeBlockIsolation value.
    ///
    /// - Parameter defaultingToTask: Uses task isolation when no explicit isolation is provided.
    /// - Returns: The OnChangeBlockIsolation enum value, defaulting to .mainActor for classes and .task for actors.
    fileprivate func isolation(defaultingToTask: Bool) throws -> OnChangeBlockIsolation {
        let defaultIsolation: OnChangeBlockIsolation = defaultingToTask ? .task : .mainActor
        guard case let .argumentList(arguments) = arguments else {
            return defaultIsolation
        }

        guard let isolationArgument = arguments.first(where: { $0.label?.text == "isolation" }) else {
            return defaultIsolation
        }

        return try Self.parseIsolationExpression(isolationArgument.expression, defaultIsolation: defaultIsolation)
    }

    private static func parseIsolationExpression(
        _ expression: ExprSyntax,
        defaultIsolation: OnChangeBlockIsolation
    ) throws -> OnChangeBlockIsolation {
        if expression.is(NilLiteralExprSyntax.self) {
            return defaultIsolation
        }

        guard let memberAccess = expression.as(MemberAccessExprSyntax.self),
            isSupportedIsolationBase(memberAccess.base)
        else {
            throw MacroExpansionErrorMessage(invalidIsolationMessage)
        }

        return switch memberAccess.declName.baseName.text {
        case "mainActor":
            .mainActor
        case "task":
            .task
        case "synchronous":
            .synchronous
        default:
            throw MacroExpansionErrorMessage(invalidIsolationMessage)
        }
    }

    private static func isSupportedIsolationBase(_ base: ExprSyntax?) -> Bool {
        guard let base else {
            return true
        }

        if base.as(DeclReferenceExprSyntax.self)?.baseName.text == "OnChangeBlockIsolation" {
            return true
        }

        if base.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "OnChangeBlockIsolation" {
            return true
        }

        return false
    }
}

private enum OnChangeBlockIsolation {
    case mainActor
    case task
    case synchronous
}

private final class ExpressionPlaceholderRewriter: SyntaxRewriter {
    private let replacements: [String: ExprSyntax]
    private let assignmentOperator: AssignmentExprSyntax?

    init(
        replacements: [String: ExprSyntax],
        assignmentOperator: AssignmentExprSyntax?
    ) {
        self.replacements = replacements
        self.assignmentOperator = assignmentOperator
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
        guard var replacement = replacements[node.baseName.text] else {
            return super.visit(node)
        }

        replacement.leadingTrivia = Trivia(
            pieces: Array(node.leadingTrivia) + Array(replacement.leadingTrivia)
        )
        replacement.trailingTrivia = Trivia(
            pieces: Array(replacement.trailingTrivia) + Array(node.trailingTrivia)
        )
        return replacement
    }

    override func visit(_ node: AssignmentExprSyntax) -> ExprSyntax {
        guard var replacement = assignmentOperator?.trimmed(matching: \.isWhitespace) else {
            return super.visit(node)
        }

        replacement.leadingTrivia = Trivia(
            pieces: Array(node.leadingTrivia) + Array(replacement.leadingTrivia)
        )
        replacement.trailingTrivia = Trivia(
            pieces: Array(replacement.trailingTrivia) + Array(node.trailingTrivia)
        )
        return ExprSyntax(replacement)
    }
}

extension CodeBlockItemListSyntax {
    fileprivate func replacingExpressions(
        _ replacements: [String: ExprSyntax],
        assignmentOperator: AssignmentExprSyntax? = nil
    ) -> CodeBlockItemListSyntax {
        let rewritten = ExpressionPlaceholderRewriter(
            replacements: replacements,
            assignmentOperator: assignmentOperator
        ).rewrite(self)
        return CodeBlockItemListSyntax(rewritten)!.trimmed(matching: \.isWhitespace)
    }
}

private final class SourceIndentationRemover: SyntaxRewriter {
    private let indentation: SourceIndentation
    private var remainingSpaces = 0
    private var remainingTabs = 0

    init(indentation: SourceIndentation) {
        self.indentation = indentation
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        var token = token
        token.leadingTrivia = removeSourceIndentation(from: token.leadingTrivia)
        remainingSpaces = 0
        remainingTabs = 0
        token.trailingTrivia = removeSourceIndentation(from: token.trailingTrivia)
        return token
    }

    override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
        var node = node
        node.leadingTrivia = removeSourceIndentation(from: node.leadingTrivia)
        remainingSpaces = 0
        remainingTabs = 0
        node.trailingTrivia = removeSourceIndentation(from: node.trailingTrivia)
        return ExprSyntax(node)
    }

    private func removeSourceIndentation(from trivia: Trivia) -> Trivia {
        var pieces: [TriviaPiece] = []
        for piece in trivia {
            switch piece {
            case .newlines, .carriageReturns, .carriageReturnLineFeeds:
                pieces.append(piece)
                remainingSpaces = indentation.spaces
                remainingTabs = indentation.tabs
            case .spaces(let count) where remainingSpaces > 0:
                let remainder = count - min(count, remainingSpaces)
                remainingSpaces -= min(count, remainingSpaces)
                if remainder > 0 {
                    pieces.append(.spaces(remainder))
                }
            case .tabs(let count) where remainingTabs > 0:
                let remainder = count - min(count, remainingTabs)
                remainingTabs -= min(count, remainingTabs)
                if remainder > 0 {
                    pieces.append(.tabs(remainder))
                }
            default:
                pieces.append(piece)
                remainingSpaces = 0
                remainingTabs = 0
            }
        }
        return Trivia(pieces: pieces)
    }
}

extension ExprSyntax {
    fileprivate func removingSourceIndentation(_ indentation: SourceIndentation) -> ExprSyntax {
        let rewritten = SourceIndentationRemover(indentation: indentation).rewrite(self)
        return ExprSyntax(rewritten)!.trimmed(matching: \.isWhitespace)
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
        StartObservationsMacro.self,
        StopObservationsMacro.self,
    ]
}
