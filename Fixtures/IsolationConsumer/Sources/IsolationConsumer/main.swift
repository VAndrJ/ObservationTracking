import Observation
import ObservationTracking

@Observable
final class ConsumerModel {
    var value = 0
}

actor ActorObserver {
    private let model = ConsumerModel()
    private var value = 0

    @ObservationTracking
    func bind() {
        value = model.value
    }
}

actor ExtensionObserver {
    fileprivate let model = ConsumerModel()
    fileprivate var value = 0
}

extension ExtensionObserver {
    @ObservationTracking(isolation: .task)
    fileprivate func bind() {
        value = model.value
    }
}

@globalActor
actor ConsumerGlobalActor {
    static let shared = ConsumerGlobalActor()
}

@ConsumerGlobalActor
final class CustomGlobalActorObserver {
    private let model = ConsumerModel()
    private var value = 0

    @ObservationTracking(isolation: .task)
    func bind() {
        value = model.value
    }
}

@MainActor
final class MainActorObserver {
    private let model = ConsumerModel()
    private var value = 0

    @ObservationTracking
    func bind() {
        value = model.value
    }
}

print("Isolation consumer compiled")
