# ObservationTracking

[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)

[![Language](https://img.shields.io/badge/language-Swift%206.0-orangered.svg?style=flat)](https://www.swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20Mac%20Catalyst%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgray.svg?style=flat)](https://developer.apple.com/discover)

Swift macros that automatically generate reactive observation patterns using Swift's Observation framework. Provides both basic observation tracking and advanced cancellable observation management.

## Overview

ObservationTracking offers four macros:

- **`@ObservationTracking`**: Generates reactive observation for supported top-level assignments, function calls, and `if`/`switch` statements
- **`@CancellableObservation`**: Adds observation lifecycle management with cancellation and selective control
- **`@StartObservations`**: Defers a `startObservationsIfNeeded()` call from an existing method
- **`@StopObservations`**: Defers a `stopObservations()` call from an existing method

The macros can work together to create observation patterns with minimal boilerplate code.

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+ / macOS 14.0+ / Mac Catalyst 17.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+

## Required Imports

Macro expansions reference framework symbols directly, so each source file using the macros must import the frameworks needed by the generated code:

```swift
import Observation
import ObservationTracking
```

## Installation

### Swift Package Manager

Add ObservationTracking to your project through Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VAndrJ/ObservationTracking.git", from: "1.1.2")
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

`@ObservationTracking` can be used on instance methods declared in classes, actors, and extensions. Extension support is syntactic: Swift macros cannot prove the extended type is a class or actor, so the compiler validates whether the generated peer methods and `[weak self]` capture are legal for that extension.

Methods declared directly in a class or actor get generation-based idempotent registration. Calling an annotated method again invalidates its earlier callbacks instead of creating duplicate active registrations. Extension methods remain stateless because Swift extensions cannot add the required stored generation; call those binding methods only once.

The macro transforms these direct top-level statements in the annotated method body:

- Simple assignments such as `property = expression`.
- Direct function calls. The complete call is observed, including every argument and any trailing closures.
- `if` statements containing an assignment or a direct function-call statement in one of their branches. A conditional function call may have any number of arguments because the whole `if` statement is observed.
- `switch` statements containing an assignment or direct function-call statement in a case, including nested `if`/`switch` branches. Case lists, `where` clauses, and `default` cases are preserved as written.

```swift
@ObservationTracking
func bind() {
    title = model.title              // Tracked
    updateTitle(model.title)         // The complete call is tracked
    render(                          // Multiple observed arguments and configuration are supported
        title: model.title,
        count: model.count,
        style: .headline
    )
    updateItems([model.firstItem, model.secondItem])
    updateGreeting("Hello \(model.name)")
    refreshSummary()                 // Reads performed synchronously inside the helper are tracked

    if model.isEnabled {             // Tracked as one observation
        subtitle = model.subtitle
    }

    if model.shouldRefresh {         // Calls when true and keeps tracking when false
        refresh()
    }

    if let value = model.detail {    // Tracked as one observation
        detail = value
    }

    subtitle = if model.isEnabled {  // Tracked as an assignment expression
        "Enabled"
    } else {
        "Disabled"
    }

    title = switch model.state {     // Tracked as an assignment expression
    case .ready: "Ready"
    case .loading: "Loading"
    }

    switch model.state {             // Tracked as one observation
    case .ready:
        showContent()
    case .loading:
        showSpinner()
    }

    items.forEach { item in
        lastTitle = item.title       // Not transformed
    }

    defer {
        footer = model.footer        // Not transformed
    }
}
```

For a supported top-level `if` or `switch`, the macro wraps the whole control-flow expression in `withObservationTracking`, so its subject or conditions and whichever branch executes are observed. It is evaluated again after any dependency read along the active path changes. The binding also evaluates immediately when the annotated method is called.

Direct calls are handled the same way: the original call syntax is placed unchanged inside `withObservationTracking`. This lets observation dependencies come from multiple arguments, string interpolation, array/dictionary/tuple elements, a synchronously executed helper body, or trailing closures without rebuilding the call.

Assignments and function calls inside `guard`, loops, closures, local functions, `defer`, and other unsupported nested scopes are not transformed independently. Move bindings that must be observed into top-level statements, supported top-level `if`/`switch` statements, or helper methods annotated separately with `@ObservationTracking`.

Generated observers are peer methods, so they cannot capture parameters or local variables from the annotated method. Keep tracked expressions based on instance, global, or static state. Parameterless binding methods are the safest form.

### Isolation Control

The `@ObservationTracking` macro supports an `isolation` parameter that controls how observation change handlers are generated.

#### Isolation Options

- **`nil` or omitted**: Infers `.mainActor` in classes and extensions, or `.task` in actors.
- **`.mainActor`**: Executes change handlers in `Task { @MainActor in ... }`.
- **`.task`**: Executes change handlers in an unstructured `Task { await ... }`. This schedules asynchronous re-observation, but it does not make mutable class state actor-isolated by itself.

### Example

For a real-use case, see `ExampleScreenView` in the `Example` project. It demonstrates direct
assignments and function calls, `if` and `switch` expressions/statements, individual and global
cancellation, and explicit `@StartObservations`/`@StopObservations` screen lifecycle hooks.

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

### Generation-Based Cancellation

The macro uses lightweight monotonic `UInt` generations to invalidate stale callbacks. Cancelling an observer removes its current generation; restarting it assigns a newer generation, so callbacks from older registrations cannot resume observation.

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
- **Idempotent Registration**: Repeated calls to methods declared directly in classes or actors replace earlier registrations instead of multiplying callbacks
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

private var _observationTrackingGenerationObserveCount: UInt = 0

private func observeCount() {
    _observationTrackingGenerationObserveCount &+= 1
    let generation = _observationTrackingGenerationObserveCount
    count = withObservationTracking {
        model.value
    } onChange: { [weak self] in
        Task { @MainActor in
            guard let self,
                  generation == self._observationTrackingGenerationObserveCount else {
                return
            }
            self.observeCount()
        }
    }
}

private var _observationTrackingGenerationObserveName: UInt = 0

private func observeName() {
    _observationTrackingGenerationObserveName &+= 1
    let generation = _observationTrackingGenerationObserveName
    name = withObservationTracking {
        model.name ?? "default"
    } onChange: { [weak self] in
        Task { @MainActor in
            guard let self,
                  generation == self._observationTrackingGenerationObserveName else {
                return
            }
            self.observeName()
        }
    }
}
```

**Top-level control-flow statements:**

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

private var _observationTrackingGenerationObserveSubtitle: UInt = 0

private func observeSubtitle() {
    _observationTrackingGenerationObserveSubtitle &+= 1
    let generation = _observationTrackingGenerationObserveSubtitle
    withObservationTracking {
        if model.isEnabled {
            subtitle = model.subtitle
        } else {
            subtitle = ""
        }
    } onChange: { [weak self] in
        Task { @MainActor in
            guard let self,
                  generation == self._observationTrackingGenerationObserveSubtitle else {
                return
            }
            self.observeSubtitle()
        }
    }
}
```

**Conditional function calls:**

```swift
@ObservationTracking
private func bind() {
    if viewModel.isSomethingEnabled {
        someFunction()
    }
}
```

**Generated code:**

```swift
private func bind() {
    observeSomeFunction()
}

private var _observationTrackingGenerationObserveSomeFunction: UInt = 0

private func observeSomeFunction() {
    _observationTrackingGenerationObserveSomeFunction &+= 1
    let generation = _observationTrackingGenerationObserveSomeFunction
    withObservationTracking {
        if viewModel.isSomethingEnabled {
            someFunction()
        }
    } onChange: { [weak self] in
        Task { @MainActor in
            guard let self,
                  generation == self._observationTrackingGenerationObserveSomeFunction else {
                return
            }
            self.observeSomeFunction()
        }
    }
}
```

The generated observer always reads `isSomethingEnabled`. It calls `someFunction()` only while the value is `true`, and remains registered while the value is `false` so a later change can trigger another evaluation.

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

private var _observationTrackingGenerationObserveResult: UInt = 0

private func observeResult() {
    _observationTrackingGenerationObserveResult &+= 1
    let generation = _observationTrackingGenerationObserveResult
    result = withObservationTracking {
        model.computation
    } onChange: { [weak self] in
        Task {
            guard let self,
                  await generation == self._observationTrackingGenerationObserveResult else {
                return
            }
            await self.observeResult()
        }
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

        observationGeneration &+= 1
        let generation = observationGeneration
        observationTokens["observeValue"] = generation
        value = withObservationTracking {
            model.property
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self,
                      generation == self.observationTokens["observeValue"] else {
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
    private var observationTokens: [String: UInt] = [:]
    private var observationGeneration: UInt = 0
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

1. **Observation Detection**: The macro scans direct top-level statements in the function body for supported assignments (`property = expression`), supported function calls, and top-level `if`/`switch` statements containing assignments or function calls
2. **Method Generation**: Creates individual observer methods for each detected top-level statement
3. **Reactive Wrapping**: Wraps assignment right-hand side expressions or complete supported function calls and `if`/`switch` statements with `withObservationTracking`
4. **Idempotent Re-observation**: Assigns each registration a generation and lets only the latest callback re-execute its observer method
5. **Function Transformation**: Replaces detected top-level assignments, function calls, and supported `if`/`switch` statements in the original function with calls to observer methods
6. **Cancellation Management**: Adds generation-based cancellation and control infrastructure
7. **Automatic Restart**: `startObservationsIfNeeded()` automatically calls `@ObservationTracking` functions declared in the same `@CancellableObservation` class declaration

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related

- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [Swift Macros](https://developer.apple.com/documentation/swift/applying-macros)
- [withObservationTracking](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:))

Inspired by the need for cleaner observation code in UIKit.
