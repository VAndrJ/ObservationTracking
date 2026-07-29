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
        assertClassMethodMacroExpansion(
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
        assertClassMethodMacroExpansion(
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
        assertClassMethodMacroExpansion(
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
        assertClassMethodMacroExpansion(
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
                            await self?._observationTrackingReobserveObserveIntValue(generation: generation)
                        }
                    }
                }

                private func _observationTrackingReobserveObserveIntValue(generation: UInt) async {
                    guard generation == _observationTrackingGenerationObserveIntValue else {
                        return
                    }
                    observeIntValue()
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroRejectsSynchronousIsolation() {
        assertClassMethodMacroExpansion(
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
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ObservationTracking isolation must be nil, .mainActor, or .task", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithQualifiedIsolation() {
        assertClassMethodMacroExpansion(
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
                            await self?._observationTrackingReobserveObserveIntValue(generation: generation)
                        }
                    }
                }

                private func _observationTrackingReobserveObserveIntValue(generation: UInt) async {
                    guard generation == _observationTrackingGenerationObserveIntValue else {
                        return
                    }
                    observeIntValue()
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroRejectsDynamicIsolationExpression() {
        assertClassMethodMacroExpansion(
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
                DiagnosticSpec(message: "@ObservationTracking isolation must be nil, .mainActor, or .task", line: 3, column: 1)
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
                                await self?._observationTrackingReobserveObserveUpdateCornersradiusdefaultsCorners(generation: generation)
                            }
                        }
                    }

                    private func _observationTrackingReobserveObserveUpdateCornersradiusdefaultsCorners(generation: UInt) async {
                        guard generation == observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                            return
                        }
                        observeUpdateCornersradiusdefaultsCorners()
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
