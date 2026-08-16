/// Compatibility shim retained for legacy imports.
///
/// The owner properties screen no longer needs a dedicated thumbnail widget,
/// but older code paths still import this file. Keeping this lightweight file
/// avoids a build-breaking missing-URI error without changing runtime behavior.
