import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerProfile extends Equatable {
  const PlayerProfile({
    this.ticketTorn = false,
    this.cultivarConfirmed = false,
    this.guestName = 'Sunny Kernel',
    this.cultivarId = 'chandler',
    this.equippedWardrobeId = 'tie_dye_tee',
    this.unlockedWardrobeIds = starterWardrobeIds,
    Set<String>? discoveredCultivarIds,
    this.savedX = 608.0,
    this.savedY = 1344.0,
    this.activeZoneName = 'Front Gate & Broken Fences',
  }) : discoveredCultivarIds = discoveredCultivarIds ?? const {'chandler'};

  static const Set<String> starterWardrobeIds = {
    'none',
    'moss_band',
    'tie_dye_tee',
    'fringe_vest',
    'flower_crown_poncho',
    'denim_rose_specs',
    'paisley_bandana_vest',
    'velvet_bellbottom_coat',
  };

  factory PlayerProfile.fromJson(
    Map<String, dynamic> json, {
    required int schemaVersion,
  }) {
    final rawUnlocked = json['unlockedWardrobeIds'] as List<dynamic>?;
    final unlocked = rawUnlocked == null
        ? starterWardrobeIds
        : {...starterWardrobeIds, ...rawUnlocked.map((e) => e.toString())};

    final activeCultivar = json['cultivarId'] as String? ?? 'chandler';
    final rawDiscovered = json['discoveredCultivarIds'] as List<dynamic>?;
    final discovered = <String>{
      activeCultivar,
      if (rawDiscovered != null) ...rawDiscovered.map((e) => e.toString()),
    };

    var x = (json['savedX'] as num?)?.toDouble() ??
        (schemaVersion < 2 ? 304.0 : 608.0);
    var y = (json['savedY'] as num?)?.toDouble() ??
        (schemaVersion < 2 ? 648.0 : 1344.0);

    // Lossless migration from v0.1.0 64x48 slice (1024x768) -> v1.0 128x96 9-zone farm (2048x1536)
    if (schemaVersion < 2) {
      x = (x + 304.0).clamp(64.0, 1984.0);
      y = (y + 696.0).clamp(64.0, 1472.0);
    } else {
      x = x.clamp(32.0, 2016.0);
      y = y.clamp(32.0, 1504.0);
    }

    return PlayerProfile(
      ticketTorn: json['ticketTorn'] as bool? ?? false,
      cultivarConfirmed: json['cultivarConfirmed'] as bool? ?? false,
      guestName: (json['guestName'] as String?)?.trim().isNotEmpty == true
          ? (json['guestName'] as String).trim()
          : 'Sunny Kernel',
      cultivarId: activeCultivar,
      equippedWardrobeId: json['equippedWardrobeId'] as String? ?? 'moss_band',
      unlockedWardrobeIds: unlocked,
      discoveredCultivarIds: discovered,
      savedX: x,
      savedY: y,
      activeZoneName:
          json['activeZoneName'] as String? ?? 'Front Gate & Broken Fences',
    );
  }

  final bool ticketTorn;
  final bool cultivarConfirmed;
  final String guestName;
  final String cultivarId;
  final String equippedWardrobeId;
  final Set<String> unlockedWardrobeIds;
  final Set<String> discoveredCultivarIds;
  final double savedX;
  final double savedY;
  final String activeZoneName;

  /// True when the player has walked past the Orchard Gate into the festival grounds.
  bool get hasActiveInOrchardPosition =>
      savedY < 1236.0 || (savedX - 608.0).abs() > 36.0;

  PlayerProfile copyWith({
    bool? ticketTorn,
    bool? cultivarConfirmed,
    String? guestName,
    String? cultivarId,
    String? equippedWardrobeId,
    Set<String>? unlockedWardrobeIds,
    Set<String>? discoveredCultivarIds,
    double? savedX,
    double? savedY,
    String? activeZoneName,
  }) {
    final nextCultivar = cultivarId ?? this.cultivarId;
    final nextDiscovered = <String>{
      ...(discoveredCultivarIds ?? this.discoveredCultivarIds),
      nextCultivar,
    };
    return PlayerProfile(
      ticketTorn: ticketTorn ?? this.ticketTorn,
      cultivarConfirmed: cultivarConfirmed ?? this.cultivarConfirmed,
      guestName: guestName ?? this.guestName,
      cultivarId: nextCultivar,
      equippedWardrobeId: equippedWardrobeId ?? this.equippedWardrobeId,
      unlockedWardrobeIds: unlockedWardrobeIds ?? this.unlockedWardrobeIds,
      discoveredCultivarIds: nextDiscovered,
      savedX: savedX ?? this.savedX,
      savedY: savedY ?? this.savedY,
      activeZoneName: activeZoneName ?? this.activeZoneName,
    );
  }

  Map<String, dynamic> toJson() => {
        'ticketTorn': ticketTorn,
        'cultivarConfirmed': cultivarConfirmed,
        'guestName': guestName,
        'cultivarId': cultivarId,
        'equippedWardrobeId': equippedWardrobeId,
        'unlockedWardrobeIds': unlockedWardrobeIds.toList()..sort(),
        'discoveredCultivarIds': discoveredCultivarIds.toList()..sort(),
        'savedX': savedX,
        'savedY': savedY,
        'activeZoneName': activeZoneName,
      };

  @override
  List<Object?> get props => [
        ticketTorn,
        cultivarConfirmed,
        guestName,
        cultivarId,
        equippedWardrobeId,
        unlockedWardrobeIds,
        discoveredCultivarIds,
        savedX,
        savedY,
        activeZoneName,
      ];
}

class PlayerProfileNotifier extends StateNotifier<PlayerProfile> {
  PlayerProfileNotifier() : super(const PlayerProfile());

  void hydrate(PlayerProfile profile) => state = profile;

  void tearTicket() {
    state = state.copyWith(ticketTorn: true);
  }

  void selectCultivar(String id) {
    state = state.copyWith(
      cultivarId: id,
      discoveredCultivarIds: {...state.discoveredCultivarIds, id},
    );
  }

  /// Marks a heritage walnut cultivar as discovered. Returns `true` if newly added.
  bool discoverCultivar(String id) {
    if (state.discoveredCultivarIds.contains(id)) return false;
    state = state.copyWith(
      discoveredCultivarIds: {...state.discoveredCultivarIds, id},
    );
    return true;
  }

  void setGuestName(String name) {
    final cleaned = name.trim();
    state = state.copyWith(
      guestName: cleaned.isEmpty ? 'Sunny Kernel' : cleaned,
    );
  }

  void confirmCultivarAndEnter() {
    state = state.copyWith(ticketTorn: true, cultivarConfirmed: true);
  }

  void unlockWardrobe(String itemId, {bool autoEquip = true}) {
    final updated = {...state.unlockedWardrobeIds, itemId};
    state = state.copyWith(
      unlockedWardrobeIds: updated,
      equippedWardrobeId: autoEquip ? itemId : state.equippedWardrobeId,
    );
  }

  void equipWardrobe(String itemId) {
    if (!state.unlockedWardrobeIds.contains(itemId)) return;
    state = state.copyWith(equippedWardrobeId: itemId);
  }

  void updatePosition(double x, double y, {String? zoneName}) {
    state = state.copyWith(
      savedX: x,
      savedY: y,
      activeZoneName: zoneName ?? state.activeZoneName,
    );
  }
}
