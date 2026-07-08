# ObservationTracking

[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)

[![Language](https://img.shields.io/badge/language-Swift%206.0-orangered.svg?style=flat)](https://www.swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20visionOS-lightgray.svg?style=flat)](https://developer.apple.com/discover)

Swift macros that automatically generate reactive observation patterns using Swift's Observation framework. Provides both basic observation tracking and advanced cancellable observation management.

## Overview

ObservationTracking offers four macros:

- **`@ObservationTracking`**: Generates reactive observation for supported top-level assignments, function calls, and `if` statements
- **`@CancellableObservation`**: Adds observation lifecycle management with cancellation and selective control
- **`@StartObservations`**: Defers a `startObservationsIfNeeded()` call from an existing method
- **`@StopObservations`**: Defers a `stopObservations()` call from an existing method

The macros can work together to create observation patterns with minimal boilerplate code.

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+

## Required Imports

Macro expansions reference framework symbols directly, so each source file using the macros must import the frameworks needed by the generated code:

```swift
import Observation
import ObservationTracking
```

Add `Foundation` when using `@CancellableObservation`, because cancellable observers generate `UUID` tokens:

```swift
import Foundation
import Observation
import ObservationTracking
```

## Installation

### Swift Package Manager

Add ObservationTracking to your project through Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VAndrJ/ObservationTracking.git", from: "1.0.0")
]
```

**Or add it through Xcode:**
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/VAndrJ/ObservationTracking.git`
3. Select the version range

## Basic Usage

### @ObservationTracking Macro

The `@ObservationTracking` macro automatically generates reactive observation for supported top-level statements in a function:

```swift
import ObservationTracking
import Observation

@Observable
class DataModel {
    var count = 0
    var name = "Hello"
    var isActive = false
}

class ViewController {
    @ObservationTracking
    private func bind() {
        label.text = model.name
        countLabel.text = "\(model.count)"
        switchControl.isOn = model.isActive
    }
}
```

### Transformation Scope

`@ObservationTracking` can be used on instance methods declared in classes, actors, and extensions. Extension support is syntactic: Swift macros cannot prove the extended type is a class or actor, so the compiler validates whether the generated peer methods and `[weak self]` capture are legal for that extension. The macro transforms direct top-level statements in the annotated function body. Supported statements are property assignments, function calls with one non-literal argument, and top-level `if` statements that contain assignments.

```swift
@ObservationTracking
func bind() {
    title = model.title              // Tracked
    updateTitle(model.title)         // Tracked when there is one non-literal argument

    if model.isEnabled {             // Tracked as one observation
        subtitle = model.subtitle
    }

    if let value = model.detail {     // Tracked as one observation
        detail = value
    }

    subtitle = if model.isEnabled {   // Tracked as an assignment expression
        "Enabled"
    } else {
        "Disabled"
    }

    items.forEach { item in
        lastTitle = item.title       // Not transformed
    }

    defer {
        footer = model.footer        // Not transformed
    }
}
```

For a top-level `if`, the macro wraps the whole conditional in `withObservationTracking`, so the condition and whichever branch executes are observed. Assignments inside `guard`, `switch`, loops, closures, local functions, `defer`, and other nested scopes are left as normal Swift code. Move bindings that must be observed into top-level statements, supported top-level `if` statements, or helper methods annotated separately with `@ObservationTracking`.

### Isolation Control

The `@ObservationTracking` macro supports an `isolation` parameter that controls how observation change handlers are generated

#### Isolation Options

- **`nil` or omitted**: Infers `.mainActor` in classes and extensions, or `.task` in actors.
- **`.mainActor`**: Executes change handlers in `Task { @MainActor in ... }`.
- **`.task`**: Executes change handlers in an unstructured `Task { await ... }`. This schedules asynchronous re-observation, but it does not make mutable class state actor-isolated by itself.
- **`.synchronous`**: Executes change handlers directly in the `onChange` callback without Task wrapping. Use only when synchronous re-observation is safe for your executor and reentrancy model.

### Example

For a real-use case, see `ExampleScreenView` in the `Example` project.

### @CancellableObservation Macro

The `@CancellableObservation` macro adds advanced observation management to classes:

```swift
@CancellableObservation
@MainActor
class WeatherObserver {
    weak var model: WeatherModel?
    var temperature = 0.0
    var humidity = 0.0
    
    @ObservationTracking
    func bind() {
        temperature = model?.temperature ?? 0.0
        humidity = model?.humidity ?? 0.0
    }
    
    // Advanced control methods are automatically generated:
    // - stopObservations()
    // - startObservationsIfNeeded()
    // - observeTemperature()
    // - observeHumidity()
    // - cancelObserveTemperature()
    // - cancelObserveHumidity()
}
```

### Global Observation Management

Control all observations at once:

```swift
// Stop all observations
observer.stopObservations()

// Restart observations declared in the same @CancellableObservation class declaration
observer.startObservationsIfNeeded()
```

### Token-Based Cancellation

The macro automatically handles cancellation with tokens (randomly generated string within the one observation update cycle).

### UIKit Screen Lifecycle

`@CancellableObservation(screen: true)` is UIKit-style lifecycle glue. It emits `override func viewWillAppear(_:)` and `override func viewDidDisappear(_:)` methods that call `super`, then start or stop observations.

Use `screen: true` only on `UIViewController` subclasses or custom screen base classes that already provide overridable `viewWillAppear(_:)` and `viewDidDisappear(_:)` methods. Swift macros do not perform full superclass type checking, so applying this option to an arbitrary class can generate invalid `override` or `super` calls. If the class already implements these lifecycle methods, the macro adds `@StartObservations` or `@StopObservations` to the existing method when possible instead of generating a duplicate method.

## Comparison with Regular Approach

### Without @ObservationTracking:

```swift
class ManualObserver {
    weak var store: SomeStore?
    var localValue1 = 0
    var localValue2 = ""
    
    func startObserving() {
        observeValue1()
        observeValue2()
    }
    
    private func observeValue1() {
        localValue1 = withObservationTracking {
            store?.value1 ?? 0
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeValue1()
            }
        }
    }
    
    private func observeValue2() {
        localValue2 = withObservationTracking {
            store?.value2 ?? ""
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeValue2()
            }
        }
    }
}
```

### With @ObservationTracking:

```swift
class MacroObserver {
    weak var store: SomeStore?
    var localValue1 = 0
    var localValue2 = ""
    
    @ObservationTracking
    func startObserving() {
        localValue1 = store?.value1 ?? 0
        localValue2 = store?.value2 ?? ""
    }
}
```

## Pros and Cons

### Pros ✅

- **Reduced Boilerplate**: Eliminates repetitive `withObservationTracking` code
- **Type Safe**: Compile-time macro expansion ensures type safety
- **Clean Syntax**: Makes intent clear and code more readable
- **UIKit Friendly**: Perfect for updating UI elements when data changes
- **Advanced Control**: Selective observation management with cancellation

### Cons ❌

- **Macro Dependency**: Requires understanding of Swift macros

## What the Macros Generate

### @ObservationTracking Expansion

**Your code:**

```swift
@ObservationTracking
private func bind() {
    count = model.value
    name = model.name ?? "default"
}
```

**Generated code:**

```swift
private func bind() {
    observeCount()
    observeName()
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

private func observeName() {
    name = withObservationTracking {
        model.name ?? "default"
    } onChange: { [weak self] in
        Task { @MainActor in
            self?.observeName()
        }
    }
}
```

**Top-level `if` statements:**

```swift
@ObservationTracking
private func bind() {
    if model.isEnabled {
        subtitle = model.subtitle
    } else {
        subtitle = ""
    }
}
```

**Generated code:**

```swift
private func bind() {
    observeSubtitle()
}

private func observeSubtitle() {
    withObservationTracking {
        if model.isEnabled {
            subtitle = model.subtitle
        } else {
            subtitle = ""
        }
    } onChange: { [weak self] in
        Task { @MainActor in
            self?.observeSubtitle()
        }
    }
}
```

#### Isolation Examples

**With `.task` isolation:**

```swift
@ObservationTracking(isolation: .task)
private func processData() {
    result = model.computation
}
```

**Generated code:**

```swift
private func processData() {
    observeResult()
}

private func observeResult() {
    result = withObservationTracking {
        model.computation
    } onChange: { [weak self] in
        Task {
            await self?.observeResult()
        }
    }
}
```

**With `.synchronous` isolation:**

```swift
@ObservationTracking(isolation: .synchronous)
private func updateCache() {
    cached = model.data
}
```

**Generated code:**

```swift
private func updateCache() {
    observeCached()
}

private func observeCached() {
    cached = withObservationTracking {
        model.data
    } onChange: { [weak self] in
        self?.observeCached()
    }
}
```

### @CancellableObservation Expansion

**Your code:**

```swift
@CancellableObservation
class Observer {
    @ObservationTracking
    func bind() {
        value = model.property
    }
}
```

**Generated infrastructure:**

```swift
class Observer {
    func bind() {
        observeValue()
    }

    func observeValue() {
        guard isObservingEnabled else { return }
        
        let token = UUID().uuidString
        observationTokens["observeValue"] = token
        value = withObservationTracking {
            model.property
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, token == self.observationTokens["observeValue"] else {
                    return
                }
                self.observeValue()
            }
        }
    }

    func cancelObserveValue() {
        observationTokens.removeValue(forKey: "observeValue")
    }

    // Infrastructure
    private var observationTokens: [String: String] = [:]
    private var isObservingEnabled = true

    func stopObservations() {
        isObservingEnabled = false
        observationTokens.removeAll()
    }

    func startObservationsIfNeeded() {
        guard !isObservingEnabled || observationTokens.isEmpty else { return }
        isObservingEnabled = true
        bind()  // Calls @ObservationTracking functions in this class declaration
    }
}
```

## How It Works

1. **Observation Detection**: The macro scans direct top-level statements in the function body for supported assignments (`property = expression`), supported function calls, and top-level `if` statements that contain assignments
2. **Method Generation**: Creates individual observer methods for each detected top-level statement
3. **Reactive Wrapping**: Wraps assignment right-hand side expressions, supported function call arguments, or whole supported `if` statements with `withObservationTracking`
4. **Auto Re-observation**: Sets up `onChange` callbacks that re-execute the observer methods
5. **Function Transformation**: Replaces detected top-level assignments, function calls, and supported `if` statements in the original function with calls to observer methods
6. **Cancellation Management**: Adds token-based cancellation and control infrastructure
7. **Automatic Restart**: `startObservationsIfNeeded()` automatically calls `@ObservationTracking` functions declared in the same `@CancellableObservation` class declaration

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related

- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [Swift Macros](https://developer.apple.com/documentation/swift/applying-macros)
- [withObservationTracking](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:) )

Inspired by the need for cleaner observation code in UIKit.
