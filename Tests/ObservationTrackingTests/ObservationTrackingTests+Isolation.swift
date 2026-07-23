//
//  ObservationTrackingTests+Isolation.swift
//  ObservationTracking
//
//  Created by VAndrJ on 14.09.2025.
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
    func testObservationTrackingMacroWithDefaultIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
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
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithNilIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: nil)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
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
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithMainActorIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: .mainActor)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
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
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithTaskIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: .task)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                }

                private var _observationTrackingGenerationObserveIntValue: UInt = 0

                private func observeIntValue() {
                    _observationTrackingGenerationObserveIntValue &+= 1
                    let generation = _observationTrackingGenerationObserveIntValue
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task {
                            guard let self, await generation == self._observationTrackingGenerationObserveIntValue else {
                                return
                            }
                            await self.observeIntValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithSynchronousIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: .synchronous)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                }

                private var _observationTrackingGenerationObserveIntValue: UInt = 0

                private func observeIntValue() {
                    _observationTrackingGenerationObserveIntValue &+= 1
                    let generation = _observationTrackingGenerationObserveIntValue
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        guard let self, generation == self._observationTrackingGenerationObserveIntValue else {
                            return
                        }
                        self.observeIntValue()
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithQualifiedIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: OnChangeBlockIsolation.task)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                }

                private var _observationTrackingGenerationObserveIntValue: UInt = 0

                private func observeIntValue() {
                    _observationTrackingGenerationObserveIntValue &+= 1
                    let generation = _observationTrackingGenerationObserveIntValue
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task {
                            guard let self, await generation == self._observationTrackingGenerationObserveIntValue else {
                                return
                            }
                            await self.observeIntValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroRejectsDynamicIsolationExpression() {
        assertMacroExpansion(
            """
            let selectedIsolation: OnChangeBlockIsolation? = .task

            @ObservationTracking(isolation: selectedIsolation)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                let selectedIsolation: OnChangeBlockIsolation? = .task
                func observeValues() {
                    observeIntValue()
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ObservationTracking isolation must be nil or one of .mainActor, .task, or .synchronous", line: 3, column: 1)
            ],
            macros: testMacros
        )
    }

    // MARK: - Cancellation Tests with Isolation

    func testObservationTrackingMacroWithCancellationDefaultIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking
                func bind() {
                    updateCorners(radius: defaults.corners)
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeUpdateCornersradiusdefaultsCorners()
                    }

                    func observeUpdateCornersradiusdefaultsCorners() {
                        guard isObservingEnabled else {
                            return
                        }

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = generation
                        withObservationTracking {
                            updateCorners(radius: defaults.corners)
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                    return
                                }
                                self.observeUpdateCornersradiusdefaultsCorners()
                            }
                        }
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
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

    func testObservationTrackingMacroWithCancellationTaskIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking(isolation: .task)
                func bind() {
                    updateCorners(radius: defaults.corners)
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeUpdateCornersradiusdefaultsCorners()
                    }

                    func observeUpdateCornersradiusdefaultsCorners() {
                        guard isObservingEnabled else {
                            return
                        }

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = generation
                        withObservationTracking {
                            updateCorners(radius: defaults.corners)
                        } onChange: { [weak self] in
                            Task {
                                guard let self, await generation == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                    return
                                }
                                await self.observeUpdateCornersradiusdefaultsCorners()
                            }
                        }
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
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

    func testObservationTrackingMacroWithCancellationSynchronousIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking(isolation: .synchronous)
                func bind() {
                    updateCorners(radius: defaults.corners)
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeUpdateCornersradiusdefaultsCorners()
                    }

                    func observeUpdateCornersradiusdefaultsCorners() {
                        guard isObservingEnabled else {
                            return
                        }

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = generation
                        withObservationTracking {
                            updateCorners(radius: defaults.corners)
                        } onChange: { [weak self] in
                            guard let self, generation == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                return
                            }
                            self.observeUpdateCornersradiusdefaultsCorners()
                        }
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
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

    func testObservationTrackingMacroWithCancellationMainActorIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking(isolation: .mainActor)
                func bind() {
                    updateCorners(radius: defaults.corners)
                }
            }
            """,
            expandedSource: """
                class Example {
                    func bind() {
                        observeUpdateCornersradiusdefaultsCorners()
                    }

                    func observeUpdateCornersradiusdefaultsCorners() {
                        guard isObservingEnabled else {
                            return
                        }

                        observationGeneration &+= 1
                        let generation = observationGeneration
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = generation
                        withObservationTracking {
                            updateCorners(radius: defaults.corners)
                        } onChange: { [weak self] in
                            Task { @MainActor in
                                guard let self, generation == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                    return
                                }
                                self.observeUpdateCornersradiusdefaultsCorners()
                            }
                        }
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
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
}
#endif
