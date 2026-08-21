import 'dart:math' as math;

import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// The Compasso mark: an open C with a compass needle inside it.
///
/// Drawn rather than shipped as an asset, for three reasons that all turned out
/// to matter: it takes the palette, so it is fuchsia on either ground without a
/// second file; it stays sharp from the 20pt in a tab bar to the 512px of a
/// PWA icon; and the gap in the C is the same arc the progress ring uses, which
/// is what makes the mark and the product's main instrument look related
/// instead of merely adjacent.
class CompassoMark extends StatelessWidget {
  const CompassoMark({super.key, this.size = 26, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: CompassoMarkPainter(color ?? context.palette.action),
      isComplex: false,
    ),
  );
}

/// Public because the icon generator under `tool/` paints with it directly:
/// the app icon and the mark in the app are then the same drawing, and cannot
/// drift apart the way an exported asset does.
class CompassoMarkPainter extends CustomPainter {
  const CompassoMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);

    // Everything is painted into its own layer, because the pivot is punched
    // out with `BlendMode.clear` — on the bare canvas that would erase whatever
    // is behind the mark, not just inside it.
    canvas.saveLayer(Offset.zero & size, Paint());

    // The C: an arc that opens to the right, between -52° and +52°, drawn from
    // the far side. Butt caps, not round — the brand board's terminals are cut
    // square, and rounding them makes the mark read as a generic loading spinner.
    final stroke = s * .135;
    final radius = (s - stroke) / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = color;
    const gap = 52 * math.pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      gap,
      2 * math.pi - 2 * gap,
      false,
      ring,
    );

    // The needle: two long, narrow triangles meeting at the centre, tilted the
    // way a compass points when it is being read rather than stored.
    final needle = Paint()..color = color;
    final long = s * .355;
    final wide = s * .075;
    // Nordeste, como no board: a agulha aponta para dentro da abertura do C,
    // não para a parte fechada. Apontada para o outro lado ela briga com o
    // traço do C em vez de ocupar o vazio que ele deixa.
    const tilt = 34 * math.pi / 180;
    Offset at(double along, double across) =>
        centre +
        Offset(
          along * math.sin(tilt) + across * math.cos(tilt),
          -along * math.cos(tilt) + across * math.sin(tilt),
        );

    canvas.drawPath(
      Path()
        ..moveTo(at(long, 0).dx, at(long, 0).dy)
        ..lineTo(at(0, wide).dx, at(0, wide).dy)
        ..lineTo(at(-long * .82, 0).dx, at(-long * .82, 0).dy)
        ..lineTo(at(0, -wide).dx, at(0, -wide).dy)
        ..close(),
      needle,
    );

    // The pivot, punched out so the needle reads as a needle on any ground.
    canvas.drawCircle(centre, s * .085, Paint()..color = color);
    canvas.drawCircle(
      centre,
      s * .038,
      Paint()
        ..color = color
        ..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassoMarkPainter old) => old.color != color;
}

/// Mark plus name, the way the brand board sets it: the wordmark is lowercase
/// and the mark sits tight against it.
class CompassoWordmark extends StatelessWidget {
  const CompassoWordmark({
    super.key,
    this.markSize = 26,
    this.tagline = false,
    this.color,
  });

  final double markSize;
  final bool tagline;
  final Color? color;

  /// The one line the brand board pairs with the name. It is not decoration:
  /// "no ritmo certo" is the product's actual claim — this app is about the
  /// cycle a bill closes on, not about a balance at an instant.
  static const claim = 'Seu dinheiro no ritmo certo.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final name = Text(
      'compasso',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: type.titleLg.copyWith(
        color: color ?? palette.ink,
        fontSize: markSize * .78,
        letterSpacing: -0.4,
        fontVariations: const [FontVariation('wght', 620)],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompassoMark(size: markSize, color: color),
            SizedBox(width: markSize * .28),
            Flexible(child: name),
          ],
        ),
        if (tagline) ...[
          const SizedBox(height: Space.xxs),
          Text(claim, style: type.bodySm.copyWith(color: palette.inkMuted)),
        ],
      ],
    );
  }
}
