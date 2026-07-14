//
//  ObservationTrackingTests+ViewController.swift
//  ObservationTracking
//
//  Created by VAndrJ on 13.09.2025.
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
    func testStartObservationsFunctionAdd() {
        assertMacroExpansion(
            """
            @StartObservations
            func setupBinding() {
                count = model.value
            }
            """,
            expandedSource: """
                func setupBinding() {
                    defer {
                        startObservationsIfNeeded()
                    }
                    count = model.value
                }
                """,
            macros: testMacros
        )
    }

    func testStopObservationsFunctionAdd() {
        assertMacroExpansion(
            """
            @StopObservations
            func cleanup() {
                observationTokens.removeAll()
            }
            """,
            expandedSource: """
                func cleanup() {
                    defer {
                        stopObservations()
                    }
                    observationTokens.removeAll()
                }
                """,
            macros: testMacros
        )
    }

    func testObservationControllerCycle() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
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

                    override func viewWillAppear(_ animated: Bool) {
                        super.viewWillAppear(animated)
                        startObservationsIfNeeded()
                    }

                    override func viewDidDisappear(_ animated: Bool) {
                        super.viewDidDisappear(animated)
                        stopObservations()
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

    func testObservationControllerCycleWillAppear() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }
                                
                override func viewWillAppear(_ animated: Bool) {
                    super.viewWillAppear(animated)
                    print(#function)
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
                                    
                    override func viewWillAppear(_ animated: Bool) {
                        defer {
                            startObservationsIfNeeded()
                        }
                        super.viewWillAppear(animated)
                        print(#function)
                    }

                    override func viewDidDisappear(_ animated: Bool) {
                        super.viewDidDisappear(animated)
                        stopObservations()
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

    func testObservationControllerCycleDidDisappear() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }
                                
                override func viewDidDisappear(_ animated: Bool) {
                    super.viewDidDisappear(animated)
                    print(#function)
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
                                    
                    override func viewDidDisappear(_ animated: Bool) {
                        defer {
                            stopObservations()
                        }
                        super.viewDidDisappear(animated)
                        print(#function)
                    }

                    override func viewWillAppear(_ animated: Bool) {
                        super.viewWillAppear(animated)
                        startObservationsIfNeeded()
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

    func testObservationControllerWithStartObservations() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }

                @StartObservations
                func viewDidLoad() {
                    super.viewDidLoad()
                    setupUI()
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
                    func viewDidLoad() {
                        defer {
                            startObservationsIfNeeded()
                        }
                        super.viewDidLoad()
                        setupUI()
                    }

                    override func viewDidDisappear(_ animated: Bool) {
                        super.viewDidDisappear(animated)
                        stopObservations()
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

    func testObservationControllerWithStopObservations() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }

                @StopObservations
                func viewWillDisappear() {
                    cleanup()
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
                    func viewWillDisappear() {
                        defer {
                            stopObservations()
                        }
                        cleanup()
                    }

                    override func viewWillAppear(_ animated: Bool) {
                        super.viewWillAppear(animated)
                        startObservationsIfNeeded()
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

    func testObservationControllerWithBothCustomMacros() {
        assertMacroExpansion(
            """
            @CancellableObservation(screen: true)
            class Example {
                @ObservationTracking
                func bind() {
                    count = model.value
                }

                @StartObservations
                func viewDidLoad() {
                    super.viewDidLoad()
                    setupUI()
                }

                @StopObservations
                func viewWillDisappear() {
                    cleanup()
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
                    func viewDidLoad() {
                        defer {
                            startObservationsIfNeeded()
                        }
                        super.viewDidLoad()
                        setupUI()
                    }
                    func viewWillDisappear() {
                        defer {
                            stopObservations()
                        }
                        cleanup()
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
