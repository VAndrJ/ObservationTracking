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

                private var _observationTrackingGenerationObserveIntValue: UInt = 0

                private func observeIntValue() {
                    _observationTrackingGenerationObserveIntValue &+= 1
                    let generation = _observationTrackingGenerationObserveIntValue
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveIntValue else {
                                return
                            }
                            self.observeIntValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveStringValue: UInt = 0

                private func observeStringValue() {
                    _observationTrackingGenerationObserveStringValue &+= 1
                    let generation = _observationTrackingGenerationObserveStringValue
                    stringValue = withObservationTracking {
                        classToObserve?.message ?? ""
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveStringValue else {
                                return
                            }
                            self.observeStringValue()
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

                private var _observationTrackingGenerationObserveCount: UInt = 0

                private func observeCount() {
                    _observationTrackingGenerationObserveCount &+= 1
                    let generation = _observationTrackingGenerationObserveCount
                    count = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                return
                            }
                            self.observeCount()
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
                    observeSuperBind()
                    observePrintbindingvalues()
                    observeCount()
                }

                private var _observationTrackingGenerationObserveSuperBind: UInt = 0

                private func observeSuperBind() {
                    _observationTrackingGenerationObserveSuperBind &+= 1
                    let generation = _observationTrackingGenerationObserveSuperBind
                    withObservationTracking {
                        super.bind()
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSuperBind else {
                                return
                            }
                            self.observeSuperBind()
                        }
                    }
                }

                private var _observationTrackingGenerationObservePrintbindingvalues: UInt = 0

                private func observePrintbindingvalues() {
                    _observationTrackingGenerationObservePrintbindingvalues &+= 1
                    let generation = _observationTrackingGenerationObservePrintbindingvalues
                    withObservationTracking {
                        print("binding values")
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObservePrintbindingvalues else {
                                return
                            }
                            self.observePrintbindingvalues()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveCount: UInt = 0

                private func observeCount() {
                    _observationTrackingGenerationObserveCount &+= 1
                    let generation = _observationTrackingGenerationObserveCount
                    count = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                return
                            }
                            self.observeCount()
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
                
                private var _observationTrackingGenerationObserveUpdateCornersradiusdefaultsCorners: UInt = 0

                private func observeUpdateCornersradiusdefaultsCorners() {
                    _observationTrackingGenerationObserveUpdateCornersradiusdefaultsCorners &+= 1
                    let generation = _observationTrackingGenerationObserveUpdateCornersradiusdefaultsCorners
                    withObservationTracking {
                        updateCorners(radius: defaults.corners)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveUpdateCornersradiusdefaultsCorners else {
                                return
                            }
                            self.observeUpdateCornersradiusdefaultsCorners()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveUpdateCornersdefaultsCorners: UInt = 0

                private func observeUpdateCornersdefaultsCorners() {
                    _observationTrackingGenerationObserveUpdateCornersdefaultsCorners &+= 1
                    let generation = _observationTrackingGenerationObserveUpdateCornersdefaultsCorners
                    withObservationTracking {
                        updateCorners(defaults.corners)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveUpdateCornersdefaultsCorners else {
                                return
                            }
                            self.observeUpdateCornersdefaultsCorners()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveUpdateCornersdefaultsCornersanimatedtrue: UInt = 0

                private func observeUpdateCornersdefaultsCornersanimatedtrue() {
                    _observationTrackingGenerationObserveUpdateCornersdefaultsCornersanimatedtrue &+= 1
                    let generation = _observationTrackingGenerationObserveUpdateCornersdefaultsCornersanimatedtrue
                    withObservationTracking {
                        updateCorners(defaults.corners, animated: true)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveUpdateCornersdefaultsCornersanimatedtrue else {
                                return
                            }
                            self.observeUpdateCornersdefaultsCornersanimatedtrue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testFunctionCallTrackingWrapsCompleteMultiArgumentCall() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                render(
                    title: viewModel.title,
                    count: viewModel.count,
                    style: .headline
                )
            }
            """,
            expandedSource: """
                func bind() {
                    observeRendertitleviewModelTitlecountviewModelCountstyleHeadline()
                }

                private var _observationTrackingGenerationObserveRendertitleviewModelTitlecountviewModelCountstyleHeadline: UInt = 0

                private func observeRendertitleviewModelTitlecountviewModelCountstyleHeadline() {
                    _observationTrackingGenerationObserveRendertitleviewModelTitlecountviewModelCountstyleHeadline &+= 1
                    let generation = _observationTrackingGenerationObserveRendertitleviewModelTitlecountviewModelCountstyleHeadline
                    withObservationTracking {
                        render(
                            title: viewModel.title,
                            count: viewModel.count,
                            style: .headline
                        )
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveRendertitleviewModelTitlecountviewModelCountstyleHeadline else {
                                return
                            }
                            self.observeRendertitleviewModelTitlecountviewModelCountstyleHeadline()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testFunctionCallTrackingPreservesContainersAndTrailingClosures() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                render(
                    "Hello \\(viewModel.name)",
                    values: [viewModel.firstItem, viewModel.secondItem],
                    metadata: ["first": viewModel.firstItem],
                    pair: (viewModel.firstItem, viewModel.secondItem)
                ) {
                    use(viewModel.name)
                } completion: {
                    finish()
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish()
                }

                private var _observationTrackingGenerationObserveRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish: UInt = 0

                private func observeRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish() {
                    _observationTrackingGenerationObserveRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish &+= 1
                    let generation = _observationTrackingGenerationObserveRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish
                    withObservationTracking {
                        render(
                            "Hello \\(viewModel.name)",
                            values: [viewModel.firstItem, viewModel.secondItem],
                            metadata: ["first": viewModel.firstItem],
                            pair: (viewModel.firstItem, viewModel.secondItem)
                        ) {
                            use(viewModel.name)
                        } completion: {
                            finish()
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish else {
                                return
                            }
                            self.observeRenderHelloviewModelNamevaluesviewModelFirstItemviewModelSecondItemmetadatafirstviewModelFirstItempairviewModelFirstItemviewModelSecondItemuseviewModelNamecompletionfinish()
                        }
                    }
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

                private var _observationTrackingGenerationObserveLogdefaultsCornersmessagedefaultsCorners: UInt = 0

                private func observeLogdefaultsCornersmessagedefaultsCorners() {
                    _observationTrackingGenerationObserveLogdefaultsCornersmessagedefaultsCorners &+= 1
                    let generation = _observationTrackingGenerationObserveLogdefaultsCornersmessagedefaultsCorners
                    withObservationTracking {
                        log(defaults.corners, message: "defaults.corners")
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveLogdefaultsCornersmessagedefaultsCorners else {
                                return
                            }
                            self.observeLogdefaultsCornersmessagedefaultsCorners()
                        }
                    }
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

                    private var _observationTrackingGenerationObserveValue: UInt = 0

                    private func observeValue() {
                        _observationTrackingGenerationObserveValue &+= 1
                        let generation = _observationTrackingGenerationObserveValue
                        value = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task {
                                guard let self, await generation == self._observationTrackingGenerationObserveValue else {
                                    return
                                }
                                await self.observeValue()
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

                    private var _observationTrackingGenerationObserveValue: UInt = 0

                    private func observeValue() {
                        _observationTrackingGenerationObserveValue &+= 1
                        let generation = _observationTrackingGenerationObserveValue
                        value = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task {
                                guard let self, await generation == self._observationTrackingGenerationObserveValue else {
                                    return
                                }
                                await self.observeValue()
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeCount"] = generation
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeCount"] else {
                                    return
                                }
                                self.observeCount()
                            }
                        }
                    }

                    func cancelObserveCount() {
                        observationTokens.removeValue(forKey: "observeCount")
                    }

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                    private var _observationTrackingGenerationObserveCount: UInt = 0

                    private func observeCount() {
                        _observationTrackingGenerationObserveCount &+= 1
                        let generation = _observationTrackingGenerationObserveCount
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                    return
                                }
                                self.observeCount()
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

                    private var _observationTrackingGenerationObserveCount: UInt = 0

                    private func observeCount() {
                        _observationTrackingGenerationObserveCount &+= 1
                        let generation = _observationTrackingGenerationObserveCount
                        count = withObservationTracking {
                            model.value
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                    return
                                }
                                self.observeCount()
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeUpdateCornersdefaultsCorners"] = generation
                        withObservationTracking {
                            updateCorners(defaults.corners)
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeUpdateCornersdefaultsCorners"] else {
                                    return
                                }
                                self.observeUpdateCornersdefaultsCorners()
                            }
                        }
                    }

                    func cancelObserveUpdateCornersdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersdefaultsCorners")
                    }

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model.nested?.property ?? defaultValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveArrayindex: UInt = 0

                private func observeArrayindex() {
                    _observationTrackingGenerationObserveArrayindex &+= 1
                    let generation = _observationTrackingGenerationObserveArrayindex
                    array[index] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveArrayindex else {
                                return
                            }
                            self.observeArrayindex()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveDictionarykey: UInt = 0

                private func observeDictionarykey() {
                    _observationTrackingGenerationObserveDictionarykey &+= 1
                    let generation = _observationTrackingGenerationObserveDictionarykey
                    dictionary["key"] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveDictionarykey else {
                                return
                            }
                            self.observeDictionarykey()
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

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model
                        .someProperty
                        .chainedCall()
                        .finalValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
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

                private var _observationTrackingGenerationObservePrivateVar: UInt = 0

                private func observePrivateVar() {
                    _observationTrackingGenerationObservePrivateVar &+= 1
                    let generation = _observationTrackingGenerationObservePrivateVar
                    _privateVar = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObservePrivateVar else {
                                return
                            }
                            self.observePrivateVar()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveDollarVar: UInt = 0

                private func observeDollarVar() {
                    _observationTrackingGenerationObserveDollarVar &+= 1
                    let generation = _observationTrackingGenerationObserveDollarVar
                    $dollarVar = withObservationTracking {
                        model.other
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveDollarVar else {
                                return
                            }
                            self.observeDollarVar()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveVar123: UInt = 0

                private func observeVar123() {
                    _observationTrackingGenerationObserveVar123 &+= 1
                    let generation = _observationTrackingGenerationObserveVar123
                    var123 = withObservationTracking {
                        model.numbered
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveVar123 else {
                                return
                            }
                            self.observeVar123()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroTracksDirectFunctionCallStatements() {
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
                    observePrintStartingobservation()
                    observeValue()
                    observeNSLogObservingvalue()
                    observeName()
                    defer {
                        print("Cleanup")
                    }
                }

                private var _observationTrackingGenerationObservePrintStartingobservation: UInt = 0

                private func observePrintStartingobservation() {
                    _observationTrackingGenerationObservePrintStartingobservation &+= 1
                    let generation = _observationTrackingGenerationObservePrintStartingobservation
                    withObservationTracking {
                        print("Starting observation")
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObservePrintStartingobservation else {
                                return
                            }
                            self.observePrintStartingobservation()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model.count
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveNSLogObservingvalue: UInt = 0

                private func observeNSLogObservingvalue() {
                    _observationTrackingGenerationObserveNSLogObservingvalue &+= 1
                    let generation = _observationTrackingGenerationObserveNSLogObservingvalue
                    withObservationTracking {
                        NSLog("Observing value")
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveNSLogObservingvalue else {
                                return
                            }
                            self.observeNSLogObservingvalue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveName: UInt = 0

                private func observeName() {
                    _observationTrackingGenerationObserveName &+= 1
                    let generation = _observationTrackingGenerationObserveName
                    name = withObservationTracking {
                        model.name
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveName else {
                                return
                            }
                            self.observeName()
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
                    return
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
                            return
                        }
                    guard let unwrappedValue = optionalValue else {
                            return
                        }
                    bindCallCount += 1
                    observeObservedValue()
                }

                private var _observationTrackingGenerationObserveObservedValue: UInt = 0

                private func observeObservedValue() {
                    _observationTrackingGenerationObserveObservedValue &+= 1
                    let generation = _observationTrackingGenerationObserveObservedValue
                    observedValue = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveObservedValue else {
                                return
                            }
                            self.observeObservedValue()
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

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model.nested.property.subProperty
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveText: UInt = 0

                private func observeText() {
                    _observationTrackingGenerationObserveText &+= 1
                    let generation = _observationTrackingGenerationObserveText
                    text = withObservationTracking {
                        model.ui?.label?.text ?? "default"
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveText else {
                                return
                            }
                            self.observeText()
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

                private var _observationTrackingGenerationObserveResult: UInt = 0

                private func observeResult() {
                    _observationTrackingGenerationObserveResult &+= 1
                    let generation = _observationTrackingGenerationObserveResult
                    result = withObservationTracking {
                        (model.value * 2) + (other.value ?? 0)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveResult else {
                                return
                            }
                            self.observeResult()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveFormatted: UInt = 0

                private func observeFormatted() {
                    _observationTrackingGenerationObserveFormatted &+= 1
                    let generation = _observationTrackingGenerationObserveFormatted
                    formatted = withObservationTracking {
                        "Total: \\(model.a + model.b)"
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveFormatted else {
                                return
                            }
                            self.observeFormatted()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveConditional: UInt = 0

                private func observeConditional() {
                    _observationTrackingGenerationObserveConditional &+= 1
                    let generation = _observationTrackingGenerationObserveConditional
                    conditional = withObservationTracking {
                        model.flag ? model.trueValue : model.falseValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveConditional else {
                                return
                            }
                            self.observeConditional()
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

                private var _observationTrackingGenerationObserveResult: UInt = 0

                private func observeResult() {
                    _observationTrackingGenerationObserveResult &+= 1
                    let generation = _observationTrackingGenerationObserveResult
                    result = withObservationTracking {
                        calculateValue(from: model.input)
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveResult else {
                                return
                            }
                            self.observeResult()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveTransformed: UInt = 0

                private func observeTransformed() {
                    _observationTrackingGenerationObserveTransformed &+= 1
                    let generation = _observationTrackingGenerationObserveTransformed
                    transformed = withObservationTracking {
                        model.data.map {
                            $0.processed
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveTransformed else {
                                return
                            }
                            self.observeTransformed()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveFiltered: UInt = 0

                private func observeFiltered() {
                    _observationTrackingGenerationObserveFiltered &+= 1
                    let generation = _observationTrackingGenerationObserveFiltered
                    filtered = withObservationTracking {
                        model.items.filter {
                            $0.isValid
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveFiltered else {
                                return
                            }
                            self.observeFiltered()
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

                private var _observationTrackingGenerationObserveSelfProperty: UInt = 0

                private func observeSelfProperty() {
                    _observationTrackingGenerationObserveSelfProperty &+= 1
                    let generation = _observationTrackingGenerationObserveSelfProperty
                    self.property = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSelfProperty else {
                                return
                            }
                            self.observeSelfProperty()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveClass: UInt = 0

                private func observeClass() {
                    _observationTrackingGenerationObserveClass &+= 1
                    let generation = _observationTrackingGenerationObserveClass
                    `class` = withObservationTracking {
                        model.keyword
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveClass else {
                                return
                            }
                            self.observeClass()
                        }
                    }
                }

                private var _observationTrackingGenerationObservePropertywithunderscores: UInt = 0

                private func observePropertywithunderscores() {
                    _observationTrackingGenerationObservePropertywithunderscores &+= 1
                    let generation = _observationTrackingGenerationObservePropertywithunderscores
                    property_with_underscores = withObservationTracking {
                        model.data
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObservePropertywithunderscores else {
                                return
                            }
                            self.observePropertywithunderscores()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveCamelCaseProperty: UInt = 0

                private func observeCamelCaseProperty() {
                    _observationTrackingGenerationObserveCamelCaseProperty &+= 1
                    let generation = _observationTrackingGenerationObserveCamelCaseProperty
                    camelCaseProperty = withObservationTracking {
                        model.camelCase
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveCamelCaseProperty else {
                                return
                            }
                            self.observeCamelCaseProperty()
                        }
                    }
                }

                private var _observationTrackingGenerationObservePascalCaseProperty: UInt = 0

                private func observePascalCaseProperty() {
                    _observationTrackingGenerationObservePascalCaseProperty &+= 1
                    let generation = _observationTrackingGenerationObservePascalCaseProperty
                    PascalCaseProperty = withObservationTracking {
                        model.PascalCase
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObservePascalCaseProperty else {
                                return
                            }
                            self.observePascalCaseProperty()
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeProp1"] = generation
                        prop1 = withObservationTracking {
                            model.value1
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeProp1"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeProp2"] = generation
                        prop2 = withObservationTracking {
                            model.value2
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeProp2"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeProp3"] = generation
                        prop3 = withObservationTracking {
                            model.value3
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeProp3"] else {
                                    return
                                }
                                self.observeProp3()
                            }
                        }
                    }

                    func cancelObserveProp3() {
                        observationTokens.removeValue(forKey: "observeProp3")
                    }

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                private var _observationTrackingGenerationObserveItems0: UInt = 0

                private func observeItems0() {
                    _observationTrackingGenerationObserveItems0 &+= 1
                    let generation = _observationTrackingGenerationObserveItems0
                    items[0] = withObservationTracking {
                        model.firstItem
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveItems0 else {
                                return
                            }
                            self.observeItems0()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveDatakey: UInt = 0

                private func observeDatakey() {
                    _observationTrackingGenerationObserveDatakey &+= 1
                    let generation = _observationTrackingGenerationObserveDatakey
                    data["key"] = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveDatakey else {
                                return
                            }
                            self.observeDatakey()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveNestedArrayindex: UInt = 0

                private func observeNestedArrayindex() {
                    _observationTrackingGenerationObserveNestedArrayindex &+= 1
                    let generation = _observationTrackingGenerationObserveNestedArrayindex
                    nested.array[index] = withObservationTracking {
                        model.nestedValue
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveNestedArrayindex else {
                                return
                            }
                            self.observeNestedArrayindex()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveViewLayerBackgroundColor: UInt = 0

                private func observeViewLayerBackgroundColor() {
                    _observationTrackingGenerationObserveViewLayerBackgroundColor &+= 1
                    let generation = _observationTrackingGenerationObserveViewLayerBackgroundColor
                    view.layer.backgroundColor = withObservationTracking {
                        model.color
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveViewLayerBackgroundColor else {
                                return
                            }
                            self.observeViewLayerBackgroundColor()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveSelfItemscurrentIndexTitle: UInt = 0

                private func observeSelfItemscurrentIndexTitle() {
                    _observationTrackingGenerationObserveSelfItemscurrentIndexTitle &+= 1
                    let generation = _observationTrackingGenerationObserveSelfItemscurrentIndexTitle
                    self.items[currentIndex].title = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSelfItemscurrentIndexTitle else {
                                return
                            }
                            self.observeSelfItemscurrentIndexTitle()
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

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model.data // inline comment
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveName: UInt = 0

                private func observeName() {
                    _observationTrackingGenerationObserveName &+= 1
                    let generation = _observationTrackingGenerationObserveName
                    name = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveName else {
                                return
                            }
                            self.observeName()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveCount: UInt = 0

                private func observeCount() {
                    _observationTrackingGenerationObserveCount &+= 1
                    let generation = _observationTrackingGenerationObserveCount
                    count = withObservationTracking {
                        model.number
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                return
                            }
                            self.observeCount()
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

                private var _observationTrackingGenerationObserveVeryLongPropertyChainWithManySegmentsFinal: UInt = 0

                private func observeVeryLongPropertyChainWithManySegmentsFinal() {
                    _observationTrackingGenerationObserveVeryLongPropertyChainWithManySegmentsFinal &+= 1
                    let generation = _observationTrackingGenerationObserveVeryLongPropertyChainWithManySegmentsFinal
                    very.long.property.chain.with.many.segments.final = withObservationTracking {
                        model.value
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveVeryLongPropertyChainWithManySegmentsFinal else {
                                return
                            }
                            self.observeVeryLongPropertyChainWithManySegmentsFinal()
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

                private var _observationTrackingGenerationObserveValue: UInt = 0

                private func observeValue() {
                    _observationTrackingGenerationObserveValue &+= 1
                    let generation = _observationTrackingGenerationObserveValue
                    value = withObservationTracking {
                        model.data
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveValue else {
                                return
                            }
                            self.observeValue()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveName: UInt = 0

                private func observeName() {
                    _observationTrackingGenerationObserveName &+= 1
                    let generation = _observationTrackingGenerationObserveName
                    name = withObservationTracking {
                        model.title
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveName else {
                                return
                            }
                            self.observeName()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveCount: UInt = 0

                private func observeCount() {
                    _observationTrackingGenerationObserveCount &+= 1
                    let generation = _observationTrackingGenerationObserveCount
                    count = withObservationTracking {
                        model.number
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveCount else {
                                return
                            }
                            self.observeCount()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveText: UInt = 0

                private func observeText() {
                    _observationTrackingGenerationObserveText &+= 1
                    let generation = _observationTrackingGenerationObserveText
                    text = withObservationTracking {
                        model
                            .formatted
                            .string
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveText else {
                                return
                            }
                            self.observeText()
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeValue1"] = generation
                        value1 = withObservationTracking {
                            model.primary
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeValue1"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeValue2"] = generation
                        value2 = withObservationTracking {
                            model.secondary
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeValue2"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeName"] = generation
                        name = withObservationTracking {
                            model.name
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeName"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeCount"] = generation
                        count = withObservationTracking {
                            model.count
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeCount"] else {
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeIsEnabled"] = generation
                        isEnabled = withObservationTracking {
                            model.enabled
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeIsEnabled"] else {
                                    return
                                }
                                self.observeIsEnabled()
                            }
                        }
                    }

                    func cancelObserveIsEnabled() {
                        observationTokens.removeValue(forKey: "observeIsEnabled")
                    }

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeValue"] = generation
                        value = withObservationTracking {
                            model.data
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeValue"] else {
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

                    private var observationTokens: [String: UInt] = [:]
                    private var observationGeneration: UInt = 0
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

                private var _observationTrackingGenerationObserveFooBar: UInt = 0

                private func observeFooBar() {
                    _observationTrackingGenerationObserveFooBar &+= 1
                    let generation = _observationTrackingGenerationObserveFooBar
                    foo.bar = withObservationTracking {
                        model.first
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveFooBar else {
                                return
                            }
                            self.observeFooBar()
                        }
                    }
                }

                private var _observationTrackingGenerationObserveFooBar2: UInt = 0

                private func observeFooBar2() {
                    _observationTrackingGenerationObserveFooBar2 &+= 1
                    let generation = _observationTrackingGenerationObserveFooBar2
                    fooBar = withObservationTracking {
                        model.second
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveFooBar2 else {
                                return
                            }
                            self.observeFooBar2()
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

                private var _observationTrackingGenerationObserveSubtitle: UInt = 0

                private func observeSubtitle() {
                    _observationTrackingGenerationObserveSubtitle &+= 1
                    let generation = _observationTrackingGenerationObserveSubtitle
                    withObservationTracking {
                        if model.isEnabled {
                            subtitle = model.subtitle
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSubtitle else {
                                return
                            }
                            self.observeSubtitle()
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

                private var _observationTrackingGenerationObserveSubtitle: UInt = 0

                private func observeSubtitle() {
                    _observationTrackingGenerationObserveSubtitle &+= 1
                    let generation = _observationTrackingGenerationObserveSubtitle
                    withObservationTracking {
                        if model.someValue {
                            subtitle = "A"
                        } else {
                            subtitle = "B"
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSubtitle else {
                                return
                            }
                            self.observeSubtitle()
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

                private var _observationTrackingGenerationObserveSubtitle: UInt = 0

                private func observeSubtitle() {
                    _observationTrackingGenerationObserveSubtitle &+= 1
                    let generation = _observationTrackingGenerationObserveSubtitle
                    withObservationTracking {
                        if let value = model.someValue {
                            subtitle = value
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSubtitle else {
                                return
                            }
                            self.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksConditionalFunctionCall() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                if viewModel.isSomethingEnabled {
                    someFunction()
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSomeFunction()
                }

                private var _observationTrackingGenerationObserveSomeFunction: UInt = 0

                private func observeSomeFunction() {
                    _observationTrackingGenerationObserveSomeFunction &+= 1
                    let generation = _observationTrackingGenerationObserveSomeFunction
                    withObservationTracking {
                        if viewModel.isSomethingEnabled {
                            someFunction()
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSomeFunction else {
                                return
                            }
                            self.observeSomeFunction()
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

                private var _observationTrackingGenerationObserveSubtitle: UInt = 0

                private func observeSubtitle() {
                    _observationTrackingGenerationObserveSubtitle &+= 1
                    let generation = _observationTrackingGenerationObserveSubtitle
                    subtitle = withObservationTracking {
                        if model.value {
                            "A"
                        } else {
                            "B"
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSubtitle else {
                                return
                            }
                            self.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksSwitchExpressionAssignment() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                titleLabel.text = switch viewModel.someValue {
                case .hello: "Hello"
                case .bye: "bye!"
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeTitleLabelText()
                }

                private var _observationTrackingGenerationObserveTitleLabelText: UInt = 0

                private func observeTitleLabelText() {
                    _observationTrackingGenerationObserveTitleLabelText &+= 1
                    let generation = _observationTrackingGenerationObserveTitleLabelText
                    titleLabel.text = withObservationTracking {
                        switch viewModel.someValue {
                        case .hello:
                            "Hello"
                        case .bye:
                            "bye!"
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveTitleLabelText else {
                                return
                            }
                            self.observeTitleLabelText()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksSwitchFunctionCalls() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                switch viewModel.someValue {
                case .hello:
                    sayHello()
                case .bye:
                    sayBye()
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSayHello()
                }

                private var _observationTrackingGenerationObserveSayHello: UInt = 0

                private func observeSayHello() {
                    _observationTrackingGenerationObserveSayHello &+= 1
                    let generation = _observationTrackingGenerationObserveSayHello
                    withObservationTracking {
                        switch viewModel.someValue {
                        case .hello:
                            sayHello()
                        case .bye:
                            sayBye()
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSayHello else {
                                return
                            }
                            self.observeSayHello()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroTracksAssignmentInNestedSwitchControlFlow() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func bind() {
                switch viewModel.someValue {
                case .hello where viewModel.isEnabled:
                    if viewModel.shouldShowSubtitle {
                        subtitle = viewModel.subtitle
                    }
                case .bye, .unknown:
                    subtitle = "Unavailable"
                default:
                    break
                }
            }
            """,
            expandedSource: """
                func bind() {
                    observeSubtitle()
                }

                private var _observationTrackingGenerationObserveSubtitle: UInt = 0

                private func observeSubtitle() {
                    _observationTrackingGenerationObserveSubtitle &+= 1
                    let generation = _observationTrackingGenerationObserveSubtitle
                    withObservationTracking {
                        switch viewModel.someValue {
                        case .hello where viewModel.isEnabled:
                            if viewModel.shouldShowSubtitle {
                                subtitle = viewModel.subtitle
                            }
                        case .bye, .unknown:
                            subtitle = "Unavailable"
                        default:
                            break
                        }
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            guard let self, generation == self._observationTrackingGenerationObserveSubtitle else {
                                return
                            }
                            self.observeSubtitle()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }
}
#endif
