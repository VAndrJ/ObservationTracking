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

                private func observeIntValue() {
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeIntValue()
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

                private func observeIntValue() {
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task { @MainActor in
                            self?.observeIntValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithActorIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: .actor)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                }

                private func observeIntValue() {
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        Task {
                            await self?.observeIntValue()
                        }
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testObservationTrackingMacroWithNoneIsolation() {
        assertMacroExpansion(
            """
            @ObservationTracking(isolation: .none)
            func observeValues() {
                intValue = classToObserve?.count ?? 0
            }
            """,
            expandedSource: """
                func observeValues() {
                    observeIntValue()
                }

                private func observeIntValue() {
                    intValue = withObservationTracking {
                        classToObserve?.count ?? 0
                    } onChange: { [weak self] in
                        self?.observeIntValue()
                    }
                }
                """,
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

                        let token = UUID().uuidString
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = token
                        updateCorners(radius:
                            withObservationTracking {
                                defaults.corners
                            } onChange: { [weak self] in
                                Task { @MainActor in
                                    guard let self, token == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                        return
                                    }
                                    self.observeUpdateCornersradiusdefaultsCorners()
                                }
                            }
                        )
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled else {
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

    func testObservationTrackingMacroWithCancellationActorIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking(isolation: .actor)
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

                        let token = UUID().uuidString
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = token
                        updateCorners(radius:
                            withObservationTracking {
                                defaults.corners
                            } onChange: { [weak self] in
                                Task {
                                    guard let self, await token == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                        return
                                    }
                                    await self.observeUpdateCornersradiusdefaultsCorners()
                                }
                            }
                        )
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled else {
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

    func testObservationTrackingMacroWithCancellationNoneIsolation() {
        assertMacroExpansion(
            """
            @CancellableObservation
            class Example {
                @ObservationTracking(isolation: .none)
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

                        let token = UUID().uuidString
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = token
                        updateCorners(radius:
                            withObservationTracking {
                                defaults.corners
                            } onChange: { [weak self] in
                                guard let self, token == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                    return
                                }
                                self.observeUpdateCornersradiusdefaultsCorners()
                            }
                        )
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled else {
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

                        let token = UUID().uuidString
                        observationTokens["observeUpdateCornersradiusdefaultsCorners"] = token
                        updateCorners(radius:
                            withObservationTracking {
                                defaults.corners
                            } onChange: { [weak self] in
                                Task { @MainActor in
                                    guard let self, token == self.observationTokens["observeUpdateCornersradiusdefaultsCorners"] else {
                                        return
                                    }
                                    self.observeUpdateCornersradiusdefaultsCorners()
                                }
                            }
                        )
                    }

                    func cancelObserveUpdateCornersradiusdefaultsCorners() {
                        observationTokens.removeValue(forKey: "observeUpdateCornersradiusdefaultsCorners")
                    }

                    private var observationTokens: [String: String] = [:]
                    private var isObservingEnabled = true

                    func stopObservations() {
                        isObservingEnabled = false
                        observationTokens.removeAll()
                    }

                    func startObservationsIfNeeded() {
                        guard !isObservingEnabled else {
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
