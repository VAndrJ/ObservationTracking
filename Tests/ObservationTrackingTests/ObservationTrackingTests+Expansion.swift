//
//  ObservationTrackingTests+Expansion.swift
//  ObservationTracking
//
//  Created by VAndrJ on 24.08.2025.
//

#if canImport(ObservationTrackingMacros)
import Observation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import ObservationTrackingMacros
import ObservationTracking

extension ObservationTrackingTests {
    func testObservationTrackingMacroExpansion() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeValues() {
                intValue = classToObserve?.count ?? 0
                stringValue = classToObserve?.message ?? ""
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                    observeStringValue()
                }

                private func observeIntValue() {
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeIntValue()
                        }
                    }
                }

                private func observeStringValue() {
                    stringValue = withObservationTracking {
                        classToObserve?.message ?? ""
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeStringValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithSingleAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeValue() {
                count = model.value
            }
            """,
            expandedSource: """
                func observeValue() {
                    observeCount()
                }

                private func observeCount() {
                    count = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeCount()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithAssignmentAndFunctionCall() {
        assertMacroExpansion(
            """
            @ObservationTracking
            override func bind() {
                super.bind()
                print("binding values")
                count = model.value
            }
            """,
            expandedSource: """
                override func bind() {
                    super.bind()
                    print("binding values")
                    observeCount()
                }

                private func observeCount() {
                    count = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeCount()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationFunctionCallTracking() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                updateCorners(radius: defaults.corners)
                updateCorners(defaults.corners)
                updateCorners(defaults.corners, animated: true)
            }
            """,
            expandedSource: """
                func bind() {
                    observeUpdateCornersradiusdefaultsCorners()
                    observeUpdateCornersdefaultsCorners()
                    observeUpdateCornersdefaultsCornersanimatedtrue()
                }
                
                private func observeUpdateCornersradiusdefaultsCorners() {
                    updateCorners(
                        radius: withObservationTracking {
                            defaults.corners
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeUpdateCornersradiusdefaultsCorners()
                            }
                        }
                    )
                }

                private func observeUpdateCornersdefaultsCorners() {
                    updateCorners(
                        withObservationTracking {
                            defaults.corners
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeUpdateCornersdefaultsCorners()
                            }
                        }
                    )
                }

                private func observeUpdateCornersdefaultsCornersanimatedtrue() {
                    updateCorners(
                        withObservationTracking {
                            defaults.corners
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeUpdateCornersdefaultsCornersanimatedtrue()
                            }
                        },
                        animated: true
                    )
                }
                """,
            macros: testMacros
        )
    }

    func testFunctionCallTrackingDoesNotRewriteMatchingLiteralText() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                log(defaults.corners, message: "defaults.corners")
            }
            """,
            expandedSource: """
                func bind() {
                    observeLogdefaultsCornersmessagedefaultsCorners()
                }

                private func observeLogdefaultsCornersmessagedefaultsCorners() {
                    log(
                        withObservationTracking {
                            defaults.corners
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeLogdefaultsCornersmessagedefaultsCorners()
                            }
                        },
                        message: "defaults.corners"
                    )
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnNonFunction() {
        assertMacroExpansion(
            """
            @ObservationTracking
            var property: Int = 0
            """,
            expandedSource: """
                var property: Int = 0
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ObservationTracking can only be applied to functions with a body", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnStructMethod() {
        assertMacroExpansion(
            """
            struct Observer {
                @ObservationTracking
                func bind() {
                    value = model.value
                }
            }
            """,
            expandedSource: """
                struct Observer {
                    func bind() {
                        value = model.value
                    }
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ObservationTracking can only be applied to instance methods declared in classes, actors, or extensions", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnActorMethod() {
        assertMacroExpansion(
            """
            actor Observer {
                @ObservationTracking
                func bind() {
                    value = model.value
                }
            }
            """,
            expandedSource: """
                actor Observer {
                    func bind() {
                        observeValue()
                    }

                    private func observeValue() {
                        value = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task {
                                await self?.observeValue()
                            }
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnActorMethodWithNilIsolation() {
        assertMacroExpansion(
            """
            actor Observer {
                @ObservationTracking(isolation: nil)
                func bind() {
                    value = model.value
                }
            }
            """,
            expandedSource: """
                actor Observer {
                    func bind() {
                        observeValue()
                    }

                    private func observeValue() {
                        value = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task {
                                await self?.observeValue()
                            }
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnClassExtensionMethod() {
        assertMacroExpansion(
            """
            extension Observer {
                @ObservationTracking
                func bind() {
                    value = model.value
                }
            }
            """,
            expandedSource: """
                extension Observer {
                    func bind() {
                        observeValue()
                    }

                    private func observeValue() {
                        value = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeValue()
                            }
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroOnStaticClassMethod() {
        assertMacroExpansion(
            """
            class Observer {
                @ObservationTracking
                static func bind() {
                    value = model.value
                }

                @ObservationTracking
                class func bindSubclass() {
                    value = model.value
                }
            }
            """,
            expandedSource: """
                class Observer {
                    static func bind() {
                        value = model.value
                    }
                    class func bindSubclass() {
                        value = model.value
                    }
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ObservationTracking can only be applied to instance methods declared in classes, actors, or extensions", line: 2, column: 5),
                DiagnosticSpec(message: "@ObservationTracking can only be applied to instance methods declared in classes, actors, or extensions", line: 7, column: 5),
            ],
            macros: testMacros
        )
    }

    func testObservationTrackingMacroCancellationGeneration() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeCount()
                    }

                    func observeCount() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeCount"] = token
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeCount"] else {
                                    return
                                }
                                self.observeCount()
                            }
                        }
                    }

                    func cancelObserveCount() {
                        observationTokens.removeValue(forKey: "observeCount")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        bind()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationFindsQualifiedObservationTrackingAttribute() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking.ObservationTracking
                func bind() {
                    count = model.value
                }
            }
            """,
            expandedSource: """
                class Example {
                    @ObservationTracking.ObservationTracking
                    func bind() {
                        count = model.value
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        bind()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationDoesNotFindForeignQualifiedObservationTrackingAttribute() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @Other.ObservationTracking
                func bind() {
                    count = model.value
                }
            }
            """,
            expandedSource: """
                class Example {
                    @Other.ObservationTracking
                    func bind() {
                        count = model.value
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroDoesNotTreatSimilarClassAttributeAsCancellable() {
        assertMacroExpansion(
            """
            @NotCancellableObservation
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }
            }
            """,
            expandedSource: """
                @NotCancellableObservation
                class Example {
                    func bind() {
                        observeCount()
                    }

                    private func observeCount() {
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeCount()
                            }
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroDoesNotTreatForeignQualifiedClassAttributeAsCancellable() {
        assertMacroExpansion(
            """
            @Other.CancellableObservation
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }
            }
            """,
            expandedSource: """
                @Other.CancellableObservation
                class Example {
                    func bind() {
                        observeCount()
                    }

                    private func observeCount() {
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                self?.observeCount()
                            }
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroCancellationFunctionGeneration() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking
                func bind() {
                    updateCorners(defaults.corners)
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeUpdateCornersdefaultsCorners()
                    }

                    func observeUpdateCornersdefaultsCorners() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeUpdateCornersdefaultsCorners"] = token
                        updateCorners(
                            withObservationTracking {
                                defaults.corners
                            } onChange: { [weak self] in
                                Task { @MainActor in
                                    guard let self, token == self.observationTokens["observeUpdateCornersdefaultsCorners"] else {
                                        return
                                    }
                                    self.observeUpdateCornersdefaultsCorners()
                                }
                            }
                        )
                    }

                    func cancelObserveUpdateCornersdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersdefaultsCorners")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        bind()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithComplexAssignments() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func complexBind() {
                // Observation
                value = model.nested?.property ?? defaultValue
                array[index] = model.value
                dictionary["key"] = model.value
            }
            """,
            expandedSource: """
                func complexBind() {
                    observeValue()
                    observeArrayindex()
                    observeDictionarykey()
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model.nested?.property ?? defaultValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }

                private func observeArrayindex() {
                    array[index] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeArrayindex()
                        }
                    }
                }

                private func observeDictionarykey() {
                    dictionary["key"] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeDictionarykey()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithMultilineAssignments() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func multilineBind() {
                value = model
                    .someProperty
                    .chainedCall()
                    .finalValue
            }
            """,
            expandedSource: """
                func multilineBind() {
                    observeValue()
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model
                        .someProperty
                        .chainedCall()
                        .finalValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithSpecialCharactersInPropertyNames() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func specialCharsBind() {
                _privateVar = model.value
                $dollarVar = model.other
                var123 = model.numbered
            }
            """,
            expandedSource: """
                func specialCharsBind() {
                    observePrivateVar()
                    observeDollarVar()
                    observeVar123()
                }

                private func observePrivateVar() {
                    _privateVar = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observePrivateVar()
                        }
                    }
                }

                private func observeDollarVar() {
                    $dollarVar = withObservationTracking {
                        model.other
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeDollarVar()
                        }
                    }
                }

                private func observeVar123() {
                    var123 = withObservationTracking {
                        model.numbered
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeVar123()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithNonAssignmentStatements() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func mixedStatements() {
                print("Starting observation")
                value = model.count
                NSLog("Observing value")
                name = model.name
                defer { print("Cleanup") }
            }
            """,
            expandedSource: """
                func mixedStatements() {
                    print("Starting observation")
                    observeValue()
                    NSLog("Observing value")
                    observeName()
                    defer {
                        print("Cleanup")
                    }
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model.count
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }

                private func observeName() {
                    name = withObservationTracking {
                        model.name
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeName()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroIgnoresNonAssignmentEqualsSyntax() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func compareAndDeclare() {
                let localValue = model.value
                private var cachedValue = model.value
                if localValue == currentValue {
                    print("unchanged")
                }
                guard let unwrappedValue = optionalValue else {
                    return
                }
                bindCallCount += 1
                observedValue = model.value
            }
            """,
            expandedSource: """
                func compareAndDeclare() {
                    let localValue = model.value
                    private var cachedValue = model.value
                    if localValue == currentValue {
                            print("unchanged")
                        }
                    guard let unwrappedValue = optionalValue else {
                            return
                        }
                    bindCallCount += 1
                    observeObservedValue()
                }

                private func observeObservedValue() {
                    observedValue = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeObservedValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationMacroOnNonClass() {
        assertMacroExpansion(
            """
            @CancellableObservation
            struct NotAClass {
                var value = 0
            }
            """,
            expandedSource: """
                struct NotAClass {
                    var value = 0
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@CancellableObservation can only be applied to classes", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testMacroWithNestedPropertyAccess() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeNested() {
                value = model.nested.property.subProperty
                text = model.ui?.label?.text ?? "default"
            }
            """,
            expandedSource: """
                func observeNested() {
                    observeValue()
                    observeText()
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model.nested.property.subProperty
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }

                private func observeText() {
                    text = withObservationTracking {
                        model.ui?.label?.text ?? "default"
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeText()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithComplexExpressions() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeComplex() {
                result = (model.value * 2) + (other.value ?? 0)
                formatted = "Total: \\(model.a + model.b)"
                conditional = model.flag ? model.trueValue : model.falseValue
            }
            """,
            expandedSource: """
                func observeComplex() {
                    observeResult()
                    observeFormatted()
                    observeConditional()
                }

                private func observeResult() {
                    result = withObservationTracking {
                        (model.value * 2) + (other.value ?? 0)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeResult()
                        }
                    }
                }

                private func observeFormatted() {
                    formatted = withObservationTracking {
                        "Total: \\(model.a + model.b)"
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeFormatted()
                        }
                    }
                }

                private func observeConditional() {
                    conditional = withObservationTracking {
                        model.flag ? model.trueValue : model.falseValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeConditional()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithFunctionCallsInAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeWithCalls() {
                result = calculateValue(from: model.input)
                transformed = model.data.map { $0.processed }
                filtered = model.items.filter { $0.isValid }
            }
            """,
            expandedSource: """
                func observeWithCalls() {
                    observeResult()
                    observeTransformed()
                    observeFiltered()
                }

                private func observeResult() {
                    result = withObservationTracking {
                        calculateValue(from: model.input)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeResult()
                        }
                    }
                }

                private func observeTransformed() {
                    transformed = withObservationTracking {
                        model.data.map {
                            $0.processed
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeTransformed()
                        }
                    }
                }

                private func observeFiltered() {
                    filtered = withObservationTracking {
                        model.items.filter {
                            $0.isValid
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeFiltered()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithComplicatedPropertyNames() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeComplicated() {
                self.property = model.value
                `class` = model.keyword
                property_with_underscores = model.data
                camelCaseProperty = model.camelCase
                PascalCaseProperty = model.PascalCase
            }
            """,
            expandedSource: """
                func observeComplicated() {
                    observeSelfProperty()
                    observeClass()
                    observePropertywithunderscores()
                    observeCamelCaseProperty()
                    observePascalCaseProperty()
                }

                private func observeSelfProperty() {
                    self.property = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSelfProperty()
                        }
                    }
                }

                private func observeClass() {
                    `class` = withObservationTracking {
                        model.keyword
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeClass()
                        }
                    }
                }

                private func observePropertywithunderscores() {
                    property_with_underscores = withObservationTracking {
                        model.data
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observePropertywithunderscores()
                        }
                    }
                }

                private func observeCamelCaseProperty() {
                    camelCaseProperty = withObservationTracking {
                        model.camelCase
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeCamelCaseProperty()
                        }
                    }
                }

                private func observePascalCaseProperty() {
                    PascalCaseProperty = withObservationTracking {
                        model.PascalCase
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observePascalCaseProperty()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationMacroWithMultipleProperties() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class MultiPropertyObserver {
                @ObservationTracking
                func observe() {
                    prop1 = model.value1
                    prop2 = model.value2
                    prop3 = model.value3
                }
            }
            """,
            expandedSource: """
                class MultiPropertyObserver {
                    func observe() {
                        observeProp1()
                        observeProp2()
                        observeProp3()
                    }

                    func observeProp1() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeProp1"] = token
                        prop1 = withObservationTracking {
                            model.value1
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeProp1"] else {
                                    return
                                }
                                self.observeProp1()
                            }
                        }
                    }

                    func cancelObserveProp1() {
                        observationTokens.removeValue(forKey: "observeProp1")
                    }

                    func observeProp2() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeProp2"] = token
                        prop2 = withObservationTracking {
                            model.value2
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeProp2"] else {
                                    return
                                }
                                self.observeProp2()
                            }
                        }
                    }

                    func cancelObserveProp2() {
                        observationTokens.removeValue(forKey: "observeProp2")
                    }

                    func observeProp3() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeProp3"] = token
                        prop3 = withObservationTracking {
                            model.value3
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeProp3"] else {
                                    return
                                }
                                self.observeProp3()
                            }
                        }
                    }

                    func cancelObserveProp3() {
                        observationTokens.removeValue(forKey: "observeProp3")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        observe()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroPropertyNameGeneration() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func testPropertyNames() {
                // Array subscript patterns
                items[0] = model.firstItem
                data["key"] = model.value
                nested.array[index] = model.nestedValue
                // Complex property chains
                view.layer.backgroundColor = model.color
                // Mixed patterns
                self.items[currentIndex].title = model.title
            }
            """,
            expandedSource: """
                func testPropertyNames() {
                    observeItems0()
                    observeDatakey()
                    observeNestedArrayindex()
                    observeViewLayerBackgroundColor()
                    observeSelfItemscurrentIndexTitle()
                }

                private func observeItems0() {
                    items[0] = withObservationTracking {
                        model.firstItem
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeItems0()
                        }
                    }
                }

                private func observeDatakey() {
                    data["key"] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeDatakey()
                        }
                    }
                }

                private func observeNestedArrayindex() {
                    nested.array[index] = withObservationTracking {
                        model.nestedValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeNestedArrayindex()
                        }
                    }
                }

                private func observeViewLayerBackgroundColor() {
                    view.layer.backgroundColor = withObservationTracking {
                        model.color
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeViewLayerBackgroundColor()
                        }
                    }
                }

                private func observeSelfItemscurrentIndexTitle() {
                    self.items[currentIndex].title = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSelfItemscurrentIndexTitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithCommentsInAssignments() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func testComments() {
                // This is a comment before assignment
                value = model.data // inline comment
                /* Multi-line
                   comment */ 
                name = model.title
                // Another comment
                count = model.number /* another inline */
            }
            """,
            expandedSource: """
                func testComments() {
                    observeValue()
                    observeName()
                    observeCount()
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model.data // inline comment
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }

                private func observeName() {
                    name = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeName()
                        }
                    }
                }

                private func observeCount() {
                    count = withObservationTracking {
                        model.number
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeCount()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithVeryLongPropertyChains() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func testLongChain() {
                very.long.property.chain.with.many.segments.final = model.value
            }
            """,
            expandedSource: """
                func testLongChain() {
                    observeVeryLongPropertyChainWithManySegmentsFinal()
                }

                private func observeVeryLongPropertyChainWithManySegmentsFinal() {
                    very.long.property.chain.with.many.segments.final = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeVeryLongPropertyChainWithManySegmentsFinal()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    @MainActor
    func testMacroWithComplexWhitespaceAndFormatting() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func testFormatting() {
                value =model.data
                name    =     model.title
                count =model.number
                text
                    = model
                        .formatted
                        .string
            }
            """,
            expandedSource: """
                func testFormatting() {
                    observeValue()
                    observeName()
                    observeCount()
                    observeText()
                }

                private func observeValue() {
                    value = withObservationTracking {
                        model.data
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeValue()
                        }
                    }
                }

                private func observeName() {
                    name = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeName()
                        }
                    }
                }

                private func observeCount() {
                    count = withObservationTracking {
                        model.number
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeCount()
                        }
                    }
                }

                private func observeText() {
                    text = withObservationTracking {
                        model
                            .formatted
                            .string
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeText()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    // TODO: - Add test for @CancellableObservation with multiple @ObservationTracking functions
    func testCancellableObservationWithMultipleObservationTrackingFunctions() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class MultiObservationClass {
                @ObservationTracking
                func bindPrimary() {
                    value1 = model.primary
                    value2 = model.secondary
                }
                
                @ObservationTracking
                func bindSecondary() {
                    name = model.name
                }
                
                @ObservationTracking
                func bindTertiary() {
                    count = model.count
                    isEnabled = model.enabled
                }
            }
            """,
            expandedSource: """
                class MultiObservationClass {
                    func bindPrimary() {
                        observeValue1()
                        observeValue2()
                    }

                    func observeValue1() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeValue1"] = token
                        value1 = withObservationTracking {
                            model.primary
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeValue1"] else {
                                    return
                                }
                                self.observeValue1()
                            }
                        }
                    }

                    func cancelObserveValue1() {
                        observationTokens.removeValue(forKey: "observeValue1")
                    }

                    func observeValue2() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeValue2"] = token
                        value2 = withObservationTracking {
                            model.secondary
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeValue2"] else {
                                    return
                                }
                                self.observeValue2()
                            }
                        }
                    }

                    func cancelObserveValue2() {
                        observationTokens.removeValue(forKey: "observeValue2")
                    }

                    func bindSecondary() {
                        observeName()
                    }

                    func observeName() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeName"] = token
                        name = withObservationTracking {
                            model.name
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeName"] else {
                                    return
                                }
                                self.observeName()
                            }
                        }
                    }

                    func cancelObserveName() {
                        observationTokens.removeValue(forKey: "observeName")
                    }

                    func bindTertiary() {
                        observeCount()
                        observeIsEnabled()
                    }

                    func observeCount() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeCount"] = token
                        count = withObservationTracking {
                            model.count
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeCount"] else {
                                    return
                                }
                                self.observeCount()
                            }
                        }
                    }

                    func cancelObserveCount() {
                        observationTokens.removeValue(forKey: "observeCount")
                    }

                    func observeIsEnabled() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeIsEnabled"] = token
                        isEnabled = withObservationTracking {
                            model.enabled
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeIsEnabled"] else {
                                    return
                                }
                                self.observeIsEnabled()
                            }
                        }
                    }

                    func cancelObserveIsEnabled() {
                        observationTokens.removeValue(forKey: "observeIsEnabled")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        bindPrimary()
                    bindSecondary()
                    bindTertiary()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationWithNoObservationTrackingFunctions() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class EmptyObservationClass {
                func regularFunction() {
                    print("No observation tracking here")
                }
                
                func anotherFunction() {
                    // Just a regular function
                }
            }
            """,
            expandedSource: """
                class EmptyObservationClass {
                    func regularFunction() {
                        print("No observation tracking here")
                    }
                    
                    func anotherFunction() {
                        // Just a regular function
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testCancellableObservationWithSingleObservationTrackingFunction() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class SingleObservationClass {
                @ObservationTracking
                func bind() {
                    value = model.data
                }
                
                func helper() {
                    // Regular helper function
                }
            }
            """,
            expandedSource: """
                class SingleObservationClass {
                    func bind() {
                        observeValue()
                    }

                    func observeValue() {
                        guard isObservingEnabled else {
                            return
                        }

                        let token = UUID().uuidString
                        observationTokens["observeValue"] = token
                        value = withObservationTracking {
                            model.data
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, token == self.observationTokens["observeValue"] else {
                                    return
                                }
                                self.observeValue()
                            }
                        }
                    }

                    func cancelObserveValue() {
                        observationTokens.removeValue(forKey: "observeValue")
                    }
                    
                    func helper() {
                        // Regular helper function
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled || observationTokens.isEmpty else {
                            return
                        }
                        isObservingEnabled = true
                        bind()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroDisambiguatesSanitizedNameCollisions() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                foo.bar = model.first
                fooBar = model.second
            }
            """,
            expandedSource: """
                func bind() {
                    observeFooBar()
                    observeFooBar2()
                }

                private func observeFooBar() {
                    foo.bar = withObservationTracking {
                        model.first
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeFooBar()
                        }
                    }
                }

                private func observeFooBar2() {
                    fooBar = withObservationTracking {
                        model.second
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeFooBar2()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksIfAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                if model.isEnabled {
                    subtitle = model.subtitle
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSubtitle()
                }

                private func observeSubtitle() {
                    withObservationTracking {
                        if model.isEnabled {
                            subtitle = model.subtitle
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksIfElseAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                if model.someValue {
                    subtitle = "A"
                } else {
                    subtitle = "B"
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSubtitle()
                }

                private func observeSubtitle() {
                    withObservationTracking {
                        if model.someValue {
                            subtitle = "A"
                        } else {
                            subtitle = "B"
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksIfLetAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                if let value = model.someValue {
                    subtitle = value
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSubtitle()
                }

                private func observeSubtitle() {
                    withObservationTracking {
                        if let value = model.someValue {
                            subtitle = value
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksIfExpressionAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                subtitle = if model.value {
                    "A"
                } else {
                    "B"
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSubtitle()
                }

                private func observeSubtitle() {
                    subtitle = withObservationTracking {
                        if model.value {
                            "A"
                        } else {
                            "B"
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }
}
#endif
