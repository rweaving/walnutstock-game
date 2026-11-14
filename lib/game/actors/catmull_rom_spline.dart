import 'dart:ui';

/// Closed C1-continuous Catmull-Rom spline for Ziggy Shell-shock's curved meadow routine.
class CatmullRomSpline2D {
  const CatmullRomSpline2D(this.controlPoints);

  final List<Offset> controlPoints;

  /// Evaluates closed spline at normalized parameter `t` in `[0, 1)`.
  Offset evaluate(double t) {
    final n = controlPoints.length;
    if (n == 0) return Offset.zero;
    if (n == 1) return controlPoints.first;

    final wrapped = (t % 1.0 + 1.0) % 1.0;
    final scaled = wrapped * n;
    final seg = scaled.floor() % n;
    final u = scaled - scaled.floor();

    final p0 = controlPoints[(seg - 1 + n) % n];
    final p1 = controlPoints[seg];
    final p2 = controlPoints[(seg + 1) % n];
    final p3 = controlPoints[(seg + 2) % n];

    final u2 = u * u;
    final u3 = u2 * u;

    final x = 0.5 *
        ((2.0 * p1.dx) +
            (-p0.dx + p2.dx) * u +
            (2.0 * p0.dx - 5.0 * p1.dx + 4.0 * p2.dx - p3.dx) * u2 +
            (-p0.dx + 3.0 * p1.dx - 3.0 * p2.dx + p3.dx) * u3);
    final y = 0.5 *
        ((2.0 * p1.dy) +
            (-p0.dy + p2.dy) * u +
            (2.0 * p0.dy - 5.0 * p1.dy + 4.0 * p2.dy - p3.dy) * u2 +
            (-p0.dy + 3.0 * p1.dy - 3.0 * p2.dy + p3.dy) * u3);
    return Offset(x, y);
  }

  /// Analytic first derivative dP/dt for C1 continuity verification & facing direction.
  Offset tangent(double t) {
    final n = controlPoints.length;
    if (n < 2) return const Offset(1, 0);

    final wrapped = (t % 1.0 + 1.0) % 1.0;
    final scaled = wrapped * n;
    final seg = scaled.floor() % n;
    final u = scaled - scaled.floor();

    final p0 = controlPoints[(seg - 1 + n) % n];
    final p1 = controlPoints[seg];
    final p2 = controlPoints[(seg + 1) % n];
    final p3 = controlPoints[(seg + 2) % n];

    final u2 = u * u;
    final dx = 0.5 *
        ((-p0.dx + p2.dx) +
            2.0 * (2.0 * p0.dx - 5.0 * p1.dx + 4.0 * p2.dx - p3.dx) * u +
            3.0 * (-p0.dx + 3.0 * p1.dx - 3.0 * p2.dx + p3.dx) * u2) *
        n;
    final dy = 0.5 *
        ((-p0.dy + p2.dy) +
            2.0 * (2.0 * p0.dy - 5.0 * p1.dy + 4.0 * p2.dy - p3.dy) * u +
            3.0 * (-p0.dy + 3.0 * p1.dy - 3.0 * p2.dy + p3.dy) * u2) *
        n;
    return Offset(dx, dy);
  }
}
