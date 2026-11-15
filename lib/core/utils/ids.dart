import 'package:uuid/uuid.dart';

/// Produces a new unique identifier. Injected rather than called directly so
/// tests can supply predictable ids.
typedef IdGenerator = String Function();

const Uuid _uuid = Uuid();

/// A random (version 4) UUID.
String newId() => _uuid.v4();

/// The current time. Injected so tests control "now".
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
