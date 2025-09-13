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
    "ObservationTracking": ObservationTrackingMacro.self,
    "CancellableObservation": CancellableObservationMacro.self,
    "StartObservations": StartObservationsMacro.self,
    "StopObservations": StopObservationsMacro.self,
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

    @Observable
    class RapidTestModel {
        var counter = 0
    }

    @MainActor
    class RapidObserver {
        weak var model: RapidTestModel?
        var observedCounter = -1

        init(model: RapidTestModel) {
            self.model = model
            startObserving()
        }

        @ObservationTracking
        func startObserving() {
            observedCounter = model?.counter ?? -1
        }
    }

    @MainActor
    func testRapidObserverCreationAndDestruction() async throws {
        let model = RapidTestModel()

        for i in 0..<100 {
            let observer = RapidObserver(model: model)
            XCTAssertEqual(observer.observedCounter, model.counter)
            model.counter = i
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    @Observable
    class EdgeCaseModel {
        var simpleValue = 0
        var nestedObject: NestedClass? = NestedClass()
        var arrayValue: [Int] = []
    }

    @Observable
    class NestedClass {
        var property = "nested"
    }

    @MainActor
    class EdgeCaseObserver {
        weak var model: EdgeCaseModel?
        var observedSimple = -1
        var observedNested = ""
        var observedArray: [Int] = []
        var observedComputed = ""

        init(model: EdgeCaseModel) {
            self.model = model
            observeEdgeCases()
        }

        @ObservationTracking
        func observeEdgeCases() {
            observedSimple = model?.simpleValue ?? -1
            observedNested = model?.nestedObject?.property ?? ""
            observedArray = model?.arrayValue ?? []
            observedComputed = "Value: \(model?.simpleValue ?? 0)"
        }
    }

    @MainActor
    func testAssignmentPatternEdgeCases() async throws {
        let model = EdgeCaseModel()
        let observer = EdgeCaseObserver(model: model)

        XCTAssertEqual(observer.observedSimple, 0)
        XCTAssertEqual(observer.observedNested, "nested")
        XCTAssertEqual(observer.observedArray, [])
        XCTAssertEqual(observer.observedComputed, "Value: 0")

        model.simpleValue = 42
        model.nestedObject?.property = "updated"
        model.arrayValue = [1, 2, 3]
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.observedSimple, 42)
        XCTAssertEqual(observer.observedNested, "updated")
        XCTAssertEqual(observer.observedArray, [1, 2, 3])
        XCTAssertEqual(observer.observedComputed, "Value: 42")
    }

    @Observable
    class LifecycleModel {
        var value = 0
    }

    @CancellableObservation
    @MainActor
    class CancellableObserver {
        weak var model: LifecycleModel?
        var observedValue = -1
        var bindCallCount = 0

        init(model: LifecycleModel) {
            self.model = model
            bind()
        }

        @ObservationTracking
        func bind() {
            bindCallCount += 1
            observedValue = model?.value ?? -1
        }
    }

    @MainActor
    func testCancellableObservationLifecycle() async throws {
        let model = LifecycleModel()
        let observer = CancellableObserver(model: model)

        XCTAssertEqual(observer.observedValue, 0)
        XCTAssertEqual(observer.bindCallCount, 1)

        model.value = 10
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, 10)
        let initialCallCount = observer.bindCallCount

        observer.stopObservations()

        model.value = 20
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, 10)
        XCTAssertEqual(observer.bindCallCount, initialCallCount)

        observer.startObservationsIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, 20)
        XCTAssertGreaterThan(observer.bindCallCount, initialCallCount)

        model.value = 30
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, 30)
    }

    @Observable
    class RapidUpdatesModel {
        var rapidValue = 0
    }

    @CancellableObservation
    @MainActor
    class TokenObserver {
        weak var model: RapidUpdatesModel?
        var observedValue = -1

        init(model: RapidUpdatesModel) {
            self.model = model
            bind()
        }

        @ObservationTracking
        func bind() {
            observedValue = model?.rapidValue ?? -1
        }
    }

    @MainActor
    func testObservationTokenRapidUpdates() async throws {
        let model = RapidUpdatesModel()
        let observer = TokenObserver(model: model)

        for i in 0..<1000 {
            model.rapidValue = i
            if i % 100 == 0 {
                try await Task.sleep(for: .milliseconds(1))
            }
        }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(observer.observedValue, 999)
    }

    // Test memory management and weak references
    @MainActor
    func testWeakReferenceMemoryManagement() async throws {
        let model = TestModel()
        weak var weakObserver: TestObserver?

        do {
            let observer = TestObserver(model: model)
            weakObserver = observer
            XCTAssertNotNil(weakObserver)

            model.count = 100
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(observer.observedCount, 100)
        }

        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(weakObserver, "Observer should be deallocated and weak reference should be nil")
    }

    @MainActor
    func testObservationWithNilModel() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)
        observer.model = nil

        // Triggering observation should use default values
        observer.startObserving()

        XCTAssertEqual(observer.observedCount, 0)
        XCTAssertEqual(observer.observedName, "")
        XCTAssertEqual(observer.observedIsEnabled, false)
        XCTAssertEqual(observer.observedPercentage, 0.0)
    }

    @MainActor
    func testMultipleObservationCalls() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)

        observer.startObserving()
        observer.startObserving()
        observer.startObserving()

        model.count = 50
        try await Task.sleep(for: .milliseconds(50))

        // Should still work correctly
        XCTAssertEqual(observer.observedCount, 50)
    }

    @MainActor
    func testRapidModelChanges() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)

        for i in 0..<100 {
            model.count = i
            model.name = "Name\(i)"
        }
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(observer.observedCount, 99)
        XCTAssertEqual(observer.observedName, "Name99")
    }

    @CancellableObservation
    @MainActor
    class AdvancedCancellableObserver {
        weak var model: LifecycleModel?
        var value1 = 0
        var value2 = 0
        var computedValue = 0

        init(model: LifecycleModel) {
            self.model = model
            bind()
        }

        @ObservationTracking
        func bind() {
            value1 = model?.value ?? 0
            value2 = (model?.value ?? 0) * 2
            computedValue = (model?.value ?? 0) + 100
        }
    }

    @MainActor
    func testAdvancedCancellableObservation() async throws {
        let model = LifecycleModel()
        let observer = AdvancedCancellableObserver(model: model)

        // Test initial values
        XCTAssertEqual(observer.value1, 0)
        XCTAssertEqual(observer.value2, 0)
        XCTAssertEqual(observer.computedValue, 100)

        // Test normal observation
        model.value = 10
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.value1, 10)
        XCTAssertEqual(observer.value2, 20)
        XCTAssertEqual(observer.computedValue, 110)

        // Test selective cancellation
        observer.cancelObserveValue1()
        observer.cancelObserveComputedValue()

        model.value = 20
        try await Task.sleep(for: .milliseconds(50))

        // value1 and computedValue should not update, value2 should
        XCTAssertEqual(observer.value1, 10, "value1 should not update after cancellation")
        XCTAssertEqual(observer.value2, 40, "value2 should still update")
        XCTAssertEqual(observer.computedValue, 110, "computedValue should not update after cancellation")

        // Test resuming specific observations
        observer.observeValue1()
        observer.observeComputedValue()

        try await Task.sleep(for: .milliseconds(50))

        // All values should now be updated
        XCTAssertEqual(observer.value1, 20)
        XCTAssertEqual(observer.value2, 40)
        XCTAssertEqual(observer.computedValue, 120)
    }

    @MainActor
    func testCancellableObservationTokenValidation() async throws {
        let model = RapidUpdatesModel()
        let observer = TokenObserver(model: model)

        // Start rapid updates
        let updateTask = Task {
            for i in 0..<100 {
                model.rapidValue = i
                if i % 10 == 0 {
                    try await Task.sleep(for: .milliseconds(1))
                }
            }
        }

        // Stop and restart observations during updates
        try await Task.sleep(for: .milliseconds(5))
        observer.stopObservations()
        try await Task.sleep(for: .milliseconds(5))
        observer.startObservationsIfNeeded()

        try await updateTask.value
        try await Task.sleep(for: .milliseconds(100))

        // Should have final value despite interruption
        XCTAssertEqual(observer.observedValue, 99)
    }

    @MainActor
    func testObservationPerformance() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)

        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<1000 {
            model.count = i
            model.name = "Performance\(i)"
        }

        try await Task.sleep(for: .milliseconds(100))

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertLessThan(duration, 5.0, "Performance test should complete within 5 seconds")
        XCTAssertEqual(observer.observedCount, 999)
        XCTAssertEqual(observer.observedName, "Performance999")
    }

    @MainActor
    func testLargeNumberOfObservers() async throws {
        let model = TestModel()
        var observers: [TestObserver] = []

        // Create 50 observers
        for _ in 0..<50 {
            observers.append(TestObserver(model: model))
        }

        model.count = 42
        model.name = "ManyObservers"

        try await Task.sleep(for: .milliseconds(200))

        // All observers should have the same values
        for observer in observers {
            XCTAssertEqual(observer.observedCount, 42)
            XCTAssertEqual(observer.observedName, "ManyObservers")
        }
    }

    @Observable
    class StressTestModel {
        var value1 = 0
        var value2 = 0.0
        var value3 = ""
        var value4 = false
        var value5: [Int] = []
    }

    @MainActor
    class StressTestObserver {
        weak var model: StressTestModel?
        var obs1 = -1
        var obs2 = -1.0
        var obs3 = ""
        var obs4 = true
        var obs5: [Int] = []

        init(model: StressTestModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            obs1 = model?.value1 ?? -1
            obs2 = model?.value2 ?? -1.0
            obs3 = model?.value3 ?? ""
            obs4 = model?.value4 ?? true
            obs5 = model?.value5 ?? []
        }
    }

    @MainActor
    func testStressTestWithMultipleProperties() async throws {
        let model = StressTestModel()
        let observer = StressTestObserver(model: model)

        // Rapid updates to all properties
        for i in 0..<100 {
            model.value1 = i
            model.value2 = Double(i) * 1.5
            model.value3 = "Stress\(i)"
            model.value4 = i % 2 == 0
            model.value5 = Array(0...i)

            if i % 20 == 0 {
                try await Task.sleep(for: .milliseconds(1))
            }
        }

        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(observer.obs1, 99)
        XCTAssertEqual(observer.obs2, 148.5, accuracy: 0.001)
        XCTAssertEqual(observer.obs3, "Stress99")
        XCTAssertFalse(observer.obs4)
        XCTAssertEqual(observer.obs5, Array(0...99))
    }

    @Observable
    class ErrorProneModel {
        var value: Int = 0 {
            willSet {
                if newValue < 0 {
                    print("Warning: negative value set")
                }
            }
        }

        var optionalValue: String? = nil
        var throwingProperty: String {
            if value < 0 {
                return "Error"
            }
            return "Value: \(value)"
        }
    }

    @MainActor
    class RobustObserver {
        weak var model: ErrorProneModel?
        var observedValue = -999
        var observedOptional = "default"
        var observedThrowing = "default"

        init(model: ErrorProneModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            observedValue = model?.value ?? -999
            observedOptional = model?.optionalValue ?? "default"
            observedThrowing = model?.throwingProperty ?? "default"
        }
    }

    @MainActor
    func testRobustnessWithEdgeCaseValues() async throws {
        let model = ErrorProneModel()
        let observer = RobustObserver(model: model)

        // Test with various edge case values
        model.value = Int.max
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, Int.max)

        model.value = Int.min
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, Int.min)
        XCTAssertEqual(observer.observedThrowing, "Error")

        model.value = 0
        model.optionalValue = nil
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedValue, 0)
        XCTAssertEqual(observer.observedOptional, "default")
        XCTAssertEqual(observer.observedThrowing, "Value: 0")

        model.optionalValue = ""
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedOptional, "")

        model.optionalValue = "Very long string with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?"
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(observer.observedOptional, "Very long string with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?")
    }

    @Observable
    class ComplexNestedModel {
        var config: ConfigModel = ConfigModel()
        var items: [ItemModel] = []
        var metadata: [String: Any] = [:]
    }

    @Observable
    class ConfigModel {
        var theme = "light"
        var fontSize = 14.0
        var isEnabled = true
    }

    @Observable
    class ItemModel {
        var title = ""
        var count = 0
        var isVisible = true
    }

    @MainActor
    class ComplexIntegrationObserver {
        weak var model: ComplexNestedModel?
        var currentTheme = ""
        var totalItems = 0
        var isConfigEnabled = false
        var formattedTitle = ""

        init(model: ComplexNestedModel) {
            self.model = model
            observeComplex()
        }

        @ObservationTracking
        func observeComplex() {
            currentTheme = model?.config.theme ?? "default"
            totalItems = model?.items.count ?? 0
            isConfigEnabled = model?.config.isEnabled ?? false
            formattedTitle = "Items: \(model?.items.count ?? 0) - Theme: \(model?.config.theme ?? "none")"
        }
    }

    @MainActor
    func testComplexNestedObservation() async throws {
        let model = ComplexNestedModel()
        let observer = ComplexIntegrationObserver(model: model)

        // Test initial values
        XCTAssertEqual(observer.currentTheme, "light")
        XCTAssertEqual(observer.totalItems, 0)
        XCTAssertTrue(observer.isConfigEnabled)
        XCTAssertEqual(observer.formattedTitle, "Items: 0 - Theme: light")

        // Test nested property changes
        model.config.theme = "dark"
        model.config.isEnabled = false
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.currentTheme, "dark")
        XCTAssertFalse(observer.isConfigEnabled)
        XCTAssertEqual(observer.formattedTitle, "Items: 0 - Theme: dark")

        // Test array changes
        model.items.append(ItemModel())
        model.items.append(ItemModel())
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.totalItems, 2)
        XCTAssertEqual(observer.formattedTitle, "Items: 2 - Theme: dark")
    }

    @Observable
    class FunctionCallModel {
        var corners: CGFloat = 0.0
        var theme: String = "light"
        var isEnabled: Bool = true
    }

    @MainActor
    class FunctionCallObserver {
        weak var model: FunctionCallModel?
        var lastCorners: CGFloat = -1
        var lastTheme: String = ""
        var lastEnabled: Bool = false

        init(model: FunctionCallModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            updateCorners(model?.corners ?? 0.0)
            setTheme(model?.theme ?? "default")
            toggleFeature(model?.isEnabled ?? false)
        }

        func updateCorners(_ value: CGFloat) {
            lastCorners = value
        }

        func setTheme(_ theme: String) {
            lastTheme = theme
        }

        func toggleFeature(_ enabled: Bool) {
            lastEnabled = enabled
        }
    }

    @MainActor
    func testFunctionCallObservation() async throws {
        let model = FunctionCallModel()
        let observer = FunctionCallObserver(model: model)

        XCTAssertEqual(observer.lastCorners, 0.0)
        XCTAssertEqual(observer.lastTheme, "light")
        XCTAssertTrue(observer.lastEnabled)

        model.corners = 12.5
        model.theme = "dark"
        model.isEnabled = false

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.lastCorners, 12.5)
        XCTAssertEqual(observer.lastTheme, "dark")
        XCTAssertFalse(observer.lastEnabled)

        model.corners = 8.0
        model.theme = "system"
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(observer.lastCorners, 8.0)
        XCTAssertEqual(observer.lastTheme, "system")
    }
}
#endif
