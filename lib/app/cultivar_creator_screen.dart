import 'dart:math' as math;
import 'dart:ui' as ui;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/soloud_audio_service.dart';
import '../data/models.dart';
import '../game/actors/wardrobe_outfit_renderer.dart';
import '../state/providers.dart';

class CultivarCreatorScreen extends ConsumerStatefulWidget {
  const CultivarCreatorScreen({
    super.key,
    this.audioService,
  });

  final SoloudAudioService? audioService;

  @override
  ConsumerState<CultivarCreatorScreen> createState() =>
      _CultivarCreatorScreenState();
}

class _CultivarCreatorScreenState extends ConsumerState<CultivarCreatorScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  Ticker? _previewTicker;
  double _animClock = 0.0;
  int _previewFacingRow = 0; // 0=front, 1=left, 2=right, 3=back
  late bool _previewGrooving;

  String? _resolvedSheetPath;
  ImageStream? _sheetStream;
  ImageStreamListener? _sheetListener;
  ui.Image? _sheetImage;

  static const List<String> _randomFestivalNames = [
    'Sunny Kernel',
    'Cosmic Cascara',
    'Clover Shellshine',
    'Ziggy Butternut',
    'Ruby Livermore',
    'Velvet Sprout',
    'Groovy Heartnut',
    'Breezy Franquette',
  ];

  bool get _isAutomatedTestBinding =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(playerProfileProvider).guestName,
    );
    _previewGrooving = !_isAutomatedTestBinding;
    _previewTicker = createTicker((elapsed) {
      if (!mounted || !_previewGrooving) return;
      setState(() {
        _animClock = elapsed.inMicroseconds / 1000000.0;
      });
    });
    if (_previewGrooving) {
      _previewTicker!.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPreviewSheet();
  }

  void _syncPreviewSheet() {
    final data = ref.read(festivalDataProvider);
    final cultivarId = ref.read(playerProfileProvider).cultivarId;
    final spec = data.cultivars.firstWhere(
      (c) => c.id == cultivarId,
      orElse: () => data.cultivars.first,
    );
    if (_resolvedSheetPath == spec.sheetAsset) return;
    _unsubscribeSheet();
    _resolvedSheetPath = spec.sheetAsset;

    final stream =
        AssetImage(spec.sheetAsset).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _sheetImage = info.image;
        });
      },
      onError: (_, __) {},
    );
    _sheetStream = stream;
    _sheetListener = listener;
    stream.addListener(listener);
  }

  void _unsubscribeSheet() {
    if (_sheetStream != null && _sheetListener != null) {
      _sheetStream!.removeListener(_sheetListener!);
    }
    _sheetStream = null;
    _sheetListener = null;
  }

  void _togglePreviewGroove() {
    setState(() {
      _previewGrooving = !_previewGrooving;
      if (_previewGrooving) {
        if (!(_previewTicker?.isActive ?? false)) {
          _previewTicker?.start();
        }
      } else {
        _previewTicker?.stop();
      }
      _animClock += 0.35;
    });
  }

  void _rotatePreview(int delta) {
    const order = [0, 1, 3, 2];
    final curIdx = order.indexOf(_previewFacingRow);
    final nextIdx = ((curIdx + delta) % order.length + order.length) % order.length;
    setState(() {
      _previewFacingRow = order[nextIdx];
      _animClock += 0.25;
    });
  }

  void _randomizeCharacter(
    List<CultivarSpec> cultivars,
    List<WardrobeItemSpec> starterOutfits,
  ) {
    final rng = math.Random();
    final pickedCultivar = cultivars[rng.nextInt(cultivars.length)];
    final pickedOutfit = starterOutfits[rng.nextInt(starterOutfits.length)];
    final pickedName =
        _randomFestivalNames[rng.nextInt(_randomFestivalNames.length)];

    _nameController.text = pickedName;
    final notifier = ref.read(playerProfileProvider.notifier);
    notifier.setGuestName(pickedName);
    notifier.selectCultivar(pickedCultivar.id);
    notifier.unlockWardrobe(pickedOutfit.id, autoEquip: true);
    setState(() {
      _animClock += 0.42;
    });
  }

  @override
  void dispose() {
    _unsubscribeSheet();
    _previewTicker?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  static Color _parseHexColor(String hexStr) {
    final cleaned = hexStr.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final v = int.tryParse('FF$cleaned', radix: 16);
      if (v != null) return Color(v);
    }
    return const Color(0xFFFFD166);
  }

  static (Color, IconData) _outfitVisualMeta(String id) => switch (id) {
        'none' => (const Color(0xFFD4A373), Icons.spa_outlined),
        'moss_band' => (const Color(0xFF52B788), Icons.eco_rounded),
        'tie_dye_tee' => (const Color(0xFFFF595E), Icons.palette_rounded),
        'fringe_vest' => (const Color(0xFFC68B59), Icons.style_rounded),
        'flower_crown_poncho' => (
            const Color(0xFFFFBE0B),
            Icons.local_florist_rounded
          ),
        'denim_rose_specs' => (
            const Color(0xFF3A86FF),
            Icons.visibility_rounded
          ),
        'paisley_bandana_vest' => (
            const Color(0xFFE63946),
            Icons.auto_awesome_rounded
          ),
        'velvet_bellbottom_coat' => (
            const Color(0xFF9D4EDD),
            Icons.diamond_rounded
          ),
        _ => (const Color(0xFFFFD166), Icons.checkroom_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(festivalDataProvider);
    final profile = ref.watch(playerProfileProvider);
    _syncPreviewSheet();

    final selectedSpec = data.cultivars.firstWhere(
      (c) => c.id == profile.cultivarId,
      orElse: () => data.cultivars.first,
    );
    final starterOutfits = data.wardrobe
        .where((w) => w.unlockedByDefault)
        .toList(growable: false);
    final selectedOutfit = data.wardrobe.firstWhere(
      (w) => w.id == profile.equippedWardrobeId,
      orElse: () => starterOutfits.first,
    );
    final cultivarAccent = _parseHexColor(selectedSpec.accentHex);

    final size = MediaQuery.sizeOf(context);
    final isWideStudio = size.width >= 740 && size.height >= 500;
    final isTallMobileStudio = !isWideStudio && size.height >= 500;
    final isCompactMobile = size.width < 520;

    Widget buildStudioCard({
      required bool boundedWide,
      required bool boundedPortrait,
    }) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          isCompactMobile ? 13 : 18,
          isCompactMobile ? 10 : 12,
          isCompactMobile ? 13 : 18,
          isCompactMobile ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF281B12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD49A5A),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: (boundedWide || boundedPortrait)
                ? MainAxisSize.max
                : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Studio Top Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WALNUT CHARACTER & OUTFIT STUDIO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFFFD166),
                            fontSize: isCompactMobile ? 14.5 : 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isCompactMobile ? 0.6 : 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose from 11 distinct walnut varieties & 8 1969 festival outfits before entering the grove',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFD9C398),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('randomize_walnut_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD166),
                      side: const BorderSide(color: Color(0xFFB08968)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        _randomizeCharacter(data.cultivars, starterOutfits),
                    icon: const Icon(Icons.casino_outlined, size: 15),
                    label: const Text(
                      'Randomize',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (boundedWide)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 292,
                        child: SingleChildScrollView(
                          child: _buildLeftPreviewAndProfileColumn(
                            selectedSpec: selectedSpec,
                            selectedOutfit: selectedOutfit,
                            cultivarAccent: cultivarAccent,
                            equippedWardrobeId: profile.equippedWardrobeId,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildRightPickersSection(
                                  cultivars: data.cultivars,
                                  starterOutfits: starterOutfits,
                                  selectedCultivarId: profile.cultivarId,
                                  selectedOutfit: selectedOutfit,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildSelectedOutfitAndEnterSection(
                              selectedOutfit: selectedOutfit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (boundedPortrait)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLeftPreviewAndProfileColumn(
                                selectedSpec: selectedSpec,
                                selectedOutfit: selectedOutfit,
                                cultivarAccent: cultivarAccent,
                                equippedWardrobeId: profile.equippedWardrobeId,
                              ),
                              const SizedBox(height: 12),
                              _buildRightPickersSection(
                                cultivars: data.cultivars,
                                starterOutfits: starterOutfits,
                                selectedCultivarId: profile.cultivarId,
                                selectedOutfit: selectedOutfit,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSelectedOutfitAndEnterSection(
                        selectedOutfit: selectedOutfit,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftPreviewAndProfileColumn(
                      selectedSpec: selectedSpec,
                      selectedOutfit: selectedOutfit,
                      cultivarAccent: cultivarAccent,
                      equippedWardrobeId: profile.equippedWardrobeId,
                    ),
                    const SizedBox(height: 12),
                    _buildRightPickersSection(
                      cultivars: data.cultivars,
                      starterOutfits: starterOutfits,
                      selectedCultivarId: profile.cultivarId,
                      selectedOutfit: selectedOutfit,
                    ),
                    const SizedBox(height: 10),
                    _buildSelectedOutfitAndEnterSection(
                      selectedOutfit: selectedOutfit,
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF19110B),
      body: SafeArea(
        child: Center(
          child: isWideStudio
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 920,
                      maxHeight: math.min(680.0, size.height - 20.0),
                    ),
                    child: buildStudioCard(
                      boundedWide: true,
                      boundedPortrait: false,
                    ),
                  ),
                )
              : isTallMobileStudio
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactMobile ? 10 : 14,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 920,
                          maxHeight: size.height - 16.0,
                        ),
                        child: buildStudioCard(
                          boundedWide: false,
                          boundedPortrait: true,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactMobile ? 10 : 14,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: buildStudioCard(
                          boundedWide: false,
                          boundedPortrait: false,
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLeftPreviewAndProfileColumn({
    required CultivarSpec selectedSpec,
    required WardrobeItemSpec selectedOutfit,
    required Color cultivarAccent,
    required String equippedWardrobeId,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Stage Sprite + Outfit Preview Box
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 0.95,
              colors: [
                cultivarAccent.withValues(alpha: 0.25),
                const Color(0xFF160F0A),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cultivarAccent.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B1E14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedSpec.shellShape,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cultivarAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    key: const ValueKey('preview_groove_button'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: _togglePreviewGroove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _previewGrooving
                            ? const Color(0xFF52B788)
                            : const Color(0xFF3A281B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _previewGrooving ? '💃 Grooving' : '💃 Test Dance',
                        style: TextStyle(
                          color: _previewGrooving
                              ? const Color(0xFF092216)
                              : const Color(0xFFFFD166),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 112,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const ValueKey('rotate_walnut_left_button'),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Turn Left',
                      onPressed: () => _rotatePreview(-1),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFFFFD166),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _sheetImage != null
                            ? CustomPaint(
                                size: const Size(112, 112),
                                painter: _LiveWalnutOutfitPainter(
                                  sheet: _sheetImage!,
                                  wardrobeId: equippedWardrobeId,
                                  facingRow: _previewFacingRow,
                                  animClock: _animClock,
                                  grooving: _previewGrooving,
                                  accentColor: cultivarAccent,
                                ),
                              )
                            : Image.asset(
                                selectedSpec.portraitAsset,
                                width: 84,
                                height: 84,
                                filterQuality: FilterQuality.none,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('rotate_walnut_right_button'),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Turn Right',
                      onPressed: () => _rotatePreview(1),
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFFFD166),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Detailed Botanical Cultivar Inspector Card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1D130C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5C3D28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF120B07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: cultivarAccent),
                    ),
                    child: Image.asset(
                      selectedSpec.portraitAsset,
                      filterQuality: FilterQuality.none,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedSpec.name,
                          style: const TextStyle(
                            color: Color(0xFFF4E3C1),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Origin: ${selectedSpec.origin}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cultivarAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedSpec.tagline,
                style: const TextStyle(
                  color: Color(0xFFD9C398),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '🌰 Tasting Notes: ${selectedSpec.flavorNotes}',
                style: const TextStyle(
                  color: Color(0xFF95D5B2),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Guest Name Field
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Color(0xFFF4E3C1), fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            labelText: 'Festival Wristband Guest Name',
            labelStyle: const TextStyle(
              color: Color(0xFFD49A5A),
              fontSize: 12,
            ),
            filled: true,
            fillColor: const Color(0xFF17100A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (v) =>
              ref.read(playerProfileProvider.notifier).setGuestName(v),
        ),
      ],
    );
  }

  Widget _buildRightPickersSection({
    required List<CultivarSpec> cultivars,
    required List<WardrobeItemSpec> starterOutfits,
    required String selectedCultivarId,
    required WardrobeItemSpec selectedOutfit,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Walnut Variety Picker (11 Distinct Cultivars)
        const Text(
          '1. PICK YOUR WALNUT VARIETY (11 DISTINCT SHELLS)',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cultivars)
              _CultivarVisualChip(
                chipKey: ValueKey('cultivar_chip_${c.id}'),
                spec: c,
                selected: c.id == selectedCultivarId,
                accent: _parseHexColor(c.accentHex),
                onTap: () {
                  ref.read(playerProfileProvider.notifier).selectCultivar(c.id);
                  setState(() {
                    _animClock += 0.25;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Starter Festival Outfit Picker (8 Unlocked Outfits)
        const Text(
          '2. PICK YOUR FESTIVAL OUTFIT (8 STARTER LOOKS + 8 QUEST UNLOCKS)',
          style: TextStyle(
            color: Color(0xFF95D5B2),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in starterOutfits)
              _OutfitVisualChip(
                chipKey: ValueKey('outfit_chip_${w.id}'),
                item: w,
                selected: w.id == selectedOutfit.id,
                visual: _outfitVisualMeta(w.id),
                onTap: () {
                  ref
                      .read(playerProfileProvider.notifier)
                      .unlockWardrobe(w.id, autoEquip: true);
                  setState(() {
                    _animClock += 0.25;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedOutfitAndEnterSection({
    required WardrobeItemSpec selectedOutfit,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1D130C),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF5C3D28)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.checkroom_rounded,
                size: 15,
                color: Color(0xFFFFD166),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${selectedOutfit.name}: ${selectedOutfit.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE9D8B8),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Enter Free Orchard CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('enter_orchard_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52B788),
              foregroundColor: const Color(0xFF0D2419),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await widget.audioService?.unlockAndInitialize();
              ref
                  .read(playerProfileProvider.notifier)
                  .setGuestName(_nameController.text);
              ref
                  .read(playerProfileProvider.notifier)
                  .confirmCultivarAndEnter();
              await persistCurrentGameState(ref);
            },
            icon: const Icon(Icons.park_outlined),
            label: const Text(
              'STEP INTO THE FREE ORCHARD',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CultivarVisualChip extends StatelessWidget {
  const _CultivarVisualChip({
    required this.chipKey,
    required this.spec,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Key chipKey;
  final CultivarSpec spec;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFD49A5A) : const Color(0xFF352418),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? const Color(0xFFFFF8E7) : accent.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                spec.portraitAsset,
                width: 20,
                height: 20,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  spec.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1C140D)
                        : const Color(0xFFF4E3C1),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutfitVisualChip extends StatelessWidget {
  const _OutfitVisualChip({
    required this.chipKey,
    required this.item,
    required this.selected,
    required this.visual,
    required this.onTap,
  });

  final Key chipKey;
  final WardrobeItemSpec item;
  final bool selected;
  final (Color, IconData) visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (swatch, icon) = visual;
    return Material(
      color: selected ? const Color(0xFF52B788) : const Color(0xFF352418),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? const Color(0xFFE9F5DB) : swatch.withValues(alpha: 0.7),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: swatch.withValues(alpha: selected ? 0.95 : 0.25),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  icon,
                  size: 11,
                  color: selected ? const Color(0xFF140C07) : swatch,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF081C15)
                        : const Color(0xFFF4E3C1),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveWalnutOutfitPainter extends CustomPainter {
  const _LiveWalnutOutfitPainter({
    required this.sheet,
    required this.wardrobeId,
    required this.facingRow,
    required this.animClock,
    required this.grooving,
    required this.accentColor,
  });

  final ui.Image sheet;
  final String wardrobeId;
  final int facingRow;
  final double animClock;
  final bool grooving;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const scale = 3.2;
    final ox = (size.width - 32.0 * scale) * 0.5;
    final oy = (size.height - 32.0 * scale) * 0.5 + 3.0;

    final beatFloat = animClock * (116.0 / 60.0);
    final beatIdx = beatFloat.floor();
    final beatPhase = beatFloat - beatIdx;
    final beatPulse = grooving ? math.pow(1.0 - beatPhase, 2.2).toDouble() : 0.0;

    // Mini Woodstock wooden stage deck & pulsing spotlight ring
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height - 12),
        width: 82 + beatPulse * 10,
        height: 18 + beatPulse * 3,
      ),
      Paint()..color = const Color(0xFF3E2718),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height - 13),
        width: 72 + beatPulse * 12,
        height: 13 + beatPulse * 3,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accentColor.withValues(alpha: grooving ? 0.85 : 0.45),
    );

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(scale, scale);

    final bounceY = grooving ? beatPulse * 2.4 : 0.0;
    final swayX =
        grooving ? math.sin(beatFloat * math.pi * 0.5) * 1.8 : 0.0;
    final frameCol = grooving ? const [1, 0, 2, 0][beatIdx % 4] : 0;

    final src = Rect.fromLTWH(
      frameCol * 32.0,
      facingRow * 32.0,
      32.0,
      32.0,
    );
    final dst = Rect.fromLTWH(swayX, -bounceY, 32.0, 32.0);
    canvas.drawImageRect(
      sheet,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );

    renderWalnutWardrobeOutfit(
      canvas,
      wardrobeId: wardrobeId,
      facingRow: facingRow,
      offsetX: swayX,
      liftY: bounceY,
      animClock: animClock,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveWalnutOutfitPainter oldDelegate) {
    return oldDelegate.sheet != sheet ||
        oldDelegate.wardrobeId != wardrobeId ||
        oldDelegate.facingRow != facingRow ||
        oldDelegate.animClock != animClock ||
        oldDelegate.grooving != grooving ||
        oldDelegate.accentColor != accentColor;
  }
}
