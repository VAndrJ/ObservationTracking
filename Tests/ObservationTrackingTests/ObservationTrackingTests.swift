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
    private func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(2),
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition(), clock.now < deadline {
            await Task.yield()
        }

        XCTAssertTrue(condition(), "Timed out waiting for \(description)", file: file, line: line)
    }

    private func drainObservationTasks() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }

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
        await waitUntil("all observed values to update") {
            observer.observedCount == 42
                && observer.observedName == "Updated"
                && observer.observedIsEnabled
                && observer.observedPercentage == 75.5
        }

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
        await waitUntil("the single observed value to update") {
            observer.observedValue == 25
        }

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
        await waitUntil("the base-value expressions to update") {
            observer.computedResult == 35
                && observer.formattedString == "Result: 30"
        }

        XCTAssertEqual(observer.computedResult, 35)
        XCTAssertEqual(observer.formattedString, "Result: 30")

        model.multiplier = 3
        await waitUntil("the multiplier expressions to update") {
            observer.computedResult == 50
                && observer.formattedString == "Result: 45"
        }

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
        await waitUntil("non-nil optional values to update") {
            observer.safeValue == 42 && observer.safeString == "hello"
        }

        XCTAssertEqual(observer.safeValue, 42)
        XCTAssertEqual(observer.safeString, "hello")

        model.optionalValue = nil
        model.optionalString = nil
        await waitUntil("optional defaults to be restored") {
            observer.safeValue == -1 && observer.safeString == "default"
        }

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
        await waitUntil("optional values without defaults to update") {
            observer.safeValue == 42 && observer.safeString == "hello"
        }

        XCTAssertEqual(observer.safeValue, 42)
        XCTAssertEqual(observer.safeString, "hello")

        model.optionalValue = nil
        model.optionalString = nil
        await waitUntil("optional values without defaults to become nil") {
            observer.safeValue == nil && observer.safeString == nil
        }

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
        await waitUntil("both observers to receive the shared values") {
            observer1.observedCount == 15
                && observer1.observedName == "Shared"
                && observer2.observedCount == 15
                && observer2.observedName == "Shared"
        }

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
            weak var weakObserver: RapidObserver?

            do {
                model.counter = i
                let observer = RapidObserver(model: model)
                weakObserver = observer
                XCTAssertEqual(observer.observedCounter, i)
            }

            await waitUntil("the short-lived observer to deallocate") {
                weakObserver == nil
            }
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
        await waitUntil("all edge-case assignments to update") {
            observer.observedSimple == 42
                && observer.observedNested == "updated"
                && observer.observedArray == [1, 2, 3]
                && observer.observedComputed == "Value: 42"
        }

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

    @CancellableObservation
    @MainActor
    class CancellableStartObserver {
        weak var model: LifecycleModel?
        var observedValue = -1
        var bindCallCount = 0

        init(model: LifecycleModel) {
            self.model = model
        }

        @ObservationTracking
        func bind() {
            bindCallCount += 1
            observedValue = model?.value ?? -1
        }
    }

    @MainActor
    func testCancellableObservationStartsWhenNoTokensExist() async throws {
        let model = LifecycleModel()
        let observer = CancellableStartObserver(model: model)

        XCTAssertEqual(observer.observedValue, -1)
        XCTAssertEqual(observer.bindCallCount, 0)

        observer.startObservationsIfNeeded()
        await waitUntil("observation startup to bind") {
            observer.observedValue == 0 && observer.bindCallCount == 1
        }

        XCTAssertEqual(observer.observedValue, 0)
        XCTAssertEqual(observer.bindCallCount, 1)

        observer.startObservationsIfNeeded()
        await drainObservationTasks()
        XCTAssertEqual(observer.bindCallCount, 1)

        model.value = 10
        await waitUntil("the started observation to update") {
            observer.observedValue == 10
        }
        XCTAssertEqual(observer.observedValue, 10)
    }

    @MainActor
    func testCancellableObservationLifecycle() async throws {
        let model = LifecycleModel()
        let observer = CancellableObserver(model: model)

        XCTAssertEqual(observer.observedValue, 0)
        XCTAssertEqual(observer.bindCallCount, 1)

        model.value = 10
        await waitUntil("the cancellable observation to update") {
            observer.observedValue == 10
        }
        XCTAssertEqual(observer.observedValue, 10)
        let initialCallCount = observer.bindCallCount

        observer.stopObservations()

        model.value = 20
        await drainObservationTasks()
        XCTAssertEqual(observer.observedValue, 10)
        XCTAssertEqual(observer.bindCallCount, initialCallCount)

        observer.startObservationsIfNeeded()
        await waitUntil("the restarted observation to bind the latest value") {
            observer.observedValue == 20 && observer.bindCallCount > initialCallCount
        }
        XCTAssertEqual(observer.observedValue, 20)
        XCTAssertGreaterThan(observer.bindCallCount, initialCallCount)

        model.value = 30
        await waitUntil("the restarted observation to continue updating") {
            observer.observedValue == 30
        }
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
                await Task.yield()
            }
        }
        await waitUntil("the latest rapid token update") {
            observer.observedValue == 999
        }

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
            await waitUntil("the observer to receive a value before deallocation") {
                observer.observedCount == 100
            }
            XCTAssertEqual(observer.observedCount, 100)
        }

        await waitUntil("the weak observer reference to clear") {
            weakObserver == nil
        }
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
        await waitUntil("repeated observation registration to update once") {
            observer.observedCount == 50
        }

        // Should still work correctly
        XCTAssertEqual(observer.observedCount, 50)
    }

    @Observable
    class IdempotentRegistrationModel {
        var value = 0
    }

    @MainActor
    class IdempotentRegistrationObserver {
        let model: IdempotentRegistrationModel
        var updateCount = 0
        var observedValue = -1 {
            didSet {
                updateCount += 1
            }
        }

        init(model: IdempotentRegistrationModel) {
            self.model = model
        }

        @ObservationTracking
        func bind() {
            observedValue = model.value
        }

        func startRepeatedly() {
            bind()
            bind()
            bind()
        }
    }

    @MainActor
    func testBasicObservationRegistrationIsIdempotent() async throws {
        let model = IdempotentRegistrationModel()
        let observer = IdempotentRegistrationObserver(model: model)

        observer.startRepeatedly()
        observer.updateCount = 0
        model.value = 42
        await waitUntil("one idempotent registration update") {
            observer.observedValue == 42 && observer.updateCount == 1
        }

        XCTAssertEqual(observer.observedValue, 42)
        XCTAssertEqual(observer.updateCount, 1)
    }

    @CancellableObservation
    @MainActor
    class CancellableGenerationObserver {
        let model: IdempotentRegistrationModel
        var updateCount = 0
        var observedValue = -1 {
            didSet {
                updateCount += 1
            }
        }

        init(model: IdempotentRegistrationModel) {
            self.model = model
            bind()
        }

        @ObservationTracking
        func bind() {
            observedValue = model.value
        }
    }

    @MainActor
    func testCancellableObservationDoesNotReuseCancelledGeneration() async throws {
        let model = IdempotentRegistrationModel()
        let observer = CancellableGenerationObserver(model: model)

        observer.cancelObserveObservedValue()
        observer.observeObservedValue()
        observer.updateCount = 0
        model.value = 42
        await waitUntil("the replacement generation to update once") {
            observer.observedValue == 42 && observer.updateCount == 1
        }

        XCTAssertEqual(observer.observedValue, 42)
        XCTAssertEqual(observer.updateCount, 1)
    }

    @MainActor
    func testRapidModelChangesPublishLatestValues() async throws {
        let model = TestModel()
        let observer = TestObserver(model: model)

        for i in 0..<1000 {
            model.count = i
            model.name = "Name\(i)"
        }
        await waitUntil("the latest rapid model values") {
            observer.observedCount == 999 && observer.observedName == "Name999"
        }

        XCTAssertEqual(observer.observedCount, 999)
        XCTAssertEqual(observer.observedName, "Name999")
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
        await waitUntil("all cancellable observers to update") {
            observer.value1 == 10
                && observer.value2 == 20
                && observer.computedValue == 110
        }
        XCTAssertEqual(observer.value1, 10)
        XCTAssertEqual(observer.value2, 20)
        XCTAssertEqual(observer.computedValue, 110)

        // Test selective cancellation
        observer.cancelObserveValue1()
        observer.cancelObserveComputedValue()

        model.value = 20
        await waitUntil("the uncancelled observer to update") {
            observer.value2 == 40
        }

        // value1 and computedValue should not update, value2 should
        XCTAssertEqual(observer.value1, 10, "value1 should not update after cancellation")
        XCTAssertEqual(observer.value2, 40, "value2 should still update")
        XCTAssertEqual(observer.computedValue, 110, "computedValue should not update after cancellation")

        // Test resuming specific observations
        observer.observeValue1()
        observer.observeComputedValue()

        await waitUntil("the selectively resumed observers to bind") {
            observer.value1 == 20
                && observer.value2 == 40
                && observer.computedValue == 120
        }

        // All values should now be updated
        XCTAssertEqual(observer.value1, 20)
        XCTAssertEqual(observer.value2, 40)
        XCTAssertEqual(observer.computedValue, 120)
    }

    @MainActor
    func testCancellableObservationTokenValidation() async throws {
        let model = RapidUpdatesModel()
        let observer = TokenObserver(model: model)

        for i in 0..<40 {
            model.rapidValue = i
        }
        await waitUntil("the pre-cancellation updates to settle") {
            observer.observedValue == 39
        }

        observer.stopObservations()
        for i in 40..<70 {
            model.rapidValue = i
        }
        await drainObservationTasks()
        XCTAssertEqual(observer.observedValue, 39)

        observer.startObservationsIfNeeded()
        XCTAssertEqual(observer.observedValue, 69)

        for i in 70..<100 {
            model.rapidValue = i
        }
        await waitUntil("the post-restart updates to settle") {
            observer.observedValue == 99
        }
        XCTAssertEqual(observer.observedValue, 99)
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

        await waitUntil("all observers to receive the broadcast values") {
            observers.allSatisfy {
                $0.observedCount == 42 && $0.observedName == "ManyObservers"
            }
        }

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
                await Task.yield()
            }
        }

        await waitUntil("all stress-test values to converge") {
            observer.obs1 == 99
                && observer.obs2 == 148.5
                && observer.obs3 == "Stress99"
                && !observer.obs4
                && observer.obs5 == Array(0...99)
        }

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
        var derivedStatus: String {
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
        var observedDerivedStatus = "default"

        init(model: ErrorProneModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            observedValue = model?.value ?? -999
            observedOptional = model?.optionalValue ?? "default"
            observedDerivedStatus = model?.derivedStatus ?? "default"
        }
    }

    @MainActor
    func testDerivedAndOptionalValuesHandleEdgeCases() async throws {
        let model = ErrorProneModel()
        let observer = RobustObserver(model: model)

        model.value = Int.max
        await waitUntil("the maximum integer value") {
            observer.observedValue == Int.max
        }
        XCTAssertEqual(observer.observedValue, Int.max)

        model.value = Int.min
        await waitUntil("the minimum integer and derived status") {
            observer.observedValue == Int.min
                && observer.observedDerivedStatus == "Error"
        }
        XCTAssertEqual(observer.observedValue, Int.min)
        XCTAssertEqual(observer.observedDerivedStatus, "Error")

        model.value = 0
        model.optionalValue = nil
        await waitUntil("the reset value and optional default") {
            observer.observedValue == 0
                && observer.observedOptional == "default"
                && observer.observedDerivedStatus == "Value: 0"
        }
        XCTAssertEqual(observer.observedValue, 0)
        XCTAssertEqual(observer.observedOptional, "default")
        XCTAssertEqual(observer.observedDerivedStatus, "Value: 0")

        model.optionalValue = ""
        await waitUntil("the empty optional string") {
            observer.observedOptional == ""
        }
        XCTAssertEqual(observer.observedOptional, "")

        model.optionalValue = "Very long string with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?"
        await waitUntil("the long optional string") {
            observer.observedOptional == "Very long string with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?"
        }
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
        await waitUntil("nested configuration changes") {
            observer.currentTheme == "dark"
                && !observer.isConfigEnabled
                && observer.formattedTitle == "Items: 0 - Theme: dark"
        }

        XCTAssertEqual(observer.currentTheme, "dark")
        XCTAssertFalse(observer.isConfigEnabled)
        XCTAssertEqual(observer.formattedTitle, "Items: 0 - Theme: dark")

        // Test array changes
        model.items.append(ItemModel())
        model.items.append(ItemModel())
        await waitUntil("nested collection changes") {
            observer.totalItems == 2
                && observer.formattedTitle == "Items: 2 - Theme: dark"
        }

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
        var renderedMessage = ""
        var renderedValues: [String] = []
        var renderedMetadata: [String: String] = [:]
        var renderedPair: (String, Bool) = ("", false)
        var helperSnapshot = ""
        var callbackTheme = ""
        var callbackEnabled = false

        init(model: FunctionCallModel) {
            self.model = model
            observe()
        }

        @ObservationTracking
        func observe() {
            updateCorners(model?.corners ?? 0.0)
            setTheme(model?.theme ?? "default")
            toggleFeature(model?.isEnabled ?? false)
            render(
                message: "Theme: \(model?.theme ?? "default")",
                values: [model?.theme ?? "default", "\(model?.corners ?? 0.0)"],
                metadata: ["theme": model?.theme ?? "default"],
                pair: (model?.theme ?? "default", model?.isEnabled ?? false)
            )
            refreshSummary()
            renderWithCallbacks {
                callbackTheme = model?.theme ?? "default"
            } completion: {
                callbackEnabled = model?.isEnabled ?? false
            }
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

        func render(
            message: String,
            values: [String],
            metadata: [String: String],
            pair: (String, Bool)
        ) {
            renderedMessage = message
            renderedValues = values
            renderedMetadata = metadata
            renderedPair = pair
        }

        func refreshSummary() {
            helperSnapshot = "\(model?.theme ?? "default"): \(model?.isEnabled ?? false)"
        }

        func renderWithCallbacks(_ render: () -> Void, completion: () -> Void) {
            render()
            completion()
        }
    }

    @MainActor
    func testFunctionCallObservation() async throws {
        let model = FunctionCallModel()
        let observer = FunctionCallObserver(model: model)

        XCTAssertEqual(observer.lastCorners, 0.0)
        XCTAssertEqual(observer.lastTheme, "light")
        XCTAssertTrue(observer.lastEnabled)
        XCTAssertEqual(observer.renderedMessage, "Theme: light")
        XCTAssertEqual(observer.renderedValues, ["light", "0.0"])
        XCTAssertEqual(observer.renderedMetadata, ["theme": "light"])
        XCTAssertEqual(observer.renderedPair.0, "light")
        XCTAssertTrue(observer.renderedPair.1)
        XCTAssertEqual(observer.helperSnapshot, "light: true")
        XCTAssertEqual(observer.callbackTheme, "light")
        XCTAssertTrue(observer.callbackEnabled)

        model.corners = 12.5
        model.theme = "dark"
        model.isEnabled = false

        await waitUntil("all function-call observations to update") {
            observer.lastCorners == 12.5
                && observer.lastTheme == "dark"
                && !observer.lastEnabled
                && observer.renderedMessage == "Theme: dark"
                && observer.renderedValues == ["dark", "12.5"]
                && observer.renderedMetadata == ["theme": "dark"]
                && observer.renderedPair.0 == "dark"
                && !observer.renderedPair.1
                && observer.helperSnapshot == "dark: false"
                && observer.callbackTheme == "dark"
                && !observer.callbackEnabled
        }

        XCTAssertEqual(observer.lastCorners, 12.5)
        XCTAssertEqual(observer.lastTheme, "dark")
        XCTAssertFalse(observer.lastEnabled)
        XCTAssertEqual(observer.renderedMessage, "Theme: dark")
        XCTAssertEqual(observer.renderedValues, ["dark", "12.5"])
        XCTAssertEqual(observer.renderedMetadata, ["theme": "dark"])
        XCTAssertEqual(observer.renderedPair.0, "dark")
        XCTAssertFalse(observer.renderedPair.1)
        XCTAssertEqual(observer.helperSnapshot, "dark: false")
        XCTAssertEqual(observer.callbackTheme, "dark")
        XCTAssertFalse(observer.callbackEnabled)

        model.corners = 8.0
        model.theme = "system"
        await waitUntil("subsequent function-call observations to update") {
            observer.lastCorners == 8.0 && observer.lastTheme == "system"
        }

        XCTAssertEqual(observer.lastCorners, 8.0)
        XCTAssertEqual(observer.lastTheme, "system")
    }

    @Observable
    class ConditionalFunctionCallModel {
        var isSomethingEnabled = false
    }

    @MainActor
    class ConditionalFunctionCallObserver {
        let viewModel: ConditionalFunctionCallModel
        var callCount = 0
        var falseEvaluationCount = 0

        init(viewModel: ConditionalFunctionCallModel) {
            self.viewModel = viewModel
            bind()
        }

        @ObservationTracking
        func bind() {
            if viewModel.isSomethingEnabled {
                someFunction()
            } else {
                falseEvaluationCount += 1
            }
        }

        func someFunction() {
            callCount += 1
        }
    }

    @MainActor
    func testConditionalFunctionCallContinuesTracking() async throws {
        let viewModel = ConditionalFunctionCallModel()
        let observer = ConditionalFunctionCallObserver(viewModel: viewModel)

        XCTAssertEqual(observer.callCount, 0)
        XCTAssertEqual(observer.falseEvaluationCount, 1)

        viewModel.isSomethingEnabled = true
        await waitUntil("the enabled conditional call") {
            observer.callCount == 1
        }
        XCTAssertEqual(observer.callCount, 1)

        viewModel.isSomethingEnabled = false
        await waitUntil("the disabled conditional branch") {
            observer.falseEvaluationCount == 2
        }
        XCTAssertEqual(observer.callCount, 1)

        viewModel.isSomethingEnabled = true
        await waitUntil("the re-enabled conditional call") {
            observer.callCount == 2
        }
        XCTAssertEqual(observer.callCount, 2)
    }

    @Observable
    class SwitchModel {
        enum Value {
            case hello
            case bye
        }

        var someValue: Value = .hello
    }

    @MainActor
    class SwitchObserver {
        let viewModel: SwitchModel
        var title = ""
        var helloCount = 0
        var byeCount = 0

        init(viewModel: SwitchModel) {
            self.viewModel = viewModel
            bind()
        }

        @ObservationTracking
        func bind() {
            title = switch viewModel.someValue {
            case .hello: "Hello"
            case .bye: "bye!"
            }

            switch viewModel.someValue {
            case .hello:
                sayHello()
            case .bye:
                sayBye()
            }
        }

        func sayHello() {
            helloCount += 1
        }

        func sayBye() {
            byeCount += 1
        }
    }

    @MainActor
    func testSwitchExpressionAndStatementContinueTracking() async throws {
        let viewModel = SwitchModel()
        let observer = SwitchObserver(viewModel: viewModel)

        XCTAssertEqual(observer.title, "Hello")
        XCTAssertEqual(observer.helloCount, 1)
        XCTAssertEqual(observer.byeCount, 0)

        viewModel.someValue = .bye
        await waitUntil("the switch to the bye branch") {
            observer.title == "bye!"
                && observer.helloCount == 1
                && observer.byeCount == 1
        }
        XCTAssertEqual(observer.title, "bye!")
        XCTAssertEqual(observer.helloCount, 1)
        XCTAssertEqual(observer.byeCount, 1)

        viewModel.someValue = .hello
        await waitUntil("the switch back to the hello branch") {
            observer.title == "Hello"
                && observer.helloCount == 2
                && observer.byeCount == 1
        }
        XCTAssertEqual(observer.title, "Hello")
        XCTAssertEqual(observer.helloCount, 2)
        XCTAssertEqual(observer.byeCount, 1)
    }
}
#endif
