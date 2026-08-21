import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A line with no axes, no grid and no labels.
///
/// The dashboard already has a full chart of the same data, with a scale and a
/// tooltip; this is the other thing a chart can be — a shape you read in half a
/// second on the way to somewhere else. It draws the **accumulated** spend of
/// the period rather than the daily figure, because a climbing line answers
/// "am I ahead of my own month?" and a spiky one only answers "was Tuesday
/// expensive?".
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 56,
    this.color,
    this.progress = 1.0,
  });

  /// One value per day of the period, already accumulated.
  final List<double> values;
  final double height;
  final Color? color;

  /// How much of the period has actually happened. The line stops there — a
  /// flat run to the right edge would read as "spending stopped", which is the
  /// opposite of "the month is not over".
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _SparkPainter(
            values: values,
            colour: color ?? palette.accent,
            reveal: t,
            progress: progress.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.values,
    required this.colour,
    required this.reveal,
    required this.progress,
  });

  final List<double> values;
  final Color colour;
  final double reveal;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final peak = values.reduce(math.max);
    if (peak <= 0) return;

    final last = math.max(1, (values.length * progress).round());
    final step = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < last; i++)
        Offset(i * step, size.height - (values[i] / peak) * size.height * .88),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      // Catmull–Rom-ish smoothing: the control point sits halfway, which keeps
      // the curve from overshooting below zero on a flat stretch.
      final previous = points[i - 1];
      final current = points[i];
      final mid = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));

    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
          colour.withValues(alpha: .26),
          colour.withValues(alpha: 0),
        ]),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour,
    );

    // The head of the line, lit. It is where "today" is, and it is the one
    // moment of glow the brand board actually shows.
    final head = points.last;
    canvas.drawCircle(
      head,
      7,
      Paint()
        ..color = colour.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(head, 3.2, Paint()..color = colour);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.reveal != reveal ||
      old.colour != colour ||
      old.progress != progress ||
      !listEquals(old.values, values);
}
