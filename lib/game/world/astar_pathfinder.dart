import 'dart:collection';
import 'dart:math' as math;
import 'tiled_map_parser.dart';

class GridPoint {
  const GridPoint(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class AStarPathfinder {
  const AStarPathfinder(this.map);

  final OrchardMapData map;

  /// Computes a tile-grid path in world coordinates; when `avoidAsphalt == true`,
  /// Barnaby Breeze-Walker strictly routes around every `asphalt` tile!
  List<(double, double)> findWorldPath({
    required double startX,
    required double startY,
    required double goalX,
    required double goalY,
    bool avoidAsphalt = false,
    int maxExpandedNodes = 2400,
  }) {
    final sx = (startX / map.tileWidth).floor().clamp(0, map.width - 1);
    final sy = (startY / map.tileHeight).floor().clamp(0, map.height - 1);
    var gx = (goalX / map.tileWidth).floor().clamp(0, map.width - 1);
    var gy = (goalY / map.tileHeight).floor().clamp(0, map.height - 1);

    if (!_isWalkable(gx, gy, avoidAsphalt: avoidAsphalt)) {
      final fallback = _nearestWalkable(gx, gy, avoidAsphalt: avoidAsphalt);
      if (fallback == null) return const [];
      gx = fallback.x;
      gy = fallback.y;
    }

    final start = GridPoint(sx, sy);
    final goal = GridPoint(gx, gy);
    if (start == goal) {
      return [(_tileCenterX(gx), _tileCenterY(gy))];
    }

    final open = SplayTreeSet<_Node>((a, b) {
      final c = a.f.compareTo(b.f);
      if (c != 0) return c;
      final cx = a.pt.x.compareTo(b.pt.x);
      if (cx != 0) return cx;
      return a.pt.y.compareTo(b.pt.y);
    });
    final gScore = <GridPoint, double>{start: 0.0};
    final cameFrom = <GridPoint, GridPoint>{};
    final nodeLookup = <GridPoint, _Node>{};

    final startNode = _Node(start, _heuristic(start, goal));
    open.add(startNode);
    nodeLookup[start] = startNode;

    var expanded = 0;
    const dirs = <(int, int, double)>[
      (1, 0, 1.0),
      (-1, 0, 1.0),
      (0, 1, 1.0),
      (0, -1, 1.0),
      (1, 1, 1.4142),
      (-1, 1, 1.4142),
      (1, -1, 1.4142),
      (-1, -1, 1.4142),
    ];

    while (open.isNotEmpty && expanded < maxExpandedNodes) {
      final current = open.first;
      open.remove(current);
      nodeLookup.remove(current.pt);
      expanded++;

      if (current.pt == goal) {
        return _reconstruct(cameFrom, current.pt);
      }

      final curG = gScore[current.pt]!;
      for (final (dx, dy, stepCost) in dirs) {
        final nx = current.pt.x + dx;
        final ny = current.pt.y + dy;
        if (!_isWalkable(nx, ny, avoidAsphalt: avoidAsphalt)) continue;
        // Prevent diagonal corner-clipping through solid walls
        if (dx != 0 && dy != 0) {
          if (!_isWalkable(current.pt.x + dx, current.pt.y,
                  avoidAsphalt: avoidAsphalt) ||
              !_isWalkable(current.pt.x, current.pt.y + dy,
                  avoidAsphalt: avoidAsphalt)) {
            continue;
          }
        }

        final neighbor = GridPoint(nx, ny);
        final tentativeG = curG + stepCost;
        final prevG = gScore[neighbor];
        if (prevG == null || tentativeG < prevG) {
          cameFrom[neighbor] = current.pt;
          gScore[neighbor] = tentativeG;
          final f = tentativeG + _heuristic(neighbor, goal);
          final oldNode = nodeLookup[neighbor];
          if (oldNode != null) {
            open.remove(oldNode);
          }
          final nextNode = _Node(neighbor, f);
          open.add(nextNode);
          nodeLookup[neighbor] = nextNode;
        }
      }
    }

    return const [];
  }

  bool _isWalkable(int tx, int ty, {required bool avoidAsphalt}) {
    if (map.isTileBlocked(tx, ty)) return false;
    if (avoidAsphalt) {
      final wx = _tileCenterX(tx);
      final wy = _tileCenterY(ty);
      if (map.surfaceAtWorld(wx, wy) == 'asphalt') {
        return false;
      }
    }
    return true;
  }

  GridPoint? _nearestWalkable(int tx, int ty, {required bool avoidAsphalt}) {
    for (var r = 1; r <= 5; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          final nx = tx + dx;
          final ny = ty + dy;
          if (_isWalkable(nx, ny, avoidAsphalt: avoidAsphalt)) {
            return GridPoint(nx, ny);
          }
        }
      }
    }
    return null;
  }

  double _heuristic(GridPoint a, GridPoint b) {
    final dx = (a.x - b.x).abs().toDouble();
    final dy = (a.y - b.y).abs().toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  List<(double, double)> _reconstruct(
    Map<GridPoint, GridPoint> cameFrom,
    GridPoint current,
  ) {
    final pts = <(double, double)>[];
    GridPoint? cursor = current;
    while (cursor != null) {
      pts.add((_tileCenterX(cursor.x), _tileCenterY(cursor.y)));
      cursor = cameFrom[cursor];
    }
    final reversed = pts.reversed.toList(growable: false);
    return reversed.length > 1 ? reversed.sublist(1) : reversed;
  }

  double _tileCenterX(int tx) => (tx + 0.5) * map.tileWidth;
  double _tileCenterY(int ty) => (ty + 0.5) * map.tileHeight;
}

class _Node {
  const _Node(this.pt, this.f);
  final GridPoint pt;
  final double f;
}
