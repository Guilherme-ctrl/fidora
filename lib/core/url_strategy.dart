/// Clean addresses on the web, nothing anywhere else.
///
/// Flutter defaults to the hash strategy, so every address would read
/// `/#/faturas?mes=2026-08`. That still gives Back and F5, but it is not an
/// address anyone would paste, and the fragment never reaches a server — so no
/// log, no analytics and no share preview would ever see which screen it was.
///
/// The import is conditional because `flutter_web_plugins` only exists on the
/// web, and this app also builds for iOS.
library;

export 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
