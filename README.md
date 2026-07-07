# ObservationTracking

[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)

[![Language](https://img.shields.io/badge/language-Swift%206.0-orangered.svg?style=flat)](https://www.swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20visionOS-lightgray.svg?style=flat)](https://developer.apple.com/discover)

Swift macros that automatically generate reactive observation patterns using Swift's Observation framework. Provides both basic observation tracking and advanced cancellable observation management.

## Overview

ObservationTracking offers two macros:

- **`@ObservationTracking`**: Generates reactive observation for property assignments
- **`@CancellableObservation`**: Adds advanced observation lifecycle management with cancellation, and selective control

Both macros work together to create robust observation patterns with minimal boilerplate code.

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

The `@ObservationTracking` macro automatically generates reactive observation for each property assignment in a function:

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

`@ObservationTracking` only transforms direct top-level statements in the annotated function body. Keep observable assignments and supported function calls as plain statements in the binding method.

```swift
@ObservationTracking
func bind() {
    title = model.title              // Tracked
    updateTitle(model.title)         // Tracked when there is one non-literal argument

    if model.isEnabled {
        subtitle = model.subtitle    // Not transformed
    }

    items.forEach { item in
        lastTitle = item.title       // Not transformed
    }

    defer {
        footer = model.footer        // Not transformed
    }
}
```

Assignments inside `if`, `guard`, `switch`, loops, closures, local functions, `defer`, and other nested scopes are left as normal Swift code. Move bindings that must be observed into top-level statements or helper methods annotated separately with `@ObservationTracking`.

### Isolation Control

The `@ObservationTracking` macro supports an `isolation` parameter that controls how observation change handlers are generated

#### Isolation Options

- **`.mainActor` (default)**: Executes change handlers in `Task { @MainActor in ... }`.
- **`.task`**: Executes change handlers in an unstructured `Task { await ... }`. This schedules asynchronous re-observation, but it does not make mutable class state actor-isolated by itself.
- **`.synchronous`**: Executes change handlers directly in the `onChange` callback without Task wrapping. Use only when synchronous re-observation is safe for your executor and reentrancy model.

`.actor` is deprecated and kept only as a compatibility spelling for `.task`. `.none` is deprecated and kept only as a compatibility spelling for `.synchronous`.

### Example

For a real-use case, see `ExampleView` in the `Example` project.

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

// Restart all observations (automatically calls all @ObservationTracking functions)
observer.startObservationsIfNeeded()
```

### Token-Based Cancellation

The macro automatically handles cancellation with tokens (randomly generated string within the one observation update cycle).

### UIKit Screen Lifecycle

`@CancellableObservation(screen: true)` is UIKit lifecycle glue. It emits `override func viewWillAppear(_:)` and `override func viewDidDisappear(_:)` methods that call `super`, then start or stop observations.

Use `screen: true` only on `UIViewController` subclasses. Swift macros do not perform full superclass type checking, so applying this option to an arbitrary class can generate invalid override or `super` calls. If the class already implements these lifecycle methods, the macro adds `@StartObservations` or `@StopObservations` to the existing method when possible instead of generating a duplicate method.

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
        guard !isObservingEnabled else { return }
        isObservingEnabled = true
        bind()  // Automatically calls all @ObservationTracking functions
    }
}
```

## How It Works

1. **Property Detection**: The macro scans only direct top-level statements in the function body for supported assignments (`property = expression`) and supported function calls
2. **Method Generation**: Creates individual observer methods for each detected top-level statement
3. **Reactive Wrapping**: Wraps right-hand side expressions with `withObservationTracking`
4. **Auto Re-observation**: Sets up `onChange` callbacks that re-execute the observer methods
5. **Function Transformation**: Replaces detected top-level assignments and function calls in the original function with calls to observer methods
6. **Cancellation Management**: Adds token-based cancellation and control infrastructure
7. **Automatic Restart**: `startObservationsIfNeeded()` automatically calls all `@ObservationTracking` functions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related

- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [Swift Macros](https://developer.apple.com/documentation/swift/applying-macros)
- [withObservationTracking](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:) )

Inspired by the need for cleaner observation code in UIKit.
