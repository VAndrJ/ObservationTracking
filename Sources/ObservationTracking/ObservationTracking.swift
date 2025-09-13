/// Swift macros for automatic observation tracking using Swift's Observation framework.
///
/// Generates individual observer functions for property assignments with proper memory management.
///
/// ```swift
/// @ObservationTracking
/// func bind() {
///     count = model.value
///     name = model.name
/// }
/// ```
///
/// Automatically generates observation tracking code for property assignments.
@attached(body)
@attached(peer, names: arbitrary)
public macro ObservationTracking() = #externalMacro(module: "ObservationTrackingMacros", type: "ObservationTrackingMacro")

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
