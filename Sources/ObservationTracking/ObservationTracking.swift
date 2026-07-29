/// Defines the task scheduling strategy for observation change handlers.
public enum OnChangeBlockIsolation {
    /// Executes change handlers directly in a main-actor Task.
    ///
    /// Use this only when the annotated method and its owning reference type are
    /// main-actor isolated.
    case mainActor
    /// Schedules change handlers in an unstructured Task.
    ///
    /// The task awaits a private helper that inherits the owning declaration's
    /// isolation. This does not make otherwise-unisolated mutable class state actor-isolated.
    case task
}

/// Swift macros for automatic observation tracking using Swift's Observation framework.
///
/// Generates individual observer functions for supported assignments, function calls, and control flow
/// with proper memory management.
/// Each generated observer uses a private integer generation, so calling the annotated method again
/// invalidates its earlier callbacks instead of creating duplicate active registrations. Extension
/// methods remain stateless because Swift extensions cannot add the required stored generation.
///
/// The source file using this macro must import `Observation`, because the expansion references
/// `withObservationTracking` directly. The macro can be used on instance methods declared in
/// classes, actors, and extensions. Methods declared directly in actors default to `.task`.
/// `.task` callbacks await a helper that inherits the owning declaration's isolation.
///
/// The macro only transforms direct top-level statements in the annotated function body. Top-level
/// `if` and `switch` statements containing assignments or function calls are tracked as a unit.
/// Direct function calls are also tracked as a unit, preserving all arguments and trailing closures.
/// Assignments inside unsupported control flow, closures, local functions, `defer` blocks, or other
/// nested scopes are left unchanged. Move observable bindings to top-level statements when they
/// should be tracked.
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
/// @MainActor
/// @ObservationTracking // Infers .mainActor outside actors.
/// func bind() {
///     label.text = viewModel.title
/// }
///
/// @ObservationTracking(isolation: .task)
/// func bind() {
///     value = store.data
/// }
/// ```
///
/// - Parameter isolation: Controls how observation change handlers are scheduled. Pass `nil` or omit the argument to infer `.mainActor` in classes and extensions, or `.task` in actors. The `.mainActor` form requires the annotated method and owning reference type to be main-actor isolated.
///
/// Automatically generates observation tracking code for supported binding statements.
@attached(body)
@attached(peer, names: arbitrary)
public macro ObservationTracking(isolation: OnChangeBlockIsolation? = nil) =
    #externalMacro(module: "ObservationTrackingMacros", type: "ObservationTrackingMacro")

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
@attached(
    member,
    names: named(observationTokens),
    named(observationGeneration),
    named(isObservingEnabled),
    named(stopObservations),
    named(startObservationsIfNeeded),
    named(viewWillAppear),
    named(viewDidDisappear)
)
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
