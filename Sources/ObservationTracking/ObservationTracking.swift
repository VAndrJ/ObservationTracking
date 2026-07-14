/// Defines the concurrency isolation strategy for observation change handlers.
public enum OnChangeBlockIsolation {
    /// Executes change handlers in a Task in `onChange` block.
    ///
    /// Generates: `Task { @MainActor in self?.functionCall() }`
    case mainActor
    /// Executes change handlers in an unstructured Task in the `onChange` block.
    ///
    /// Generates: `Task { await self?.functionCall() }`
    ///
    /// This schedules asynchronous re-observation, but it does not make mutable class state
    /// actor-isolated by itself.
    case task

    /// Executes change handlers synchronously in the `onChange` block without task wrapping.
    ///
    /// Generates: `self?.functionCall()`
    ///
    /// Use this only when direct re-observation from the `onChange` callback is safe for your
    /// executor and reentrancy model.
    case synchronous
}

/// Swift macros for automatic observation tracking using Swift's Observation framework.
///
/// Generates individual observer functions for property assignments with proper memory management.
/// The macro analyzes property assignments in the function body and creates corresponding observation handlers.
/// Each generated observer uses a private integer generation, so calling the annotated method again
/// invalidates its earlier callbacks instead of creating duplicate active registrations. Extension
/// methods remain stateless because Swift extensions cannot add the required stored generation.
///
/// The source file using this macro must import `Observation`, because the expansion references
/// `withObservationTracking` directly. The macro can be used on instance methods declared in
/// classes, actors, and extensions. Actor-contained methods default to `.task` isolation so
/// generated re-observation calls are awaited.
///
/// The macro only transforms direct top-level statements in the annotated function body. Assignments
/// inside control-flow statements, closures, local functions, `defer` blocks, or other nested scopes
/// are left unchanged. Move observable bindings to top-level statements when they should be tracked.
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
/// @ObservationTracking // Infers .mainActor outside actors, generates: `Task { @MainActor in self?.bind() }`
/// func bind() {
///     label.text = viewModel.title
/// }
///
/// @ObservationTracking(isolation: .task) // Generates: `Task { await self?.bind() }`
/// func bind() {
///     value = store.data
/// }
///
/// @ObservationTracking(isolation: .synchronous) // Direct synchronous execution, Generates: `self?.bind()`
/// func bind() {
///     value = store.data
/// }
/// ```
///
/// - Parameter isolation: Controls how observation change handlers are executed. Pass `nil` or omit the argument to infer `.mainActor` in classes and extensions, or `.task` in actors.
///
/// Automatically generates observation tracking code for property assignments.
@attached(body)
@attached(peer, names: arbitrary)
public macro ObservationTracking(isolation: OnChangeBlockIsolation? = nil) = #externalMacro(module: "ObservationTrackingMacros", type: "ObservationTrackingMacro")

/// Adds cancellable observation infrastructure to a class.
///
/// Generates observation generations, control flags, and start/stop methods for observation management.
///
/// Cancellable expansions use lightweight integer generations to invalidate stale callbacks.
/// If `screen` is `true`, the macro emits `viewWillAppear(_:)` and `viewDidDisappear(_:)`
/// overrides with `super` calls, so use it only on `UIViewController`
/// subclasses or custom screen base classes that provide compatible overridable lifecycle methods.
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
@attached(member, names: named(observationTokens), named(observationGeneration), named(isObservingEnabled), named(stopObservations), named(startObservationsIfNeeded), named(viewWillAppear), named(viewDidDisappear))
public macro CancellableObservation(screen: Bool = false) = #externalMacro(module: "ObservationTrackingMacros", type: "CancellableObservationMacro")

/// Automatically defers a `startObservationsIfNeeded()` call from the function body.
///
/// Use this macro to ensure observations are started when a function exits, including early returns and thrown errors.
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

/// Automatically defers a `stopObservations()` call from the function body.
///
/// Use this macro to ensure observations are stopped when a function exits, including early returns and thrown errors.
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
