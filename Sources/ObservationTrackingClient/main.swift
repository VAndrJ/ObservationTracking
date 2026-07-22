//
//  main.swift
//  ObservationTrackingClient
//
//  A demonstration client showing how to use the @ObservationTracking macro
//  with Swift's Observation framework for automatic UI updates.
//

import Foundation
import Observation
import ObservationTracking

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@Observable
final class SomeObservableClass {
    enum SomeValue {
        case hello
        case bye
    }

    var count = 42
    var message = "Hello"
    var someValue: SomeValue = .hello
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
    var functionCallValue = ""
    var conditionText = ""
    var lastConditionAction = ""
    var switchText = ""
    var lastSwitchAction = ""

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
        updateFunctionCallValue(observedObject?.message ?? "")

        conditionText = if (observedObject?.count ?? 0).isMultiple(of: 2) {
            "even"
        } else {
            "odd"
        }

        if (observedObject?.count ?? 0).isMultiple(of: 2) {
            recordEvenCount()
        } else {
            recordOddCount()
        }

        switchText = switch observedObject?.someValue ?? .hello {
        case .hello: "Hello"
        case .bye: "bye!"
        }

        switch observedObject?.someValue ?? .hello {
        case .hello:
            sayHello()
        case .bye:
            sayBye()
        }
    }

    private func updateFunctionCallValue(_ value: String) {
        functionCallValue = "Function received: \(value)"
    }

    private func recordEvenCount() {
        lastConditionAction = "recordEvenCount()"
    }

    private func recordOddCount() {
        lastConditionAction = "recordOddCount()"
    }

    private func sayHello() {
        lastSwitchAction = "sayHello()"
    }

    private func sayBye() {
        lastSwitchAction = "sayBye()"
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

    do {
        var observer = ObserverClass(observedObject: observableModel)

        print("Initial values:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        print("  Function call: \(observer.functionCallValue)")
        print("  If expression: \(observer.conditionText)")
        print("  If statement: \(observer.lastConditionAction)")
        print("  Switch expression: \(observer.switchText)")
        print("  Switch statement: \(observer.lastSwitchAction)")

        try? await Task.sleep(for: .milliseconds(10))

        print("\nChanging observable values...")
        observableModel.count = 13
        observableModel.message = "Updated to 13"
        observableModel.someValue = .bye

        try? await Task.sleep(for: .milliseconds(10))

        print("After first change:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        print("  Function call: \(observer.functionCallValue)")
        print("  If expression: \(observer.conditionText)")
        print("  If statement: \(observer.lastConditionAction)")
        print("  Switch expression: \(observer.switchText)")
        print("  Switch statement: \(observer.lastSwitchAction)")

        print("\nCreating new observer instance...")
        observer = ObserverClass(observedObject: observableModel)

        print("New observer initial values:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        print("  Function call: \(observer.functionCallValue)")
        print("  If expression: \(observer.conditionText)")
        print("  If statement: \(observer.lastConditionAction)")
        print("  Switch expression: \(observer.switchText)")
        print("  Switch statement: \(observer.lastSwitchAction)")

        print("\nChanging observable values again...")
        observableModel.count = 42
        observableModel.message = "Back to 42"
        observableModel.someValue = .hello

        try? await Task.sleep(for: .milliseconds(10))

        print("After second change:")
        print("  Observer.intValue: \(observer.intValue)")
        print("  Observer.stringValue: \(observer.stringValue)")
        print("  Function call: \(observer.functionCallValue)")
        print("  If expression: \(observer.conditionText)")
        print("  If statement: \(observer.lastConditionAction)")
        print("  Switch expression: \(observer.switchText)")
        print("  Switch statement: \(observer.lastSwitchAction)")
    }

    print("\n=== ObservationTracking Example Complete ===")
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@Observable
final class AdvancedObservableModel {
    var temperature = 20.0
    var humidity = 45.0
    var pressure = 1013.25
    var location = "Unknown"
    var isActive = true
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@CancellableObservation
@MainActor
final class CancellableObserverClass: BaseClass, @unchecked Sendable {
    weak var weatherModel: AdvancedObservableModel?
    var currentTemperature = 0.0
    var currentHumidity = 0.0
    var currentPressure = 0.0
    var currentLocation = "Initial"
    var isModelActive = false
    var temperatureStatus = "Unknown"
    var comfortLevel = "Unknown"

    init(weatherModel: AdvancedObservableModel) {
        self.weatherModel = weatherModel
        super.init()
        bind()
    }

    @ObservationTracking
    override func bind() {
        super.bind()

        // Basic property observations
        currentTemperature = weatherModel?.temperature ?? 0.0
        currentHumidity = weatherModel?.humidity ?? 0.0
        currentPressure = weatherModel?.pressure ?? 0.0
        currentLocation = weatherModel?.location ?? "Unknown"
        isModelActive = weatherModel?.isActive ?? false

        // Computed observations
        temperatureStatus = (weatherModel?.temperature ?? 0.0) > 25.0 ? "Hot" : "Cool"
        comfortLevel =
            ((weatherModel?.temperature ?? 0.0) > 18.0 && (weatherModel?.temperature ?? 0.0) < 26.0 && (weatherModel?.humidity ?? 0.0) < 60.0)
            ? "Comfortable" : "Uncomfortable"
    }

    func pauseTemperatureObservation() {
        cancelObserveCurrentTemperature()
        cancelObserveTemperatureStatus()
    }

    func resumeTemperatureObservation() {
        observeCurrentTemperature()
        observeTemperatureStatus()
    }

    deinit {
        print("CancellableObserverClass instance deinitialized")
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
func runCancellableObservationExample() async {
    print("\n=== CancellableObservation Macro Example ===")

    let weatherModel = AdvancedObservableModel()
    let observer = CancellableObserverClass(weatherModel: weatherModel)

    print("Initial weather data:")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Humidity: \(observer.currentHumidity)%")
    print("  Pressure: \(observer.currentPressure) hPa")
    print("  Location: \(observer.currentLocation)")
    print("  Comfort Level: \(observer.comfortLevel)")
    print("  Model Active: \(observer.isModelActive)")

    try? await Task.sleep(for: .milliseconds(50))

    print("\n--- Updating weather conditions ---")
    weatherModel.temperature = 28.5
    weatherModel.humidity = 65.0
    weatherModel.pressure = 1020.0
    weatherModel.location = "Beach Resort"
    weatherModel.isActive = true

    try? await Task.sleep(for: .milliseconds(50))

    print("After weather update:")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Humidity: \(observer.currentHumidity)%")
    print("  Pressure: \(observer.currentPressure) hPa")
    print("  Location: \(observer.currentLocation)")
    print("  Comfort Level: \(observer.comfortLevel)")
    print("  Model Active: \(observer.isModelActive)")

    print("\n--- Pausing temperature observations ---")
    observer.pauseTemperatureObservation()

    print("Changing temperature while paused...")
    weatherModel.temperature = 15.0
    weatherModel.humidity = 0.0

    try? await Task.sleep(for: .milliseconds(50))

    print("Temperature after change (should be unchanged due to pause):")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Humidity: \(observer.currentHumidity)% (should still update)")

    print("\n--- Resuming temperature observations ---")
    observer.resumeTemperatureObservation()

    try? await Task.sleep(for: .milliseconds(50))

    print("After resuming temperature observations:")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Comfort Level: \(observer.comfortLevel)")

    print("\n--- Testing global observation control ---")
    observer.stopObservations()

    print("All observations stopped. Updating all values...")
    weatherModel.temperature = 22.0
    weatherModel.humidity = 50.0
    weatherModel.location = "Mountain Lodge"

    try? await Task.sleep(for: .milliseconds(50))

    print("Values after global stop (should be unchanged):")
    print("  Temperature: \(observer.currentTemperature)°C")
    print("  Humidity: \(observer.currentHumidity)%")
    print("  Location: \(observer.currentLocation)")

    print("\nRestarting all observations...")
    observer.startObservationsIfNeeded()

    try? await Task.sleep(for: .milliseconds(50))

    print("Values after restart (should be updated):")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Humidity: \(observer.currentHumidity)%")
    print("  Location: \(observer.currentLocation)")
    print("  Comfort Level: \(observer.comfortLevel)")

    print("\n--- Testing rapid updates with cancellation ---")
    for i in 1...5 {
        weatherModel.temperature = Double(20 + i * 2)
        weatherModel.humidity = Double(40 + i * 5)
        if i == 3 {
            print("Pausing observations during rapid updates...")
            observer.stopObservations()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }

    print("Final values after rapid updates:")
    print("  Temperature: \(observer.currentTemperature)°C")
    print("  Humidity: \(observer.currentHumidity)%")

    observer.startObservationsIfNeeded()
    try? await Task.sleep(for: .milliseconds(50))

    print("Final values after restarting:")
    print("  Temperature: \(observer.currentTemperature)°C (\(observer.temperatureStatus))")
    print("  Humidity: \(observer.currentHumidity)%")
    print("  Comfort Level: \(observer.comfortLevel)")

    print("\n=== CancellableObservation Example Complete ===")
}

if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) {
    await runExample()
    await runCancellableObservationExample()
}
