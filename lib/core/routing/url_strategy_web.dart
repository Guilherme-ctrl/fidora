import 'package:flutter_web_plugins/url_strategy.dart';

/// `/faturas?mes=2026-08` instead of `/#/faturas?mes=2026-08`.
///
/// The host must serve `index.html` for any unmatched path, or a reload on a
/// deep address returns 404. Vercel needs a rewrite of `/(.*)` to `/index.html`.
void useCleanUrls() => usePathUrlStrategy();
