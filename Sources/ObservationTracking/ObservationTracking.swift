/// # ObservationTracking
///
/// A Swift package that provides macros for automatic observation tracking using Swift's Observation framework.
/// This module simplifies the process of setting up observation tracking for multiple property assignments
/// by automatically generating individual observer functions with proper memory management.
///
/// ## Features
///
/// - **Automatic Observer Generation**: Creates individual observer functions for each property assignment
/// - **Memory Safety**: Uses weak references to prevent retain cycles
/// - **Main Actor Safety**: Generates main actor-isolated observation tracking code for UI updates
/// - **Clean Syntax**: Simple macro annotation replaces boilerplate observation code
///
/// ## Usage
///
/// ```swift
/// import ObservationTracking
/// import Observation
///
/// @Observable
/// class SomeObservableClass {
///     var count = 0
///     var message = "Hello"
/// }
///
/// class Observer {
///     weak var classToObserve: SomeObservableClass?
///     var localCount = 0
///     var localMessage = ""
///
///     @ObservationTracking
///     func observeValues() {
///         localCount = classToObserve?.count ?? 0
///         localMessage = classToObserve?.message ?? ""
///     }
/// }
/// ```
///
/// The `@ObservationTracking` macro will automatically generate:
/// - Individual observer functions for each assignment (`observeLocalCount()`, `observeLocalMessage()`)
/// - Proper `withObservationTracking` calls with weak self references
/// - Main actor-isolated task scheduling for observation callbacks
///
/// Automatically generates observation tracking code for property assignments within a function.
///
/// The `@ObservationTracking` macro transforms a function containing property assignments into:
/// 1. A main function that calls individual observer functions
/// 2. Individual observer functions for each assignment that use `withObservationTracking`
/// 3. Proper memory management with weak self references
/// 4. Main actor-isolated task scheduling for observation callbacks
///
/// ## Requirements
///
/// - The macro must be applied to a function with a body
/// - The function must contain at least one assignment statement
/// - Available on macOS 14.0+, iOS 17.0+, tvOS 17.0+, watchOS 10.0+
///
/// ## Example
///
/// **Input:**
///
/// ```swift
/// @ObservationTracking
/// func observeValues() {
///     localValue = classToObserve?.value ?? 0
///     localName = classToObserve?.name ?? ""
/// }
/// ```
///
/// **Generated Output:**
///
/// ```swift
/// func observeValues() {
///     observeLocalValue()
///     observeLocalName()
/// }
///
/// private func observeLocalValue() {
///     localValue = withObservationTracking {
///         classToObserve?.value ?? 0
///     } onChange: { [weak self] in
///         Task { @MainActor in
///             self?.observeLocalValue()
///         }
///     }
/// }
///
/// private func observeLocalName() {
///     localName = withObservationTracking {
///         classToObserve?.name ?? ""
///     } onChange: { [weak self] in
///         Task { @MainActor in
///             self?.observeLocalName()
///         }
///     }
/// }
/// ```
///
/// ## Memory Management
///
/// The generated code uses `[weak self]` capture to prevent retain cycles.
/// When the observer object is deallocated, observation automatically stops,
/// ensuring proper cleanup without manual intervention.
///
/// All observation callbacks are scheduled to run on the main actor using
/// `Task { @MainActor in }`, ensuring UI updates can be performed safely
/// within the observer functions.
@attached(body)
@attached(peer, names: arbitrary)
public macro ObservationTracking() = #externalMacro(module: "ObservationTrackingMacros", type: "ObservationTrackingMacro")
