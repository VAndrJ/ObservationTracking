/// Defines the concurrency isolation strategy for observation change handlers.
public enum OnChangeBlockIsolation {
    /// Executes change handlers in a Task in `onChange` block.
    ///
    /// Generates: `Task { @MainActor in self?.functionCall() }`
    case mainActor
    /// Executes change handlers in a Task in `onChange` block.
    ///
    /// Generates: `Task { await self?.functionCall() }`
    case actor
    /// Executes change handlers directly without task wrapping in `onChange` block.
    ///
    /// Generates: `self?.functionCall()`
    case none
}

/// Swift macros for automatic observation tracking using Swift's Observation framework.
///
/// Generates individual observer functions for property assignments with proper memory management.
/// The macro analyzes property assignments in the function body and creates corresponding observation handlers.
///
/// ## Basic Usage
///
/// ```swift
/// @ObservationTracking
/// func bind() {
///     count = model.value
///     name = model.name
/// }
/// ```
///
/// ## Isolation Control
///
/// You can control the behavior of the generated observation handlers in the `onChange` block:
///
/// ```swift
/// @ObservationTracking // Default to (isolation: .mainActor), Generates: `Task { @MainActor in self?.bind() }`
/// func bind() {
///     label.text = viewModel.title
/// }
///
/// @ObservationTracking(isolation: .actor) // Generates: `Task { await self?.bind() }`
/// func bind() {
///     value = store.data
/// }
///
/// @ObservationTracking(isolation: .none) // Direct execution, Generates: `self?.bind()`
/// func bind() {
///     value = store.data
/// }
/// ```
///
/// - Parameter isolation: Controls how observation change handlers are executed. Defaults to `.mainActor`.
///
/// Automatically generates observation tracking code for property assignments.
@attached(body)
@attached(peer, names: arbitrary)
public macro ObservationTracking(isolation: OnChangeBlockIsolation = .mainActor) = #externalMacro(module: "ObservationTrackingMacros", type: "ObservationTrackingMacro")

/// Adds cancellable observation infrastructure to a class.
///
/// Generates observation tokens, control flags, and start/stop methods for observation management.
///
/// ```swift
/// @CancellableObservation
/// class Observer {
///     @ObservationTracking
///     func bind() {
///         value = model.property
///     }
/// }
/// ```
@attached(memberAttribute)
@attached(member, names: named(observationTokens), named(isObservingEnabled), named(stopObservations), named(startObservationsIfNeeded), named(viewWillAppear), named(viewDidDisappear))
public macro CancellableObservation(screen: Bool = false) = #externalMacro(module: "ObservationTrackingMacros", type: "CancellableObservationMacro")

/// Automatically adds `startObservationsIfNeeded()` call at the end of the function body.
///
/// Use this macro to ensure observations are started when a function is executed.
///
/// ```swift
/// @StartObservations
/// func setupBinding() {
///     // existing function code
///     // startObservationsIfNeeded() will be added automatically
/// }
/// ```
@attached(body)
public macro StartObservations() = #externalMacro(module: "ObservationTrackingMacros", type: "StartObservationsMacro")

/// Automatically adds `stopObservations()` call at the end of the function body.
///
/// Use this macro to ensure observations are stopped when a function is executed.
///
/// ```swift
/// @StopObservations
/// func cleanup() {
///     // existing function code
///     // stopObservations() will be added automatically
/// }
/// ```
@attached(body)
public macro StopObservations() = #externalMacro(module: "ObservationTrackingMacros", type: "StopObservationsMacro")
