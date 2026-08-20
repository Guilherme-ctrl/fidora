import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Where a discarded cause goes.
///
/// The audit found eight `catch (_)` that threw the error away entirely, and
/// the project has no crash reporting to recover it from — so a failed receipt
/// pick, a refused share and a rejected write were indistinguishable from each
/// other and from a bug, forever.
///
/// This is deliberately the smallest thing that fixes that. It is an interface
/// so a crash reporter can be injected later without touching a call site, and
/// the default writes to the developer log, which is visible in the IDE and
/// costs nothing in release.
abstract interface class Logger {
  void error(String context, Object cause, StackTrace stack);
}

class DeveloperLogger implements Logger {
  const DeveloperLogger();

  @override
  void error(String context, Object cause, StackTrace stack) {
    developer.log(
      context,
      name: 'finora',
      error: cause,
      stackTrace: stack,
      level: 1000,
    );
  }
}

/// Discards everything. For tests that deliberately drive a failure path and
/// should not print a stack for it.
class SilentLogger implements Logger {
  const SilentLogger();

  @override
  void error(String context, Object cause, StackTrace stack) {}
}

/// The logger used by call sites that have no injected one yet.
///
/// A mutable global is a compromise and it is worth naming as one: the eight
/// swallowed causes are in widgets that unit 6 will rewrite into Cubits with
/// proper dependencies, and blocking the fix on that rewrite would leave the
/// causes discarded for five more units. It is replaceable in tests, which is
/// what keeps it from being a singleton in the harmful sense.
Logger appLogger = kDebugMode ? const DeveloperLogger() : const SilentLogger();
