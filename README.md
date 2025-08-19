# ObservationTracking

[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)

[![Language](https://img.shields.io/badge/language-Swift%206.0-orangered.svg?style=flat)](https://www.swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20visionOS-lightgray.svg?style=flat)](https://developer.apple.com/discover)

A Swift macro that automatically generates reactive observation for property assignments using Swift's `withObservationTracking`.

## Overview

The `@ObservationTracking` macro generates a separate private observation method that automatically re-executes when the observed values change for each property assignment in the decorated function.

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+

## Installation

### Swift Package Manager

Add ObservationTracking to your project through Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VAndrJ/ObservationTracking.git", from: "1.0.0")
]
```

## Usage

### Basic Example

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

### Example

For a real-use case, see `ExampleView` in the `Example` project.

## What the Macro Generates

The macro transforms function into reactive observation patterns:

**Code with macro:**
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

## How It Works

1. **Property Detection**: The macro scans function bodies for property assignments (`property = expression`)
2. **Method Generation**: Creates private observer methods for each assignment
3. **Reactive Wrapping**: Wraps the right-hand side of assignments with `withObservationTracking`
4. **Auto Re-observation**: Sets up `onChange` callbacks that re-execute the observer methods
5. **Function Transformation**: Replaces assignments in the original function with calls to observer methods

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related

- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [Swift Macros](https://developer.apple.com/documentation/swift/applying-macros)
- [withObservationTracking](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:) )

Inspired by the need for cleaner observation code in UIKit.
