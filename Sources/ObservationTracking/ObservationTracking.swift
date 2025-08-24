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
@attached(member, names: named(observationTokens), named(isObservingEnabled), named(stopObservations), named(startObservationsIfNeeded))
public macro CancellableObservation() = #externalMacro(module: "ObservationTrackingMacros", type: "CancellableObservationMacro")
