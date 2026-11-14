import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

class TileDefinition {
  const TileDefinition({
    required this.id,
    this.surface = 'grass',
    this.collidable = false,
    this.slippery = false,
    this.fenceGate = false,
    this.mossTarget = false,
    this.climbableMoss = false,
    this.canopy = false,
    this.occlusion = false,
    this.lantern = false,
    this.lowGravity = false,
  });

  final int id; // 0-based tileset index (GID - firstGid)
  final String surface;
  final bool collidable;
  final bool slippery;
  final bool fenceGate;
  final bool mossTarget;
  final bool climbableMoss;
  final bool canopy;
  final bool occlusion;
  final bool lantern;
  final bool lowGravity;
}

class MapObjectZone {
  const MapObjectZone({
    required this.id,
    required this.name,
    required this.type,
    required this.rect,
  });

  final int id;
  final String name;
  final String type;
  final Rect rect;
}

class OrchardMapData {
  OrchardMapData({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.firstGid,
    required this.tilesetColumns,
    required this.tileDefs,
    required this.groundGids,
    required this.decorGids,
    required this.canopyGids,
    required this.objects,
  }) : _originalGroundGids = List<int>.from(groundGids, growable: false);

  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final int firstGid;
  final int tilesetColumns;
  final Map<int, TileDefinition> tileDefs;
  final List<int> groundGids;
  final List<int> decorGids;
  final List<int> canopyGids;
  final List<MapObjectZone> objects;
  final List<int> _originalGroundGids;

  double get pixelWidth => (width * tileWidth).toDouble();
  double get pixelHeight => (height * tileHeight).toDouble();

  int originalGroundGidAt(int tx, int ty) {
    if (!inBounds(tx, ty)) return 0;
    return _originalGroundGids[ty * width + tx];
  }

  bool inBounds(int tx, int ty) =>
      tx >= 0 && ty >= 0 && tx < width && ty < height;

  int groundGidAt(int tx, int ty) =>
      inBounds(tx, ty) ? groundGids[ty * width + tx] : 0;

  int decorGidAt(int tx, int ty) =>
      inBounds(tx, ty) ? decorGids[ty * width + tx] : 0;

  int canopyGidAt(int tx, int ty) =>
      inBounds(tx, ty) ? canopyGids[ty * width + tx] : 0;

  TileDefinition? defForGid(int gid) {
    if (gid < firstGid) return null;
    return tileDefs[gid - firstGid];
  }

  bool isTileBlocked(int tx, int ty) {
    if (!inBounds(tx, ty)) return true;
    final dGid = decorGidAt(tx, ty);
    final dDef = defForGid(dGid);
    if (dDef != null) {
      if (dDef.climbableMoss) return false;
      if (dDef.collidable) return true;
    }
    final gDef = defForGid(groundGidAt(tx, ty));
    return gDef?.collidable ?? false;
  }

  bool isPointBlocked(double wx, double wy) {
    final tx = (wx / tileWidth).floor();
    final ty = (wy / tileHeight).floor();
    return isTileBlocked(tx, ty);
  }

  String surfaceAtWorld(double wx, double wy) {
    final tx = (wx / tileWidth).floor();
    final ty = (wy / tileHeight).floor();
    if (!inBounds(tx, ty)) return 'grass';
    final dDef = defForGid(decorGidAt(tx, ty));
    if (dDef != null && dDef.climbableMoss) {
      return dDef.surface;
    }
    final gDef = defForGid(groundGidAt(tx, ty));
    return gDef?.surface ?? 'grass';
  }

  bool isSlipperyAtWorld(double wx, double wy) {
    final tx = (wx / tileWidth).floor();
    final ty = (wy / tileHeight).floor();
    if (!inBounds(tx, ty)) return false;
    final gDef = defForGid(groundGidAt(tx, ty));
    return (gDef?.slippery ?? false) || gDef?.surface == 'mud';
  }

  bool isLowGravityAtWorld(double wx, double wy) {
    final tx = (wx / tileWidth).floor();
    final ty = (wy / tileHeight).floor();
    if (!inBounds(tx, ty)) return false;
    final gDef = defForGid(groundGidAt(tx, ty));
    return (gDef?.lowGravity ?? false) || gDef?.surface == 'crystal_floor';
  }

  bool isOccludedAtWorld(double wx, double wy) {
    final pt = Offset(wx, wy);
    for (final obj in objects) {
      if (obj.type == 'occlusion' && obj.rect.contains(pt)) {
        return true;
      }
    }
    final tx = (wx / tileWidth).floor();
    final ty = (wy / tileHeight).floor();
    if (!inBounds(tx, ty)) return false;
    final cDef = defForGid(canopyGidAt(tx, ty));
    if (cDef?.occlusion == true) return true;
    final gDef = defForGid(groundGidAt(tx, ty));
    return gDef?.occlusion ?? false;
  }

  String zoneNameAtWorld(double wx, double wy) {
    final pt = Offset(wx, wy);
    for (final obj in objects) {
      if (obj.type == 'zone' && obj.rect.contains(pt)) {
        return obj.name;
      }
    }
    return 'The Free Orchard';
  }

  List<MapObjectZone> get interactables =>
      objects.where((o) => o.type == 'interactable').toList(growable: false);

  List<MapObjectZone> get zones =>
      objects.where((o) => o.type == 'zone').toList(growable: false);
}

class TiledMapParser {
  const TiledMapParser._();

  static Map<int, TileDefinition> parseTsxXml(String tsxXmlString) {
    final doc = XmlDocument.parse(tsxXmlString);
    final defs = <int, TileDefinition>{};
    for (final tileEl in doc.findAllElements('tile')) {
      final id = int.tryParse(tileEl.getAttribute('id') ?? '') ?? 0;
      var surface = 'grass';
      var collidable = false;
      var slippery = false;
      var fenceGate = false;
      var mossTarget = false;
      var climbableMoss = false;
      var canopy = false;
      var occlusion = false;
      var lantern = false;
      var lowGravity = false;

      for (final prop in tileEl.findAllElements('property')) {
        final name = prop.getAttribute('name') ?? '';
        final val = prop.getAttribute('value') ?? '';
        final asBool = val == 'true' || val == '1';
        switch (name) {
          case 'surface':
            surface = val;
            break;
          case 'collidable':
            collidable = asBool;
            break;
          case 'slippery':
            slippery = asBool;
            break;
          case 'fence_gate':
            fenceGate = asBool;
            break;
          case 'moss_target':
            mossTarget = asBool;
            break;
          case 'climbable_moss':
            climbableMoss = asBool;
            break;
          case 'canopy':
            canopy = asBool;
            break;
          case 'occlusion':
            occlusion = asBool;
            break;
          case 'lantern':
            lantern = asBool;
            break;
          case 'low_gravity':
            lowGravity = asBool;
            break;
        }
      }

      defs[id] = TileDefinition(
        id: id,
        surface: surface,
        collidable: collidable,
        slippery: slippery,
        fenceGate: fenceGate,
        mossTarget: mossTarget,
        climbableMoss: climbableMoss,
        canopy: canopy,
        occlusion: occlusion,
        lantern: lantern,
        lowGravity: lowGravity,
      );
    }
    return defs;
  }

  static OrchardMapData parseTmxAndTsx({
    required String tmxXmlString,
    required String tsxXmlString,
  }) {
    final tsxDoc = XmlDocument.parse(tsxXmlString);
    final tilesetRoot = tsxDoc.findAllElements('tileset').first;
    final columns =
        int.tryParse(tilesetRoot.getAttribute('columns') ?? '') ?? 16;
    final tileDefs = parseTsxXml(tsxXmlString);

    final tmxDoc = XmlDocument.parse(tmxXmlString);
    final mapEl = tmxDoc.findAllElements('map').first;
    final width = int.parse(mapEl.getAttribute('width')!);
    final height = int.parse(mapEl.getAttribute('height')!);
    final tileW = int.tryParse(mapEl.getAttribute('tilewidth') ?? '') ?? 16;
    final tileH = int.tryParse(mapEl.getAttribute('tileheight') ?? '') ?? 16;

    final mapTilesetRef = mapEl.findElements('tileset').first;
    final firstGid =
        int.tryParse(mapTilesetRef.getAttribute('firstgid') ?? '') ?? 1;

    List<int> parseLayer(String name) {
      for (final layer in mapEl.findElements('layer')) {
        if (layer.getAttribute('name') == name) {
          final csv = layer.findElements('data').first.innerText;
          final nums = csv
              .split(RegExp(r'[,\s]+'))
              .where((s) => s.isNotEmpty)
              .map((s) => int.tryParse(s) ?? 0)
              .toList(growable: false);
          if (nums.length >= width * height) {
            return List<int>.from(nums.take(width * height));
          }
        }
      }
      return List<int>.filled(width * height, 0);
    }

    final objects = <MapObjectZone>[];
    for (final group in mapEl.findElements('objectgroup')) {
      for (final obj in group.findElements('object')) {
        final id = int.tryParse(obj.getAttribute('id') ?? '') ?? 0;
        final name = obj.getAttribute('name') ?? '';
        final type = obj.getAttribute('type') ?? '';
        final x = double.tryParse(obj.getAttribute('x') ?? '') ?? 0.0;
        final y = double.tryParse(obj.getAttribute('y') ?? '') ?? 0.0;
        final w = double.tryParse(obj.getAttribute('width') ?? '') ?? 16.0;
        final h = double.tryParse(obj.getAttribute('height') ?? '') ?? 16.0;
        objects.add(
          MapObjectZone(
            id: id,
            name: name,
            type: type,
            rect: Rect.fromLTWH(x, y, w, h),
          ),
        );
      }
    }

    return OrchardMapData(
      width: width,
      height: height,
      tileWidth: tileW,
      tileHeight: tileH,
      firstGid: firstGid,
      tilesetColumns: columns,
      tileDefs: tileDefs,
      groundGids: parseLayer('ground'),
      decorGids: parseLayer('decor'),
      canopyGids: parseLayer('canopy'),
      objects: objects,
    );
  }

  static Future<OrchardMapData> loadFromAssets({
    String tmxAsset = 'assets/tiles/free_orchard_full.tmx',
    String tsxAsset = 'assets/tiles/orchard_tileset.tsx',
    AssetBundle? bundle,
  }) async {
    final b = bundle ?? rootBundle;
    final res = await Future.wait([
      b.loadString(tmxAsset),
      b.loadString(tsxAsset),
    ]);
    return parseTmxAndTsx(tmxXmlString: res[0], tsxXmlString: res[1]);
  }
}
