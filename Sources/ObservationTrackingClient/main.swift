//
//  main.swift
//  ObservationTrackingClient
//
//  A demonstration client showing how to use the @ObservationTracking macro
//  with Swift's Observation framework for automatic UI updates.
//

import Observation
import ObservationTracking

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@Observable
final class SomeObservableClass {
    var count = 42
    var message = "Hello"
}

@MainActor
class BaseClass {
    func bind() {}
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
final class ObserverClass: BaseClass, @unchecked Sendable {
    weak var observedObject: SomeObservableClass?
    var intValue = 0
    var stringValue = "Initial"

    init(observedObject: SomeObservableClass) {
        self.observedObject = observedObject
        super.init()
        bind()
    }

    @ObservationTracking
    override func bind() {
        super.bind()

        intValue = observedObject?.count ?? 0
        stringValue = observedObject?.message ?? ""
    }

    deinit {
        print("ObserverClass instance deinitialized")
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
func runExample() async {
    print("=== ObservationTracking Macro Example ===")

    let observableModel = SomeObservableClass()

    print("\n--- Testing @ObservationTracking Macro ---")

    do {
        var observer = ObserverClass(observedObject: observableModel)
        
        print("Initial values:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        
        try? await Task.sleep(for: .milliseconds(10))
        
        print("\nChanging observable values...")
        observableModel.count = 13
        observableModel.message = "Updated to 13"
        
        try? await Task.sleep(for: .milliseconds(10))
        
        print("After first change:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        
        print("\nCreating new observer instance...")
        observer = ObserverClass(observedObject: observableModel)
        
        print("New observer initial values:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        
        print("\nChanging observable values again...")
        observableModel.count = 42
        observableModel.message = "Back to 42"
        
        try? await Task.sleep(for: .milliseconds(10))
        
        print("After second change:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
    }

    print("\n=== Example Complete ===")
}

if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) {
    await runExample()
}
