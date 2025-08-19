import Observation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ObservationTrackingMacros)
import ObservationTrackingMacros
import ObservationTracking

@MainActor
let testMacros: [String: Macro.Type] = [
    "ObservationTracking": ObservationTrackingMacro.self
]

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
final class ObservationTrackingTests: XCTestCase {
    @Observable
    class TestModel {
        var count = 0
        var name = "Test"
        var isEnabled = false
        var percentage = 0.0
    }

    @MainActor
    class TestObserver {
        weak var model: TestModel?
        var observedCount = -1
        var observedName = "Initial"
        var observedIsEnabled = true
        var observedPercentage = -1.0

        init(model: TestModel) {
            self.model = model

            startObserving()
        }

        @ObservationTracking
        func startObserving() {
            observedCount = model?.count ?? 0
            observedName = model?.name ?? ""
            observedIsEnabled = model?.isEnabled ?? false
            observedPercentage = model?.percentage ?? 0.0
        }

        deinit {
            print("TestObserver deallocated")
        }
    }

    @MainActor
    func testObservationTrackingWithRealObservableObject() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)

        XCTAssertEqual(observer.observedCount, 0)
        XCTAssertEqual(observer.observedName, "Test")
        XCTAssertEqual(observer.observedIsEnabled, false)
        XCTAssertEqual(observer.observedPercentage, 0.0)

        model.count = 42
        model.name = "Updated"
        model.isEnabled = true
        model.percentage = 75.5
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.observedCount, 42)
        XCTAssertEqual(observer.observedName, "Updated")
        XCTAssertEqual(observer.observedIsEnabled, true)
        XCTAssertEqual(observer.observedPercentage, 75.5)
    }

    @Observable
    class SinglePropertyModel {
        var value = 10
    }

    @MainActor
    class SinglePropertyObserver {
        weak var model: SinglePropertyModel?
        var observedValue = 0

        init(model: SinglePropertyModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            observedValue = model?.value ?? 0
        }
    }

    @MainActor
    func testSinglePropertyObservation() async throws {
        let model = SinglePropertyModel()
        let observer = SinglePropertyObserver(model: model)

        // Initial value
        XCTAssertEqual(observer.observedValue, 10)

        model.value = 25
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.observedValue, 25)
    }

    @Observable
    class ComplexModel {
        var baseValue = 10
        var multiplier = 2
        var offset = 5
    }

    @MainActor
    class ComplexObserver {
        weak var model: ComplexModel?
        var computedResult = 0
        var formattedString = ""

        init(model: ComplexModel) {
            self.model = model
            startTracking()
        }

        @ObservationTracking
        func startTracking() {
            computedResult = (model?.baseValue ?? 0) * (model?.multiplier ?? 1) + (model?.offset ?? 0)
            formattedString = "Result: \((model?.baseValue ?? 0) * (model?.multiplier ?? 1))"
        }
    }
    @MainActor
    func testComplexExpressionObservation() async throws {
        let model = ComplexModel()
        let observer = ComplexObserver(model: model)

        XCTAssertEqual(observer.computedResult, 25)
        XCTAssertEqual(observer.formattedString, "Result: 20")

        model.baseValue = 15
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.computedResult, 35)
        XCTAssertEqual(observer.formattedString, "Result: 30")

        model.multiplier = 3
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.computedResult, 50)
        XCTAssertEqual(observer.formattedString, "Result: 45")
    }

    @Observable
    class OptionalModel {
        var optionalValue: Int? = nil
        var optionalString: String? = nil
    }

    @MainActor
    class OptionalObserver {
        weak var model: OptionalModel?
        var safeValue = 0
        var safeString = ""

        init(model: OptionalModel) {
            self.model = model
            observeOptionals()
        }

        @ObservationTracking
        func observeOptionals() {
            safeValue = model?.optionalValue ?? -1
            safeString = model?.optionalString ?? "default"
        }
    }

    @MainActor
    func testNilHandlingInObservation() async throws {
        let model = OptionalModel()
        let observer = OptionalObserver(model: model)

        // Initial nil values should use defaults
        XCTAssertEqual(observer.safeValue, -1)
        XCTAssertEqual(observer.safeString, "default")

        model.optionalValue = 42
        model.optionalString = "hello"
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.safeValue, 42)
        XCTAssertEqual(observer.safeString, "hello")

        model.optionalValue = nil
        model.optionalString = nil
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.safeValue, -1)
        XCTAssertEqual(observer.safeString, "default")
    }

    @Observable
    class OptionalModelWithoutDefaults {
        var optionalValue: Int? = nil
        var optionalString: String? = nil
    }

    @MainActor
    class OptionalObserverWithoutDefaults {
        weak var model: OptionalModelWithoutDefaults?
        var safeValue: Int?
        var safeString: String?

        init(model: OptionalModelWithoutDefaults) {
            self.model = model
            observeOptionals()
        }

        @ObservationTracking
        func observeOptionals() {
            safeValue = model?.optionalValue
            safeString = model?.optionalString
        }
    }

    @MainActor
    func testNilHandlingWithoutDefaults() async throws {
        let model = OptionalModelWithoutDefaults()
        let observer = OptionalObserverWithoutDefaults(model: model)

        // Initial nil values should remain nil
        XCTAssertNil(observer.safeValue)
        XCTAssertNil(observer.safeString)

        model.optionalValue = 42
        model.optionalString = "hello"
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.safeValue, 42)
        XCTAssertEqual(observer.safeString, "hello")

        model.optionalValue = nil
        model.optionalString = nil
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNil(observer.safeValue)
        XCTAssertNil(observer.safeString)
    }

    @MainActor
    func testMultipleObserversOnSameModel() async throws {
        let model = TestModel()

        let observer1 = TestObserver(model: model)
        let observer2 = TestObserver(model: model)

        // Both should have initial values
        XCTAssertEqual(observer1.observedCount, 0)
        XCTAssertEqual(observer2.observedCount, 0)

        model.count = 15
        model.name = "Shared"
        try await Task.sleep(for: .milliseconds(50))

        // Both observers should see the change
        XCTAssertEqual(observer1.observedCount, 15)
        XCTAssertEqual(observer1.observedName, "Shared")
        XCTAssertEqual(observer2.observedCount, 15)
        XCTAssertEqual(observer2.observedName, "Shared")
    }
}

// MARK: - Macro Expansion Tests
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
}
#endif
