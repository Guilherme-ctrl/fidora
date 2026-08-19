import 'package:clock/clock.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The instant every golden is rendered at.
///
/// Both the demo ledger and the derivations that answer "how many days are
/// left" read the clock, so without pinning it a golden would differ every
/// morning. [withGoldenClock] freezes both at once.
final goldenInstant = DateTime(2026, 8, 19, 9);

/// The period every golden is rendered for.
FinancePeriod get goldenPeriod => FinancePeriod.month(goldenInstant);

/// Runs [body] with the clock frozen at [goldenInstant].
Future<T> withGoldenClock<T>(Future<T> Function() body) {
  // The appearance control reads stored preferences, and a page that renders it
  // needs the channel to answer. Setting it here rather than in each test keeps
  // the next screen that stores something from failing the same way.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return withClock(Clock.fixed(goldenInstant), body);
}

/// The widths the design system names, plus the one where the current shell
/// switches. 390 is an iPhone 15, 900 is the breakpoint the app uses today and
/// 1440 is the width the new content container is capped at.
const goldenWidths = <String, Size>{
  '390': Size(390, 1400),
  '900': Size(900, 1500),
  '1440': Size(1440, 1600),
};

/// Pumps [page] inside the real theme at a fixed size, with animations and
/// text scaling pinned so the only thing a golden can record is the design.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget page, {
  required Size size,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  // The test view defaults to 3x, which would store a 1440pt golden as a
  // 4320px image — nine times the bytes for no extra information in a design
  // review, on files that get regenerated once per pull request.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            // A golden that captures a running animation is a golden that
            // fails at random.
            disableAnimations: true,
          ),
          child: Scaffold(body: page),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
