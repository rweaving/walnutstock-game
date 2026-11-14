import 'tiled_map_parser.dart';

class WorldMutators {
  WorldMutators(this.map);

  final OrchardMapData map;

  bool _fencesApplied = false;
  bool _mossApplied = false;
  bool _mossEnhancedApplied = false;
  bool? _mudApplied;

  /// Topples Front Gate wooden fences (`fence_gate=true` -> open planks `id 9`).
  bool applyFenceDrop() {
    if (_fencesApplied) return false;
    final openFenceGid = map.firstGid + 9;
    var mutated = false;
    for (var i = 0; i < map.decorGids.length; i++) {
      final def = map.defForGid(map.decorGids[i]);
      if (def != null && def.fenceGate) {
        map.decorGids[i] = openFenceGid;
        mutated = true;
      }
    }
    _fencesApplied = true;
    return mutated;
  }

  /// Blooms emerald bark-moss shortcut (`moss_target=true` -> `climbable_moss` `id 26`).
  /// When [enhancedByTea] is true (Janice Joeplant's Aged-Grapevine Vocal Tea quest completed),
  /// widens the climbable emerald moss terrace across columns `11..15` (`y: 14..16`).
  bool applyMossBloom({bool enhancedByTea = false}) {
    if (_mossApplied && (!enhancedByTea || _mossEnhancedApplied)) {
      return false;
    }
    final bloomedMossGid = map.firstGid + 26;
    var mutated = false;

    if (!_mossApplied) {
      for (var i = 0; i < map.decorGids.length; i++) {
        final def = map.defForGid(map.decorGids[i]);
        if (def != null && def.mossTarget) {
          map.decorGids[i] = bloomedMossGid;
          mutated = true;
        }
      }
      _mossApplied = true;
    }

    if (enhancedByTea && !_mossEnhancedApplied) {
      for (var ty = 14; ty <= 16; ty++) {
        for (final tx in [11, 15]) {
          if (tx >= 0 && tx < map.width && ty >= 0 && ty < map.height) {
            final idx = ty * map.width + tx;
            if (map.decorGids[idx] != bloomedMossGid) {
              map.decorGids[idx] = bloomedMossGid;
              mutated = true;
            }
          }
        }
      }
      _mossEnhancedApplied = true;
    }

    return mutated;
  }

  /// Dynamically converts `dirt` lanes AND the Velvet-to-Main-Roots Woodstock Mud-Slide Meadow
  /// into slippery `mud` during & after the festival rainstorms, restoring cleanly when dry!
  bool syncRainstormMud(bool shouldBeMuddy) {
    if (_mudApplied == shouldBeMuddy) return false;
    final mudGid = map.firstGid + 4;
    var mutated = false;

    for (var ty = 0; ty < map.height; ty++) {
      for (var tx = 0; tx < map.width; tx++) {
        final idx = ty * map.width + tx;
        final origGid = map.originalGroundGidAt(tx, ty);
        final origDef = map.defForGid(origGid);
        final isDirtLane = origDef?.surface == 'dirt';
        final isMudMeadowLawn = origDef?.surface == 'grass' &&
            map.decorGidAt(tx, ty) == 0 &&
            _isInsideMudSlideMeadow(tx, ty);

        if (isDirtLane || isMudMeadowLawn) {
          final targetGid = shouldBeMuddy ? mudGid : origGid;
          if (map.groundGids[idx] != targetGid) {
            map.groundGids[idx] = targetGid;
            mutated = true;
          }
        }
      }
    }

    _mudApplied = shouldBeMuddy;
    return mutated;
  }

  /// Organic Woodstock Mud-Slide & Mud-Fight bowls south of Velvet Canopy & Main Roots Stages.
  static bool _isInsideMudSlideMeadow(int tx, int ty) {
    if (ty < 33 || ty > 42 || tx < 12 || tx > 44) return false;
    // Bowl A: Velvet Canopy South Mud Pit (right where Set 8 wraps up!)
    final dxA = (tx - 18.0) / 6.4;
    final dyA = (ty - 36.8) / 3.5;
    if (dxA * dxA + dyA * dyA <= 1.0) return true;

    // Bowl B: Main Roots Festival Mud Bowl (connecting east along the boulevard!)
    final dxB = (tx - 33.5) / 9.8;
    final dyB = (ty - 38.0) / 3.4;
    return (dxB * dxB + dyB * dyB) <= 1.0;
  }
}
