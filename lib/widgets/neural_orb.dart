import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeuralOrb extends StatefulWidget {
  const NeuralOrb({super.key, required this.active, required this.speaking});
  final bool active;
  final bool speaking;

  @override
  State<NeuralOrb> createState() => _NeuralOrbState();
}

class _NeuralOrbState extends State<NeuralOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 13000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _NeuralOrbPainter(
          progress: _controller.value,
          active: widget.active,
          speaking: widget.speaking,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NeuralOrbPainter extends CustomPainter {
  _NeuralOrbPainter({required this.progress, required this.active, required this.speaking});
  final double progress;
  final bool active;
  final bool speaking;

  static final List<math.Point<double>> _sphere = List.generate(104, (i) {
    const goldenAngle = 2.399963229728653;
    final y = 1 - 2 * (i + .5) / 104;
    final r = math.sqrt(math.max(0, 1 - y * y));
    final theta = goldenAngle * i;
    return math.Point<double>(math.cos(theta) * r, math.sin(theta) * r + y * 0.0001);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .405;
    final angle = progress * math.pi * 2;
    final pulse = math.sin(progress * math.pi * 12) * (active ? .035 : .012);
    final r = radius * (1 + pulse + (speaking ? .025 : 0));

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF48E6FF).withOpacity(active ? .19 : .105),
          const Color(0xFF087BBD).withOpacity(.055),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.5));
    canvas.drawCircle(c, r * 1.5, glow);

    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF5DEBFF).withOpacity(.24);
    canvas.drawCircle(c, r, outer);

    // Three faint orbital rings add depth without relying on external images.
    for (var ring = 0; ring < 3; ring++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-.48 + ring * .81 + angle * (ring.isEven ? .035 : -.027));
      final oval = Rect.fromCenter(
        center: Offset.zero,
        width: r * (2.35 - ring * .09),
        height: r * (.48 + ring * .08),
      );
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = const Color(0xFF52C8F6).withOpacity(.12 + ring * .035);
      canvas.drawOval(oval, ringPaint);
      canvas.restore();
    }

    final points = <Offset>[];
    final depth = <double>[];
    for (var i = 0; i < _sphere.length; i++) {
      final p = _sphere[i];
      final x0 = p.x;
      final y0 = (i / _sphere.length * 2 - 1) * .985;
      // Make a spherical lattice with a small deterministic vertical variation.
      final x = x0 * math.cos(angle) - y0 * math.sin(angle) * .17;
      final y = y0 * math.cos(.22) + p.y * math.sin(.22);
      final z = math.sin(angle) * x0 + p.y * math.cos(angle);
      final perspective = 1 / (1.14 - z * .16);
      points.add(Offset(c.dx + x * r * perspective, c.dy + y * r * perspective));
      depth.add(z);
    }

    // Connect nearby nodes; opacity depends on depth to create a 3D mesh.
    final linePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = .55;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final dx = points[i].dx - points[j].dx;
        final dy = points[i].dy - points[j].dy;
        final d2 = dx * dx + dy * dy;
        if (d2 < r * r * .105) {
          final opacity = ((1 - d2 / (r * r * .105)) * .19 + .035) *
              (.50 + ((depth[i] + depth[j] + 2) / 4) * .5);
          linePaint.color = Color.lerp(const Color(0xFF1676C4), const Color(0xFF7BEFFF), (depth[i] + 1) / 2)!
              .withOpacity(opacity.clamp(0.0, .30).toDouble());
          canvas.drawLine(points[i], points[j], linePaint);
        }
      }
    }

    final dotPaint = Paint();
    for (var i = 0; i < points.length; i++) {
      final front = ((depth[i] + 1) / 2).clamp(0.0, 1.0).toDouble();
      final dotRadius = (.65 + front * 1.55) * (active ? 1.18 : 1.0);
      dotPaint.color = Color.lerp(const Color(0xFF1688C4), const Color(0xFFB4F7FF), front)!
          .withOpacity(.25 + front * .60);
      canvas.drawCircle(points[i], dotRadius, dotPaint);
      if (i % 19 == 0) {
        final halo = Paint()..color = const Color(0xFF36C8FF).withOpacity(.11 + front * .09);
        canvas.drawCircle(points[i], dotRadius * 3.6, halo);
      }
    }

    // Central core and a tiny pulse ring.
    final coreGlow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFE2FCFF).withOpacity(.95),
        const Color(0xFF4AD8FF).withOpacity(.55),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: 20 + (active ? 7 : 2)));
    canvas.drawCircle(c, 20 + (active ? 7 : 2), coreGlow);
    canvas.drawCircle(c, 4.2 + (speaking ? 2 : 0), Paint()..color = const Color(0xFFE9FDFF));

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF82F2FF).withOpacity(.5);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.09), angle, math.pi * .43, false, arcPaint);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.09), angle + math.pi * 1.12, math.pi * .16, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _NeuralOrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active || oldDelegate.speaking != speaking;
}
