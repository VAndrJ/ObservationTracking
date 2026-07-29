#if canImport(ObservationTrackingMacros)
import Observation
import ObservationTracking
import Testing

@Observable
private final class IsolationCompilationModel {
    var value = 0
}

private actor ActorIsolationObserver {
    private let model = IsolationCompilationModel()
    private var value = 0

    func updateModel(to value: Int) {
        model.value = value
    }

    func observedValue() -> Int {
        value
    }

    @ObservationTracking
    func bind() {
        value = model.value
    }
}

private actor ExtensionIsolationObserver {
    fileprivate let model = IsolationCompilationModel()
    fileprivate var value = 0
}

extension ExtensionIsolationObserver {
    fileprivate func updateModel(to value: Int) {
        model.value = value
    }

    fileprivate func observedValue() -> Int {
        value
    }

    @ObservationTracking(isolation: .task)
    fileprivate func bind() {
        value = model.value
    }
}

@globalActor
private actor IsolationCompilationGlobalActor {
    static let shared = IsolationCompilationGlobalActor()
}

@IsolationCompilationGlobalActor
private final class CustomGlobalActorIsolationObserver {
    private let model = IsolationCompilationModel()
    private var value = 0

    func updateModel(to value: Int) {
        model.value = value
    }

    func observedValue() -> Int {
        value
    }

    @ObservationTracking(isolation: .task)
    func bind() {
        value = model.value
    }
}

@MainActor
private final class MainActorIsolationObserver {
    private let model = IsolationCompilationModel()
    private var value = 0

    @ObservationTracking
    func bind() {
        value = model.value
    }
}

struct ObservationTrackingIsolationRuntimeTests {
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !(await condition()), clock.now < deadline {
            await Task.yield()
        }

        return await condition()
    }

    @Test
    func testActorMethodWithDefaultTaskIsolationAtRuntime() async {
        let observer = ActorIsolationObserver()

        await observer.bind()
        await observer.updateModel(to: 11)
        let didUpdate = await waitUntil {
            await observer.observedValue() == 11
        }
        #expect(didUpdate)
    }

    @Test
    func testActorExtensionWithExplicitTaskIsolationAtRuntime() async {
        let observer = ExtensionIsolationObserver()

        await observer.bind()
        await observer.updateModel(to: 22)
        let didUpdate = await waitUntil {
            await observer.observedValue() == 22
        }
        #expect(didUpdate)
    }

    @Test
    func testCustomGlobalActorWithExplicitTaskIsolationAtRuntime() async {
        let observer = await CustomGlobalActorIsolationObserver()

        await observer.bind()
        await observer.updateModel(to: 33)
        let didUpdate = await waitUntil {
            await observer.observedValue() == 33
        }
        #expect(didUpdate)
    }
}
#endif
