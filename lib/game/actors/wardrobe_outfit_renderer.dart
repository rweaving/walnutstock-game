import 'dart:math' as math;
import 'dart:ui';

/// Shared pixel-crisp 1969 Woodstock outfit renderer used both in the live
/// Flame orchard world (`PlayerWalnut`) and in the interactive Onboarding
/// Character & Outfit Studio (`CultivarCreatorScreen`).
void renderWalnutWardrobeOutfit(
  Canvas canvas, {
  required String wardrobeId,
  required int facingRow,
  required double offsetX,
  required double liftY,
  double animClock = 0.0,
}) {
  if (wardrobeId == 'none' || wardrobeId.isEmpty) return;

  final faceShift = facingRow == 1
      ? -2.0
      : facingRow == 2
          ? 2.0
          : 0.0;
  final ox = offsetX;
  final oy = -liftY;
  final darkOutline = Paint()..color = const Color(0xFF1C110A);

  switch (wardrobeId) {
    case 'moss_band':
      // Twin living emerald wrist-moss bands + tiny glowing spore bud
      final mossBase = Paint()..color = const Color(0xFF2D6A4F);
      final mossBright = Paint()..color = const Color(0xFF52B788);
      final sporeGlow = Paint()..color = const Color(0xFFB7E4C7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(22.0 + ox, 19.2 + oy, 3.6, 2.6),
          const Radius.circular(1.2),
        ),
        mossBase,
      );
      canvas.drawCircle(Offset(23.8 + ox, 20.0 + oy), 1.3, mossBright);
      canvas.drawCircle(Offset(24.2 + ox, 19.4 + oy), 0.65, sporeGlow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6.6 + ox, 19.4 + oy, 3.2, 2.2),
          const Radius.circular(1.0),
        ),
        mossBright,
      );
      break;

    case 'tie_dye_tee':
      // Psychedelic rainbow spiral tie-dye festival tunic + peace pendant
      const spiralCols = [
        Color(0xFFFF595E),
        Color(0xFFFFCA3A),
        Color(0xFF8AC926),
        Color(0xFF1982C4),
        Color(0xFF6A4C93),
      ];
      final phase = animClock * 1.4;
      for (var dy = 0; dy < 6; dy++) {
        for (var dx = 0; dx < 12; dx++) {
          final cx = dx - 5.5;
          final cy = dy - 2.5;
          final ang =
              math.atan2(cy, cx) + math.sqrt(cx * cx + cy * cy) * 0.75 - phase;
          final idx = ((ang * 1.6).floor() % 5 + 5) % 5;
          canvas.drawRect(
            Rect.fromLTWH(10.0 + dx + ox, 19.0 + dy + oy, 1.05, 1.05),
            Paint()..color = spiralCols[idx],
          );
        }
      }
      if (facingRow != 3) {
        canvas.drawCircle(
          Offset(16.0 + faceShift * 0.4 + ox, 20.8 + oy),
          1.25,
          Paint()..color = const Color(0xFFFFD166),
        );
      }
      break;

    case 'fringe_vest':
      // Woodstock buckskin suede vest + turquoise bead yoke + swaying tassels + headband
      final suede = Paint()..color = const Color(0xFFC68B59);
      final suedeDark = Paint()..color = const Color(0xFF8C5832);
      final fringe = Paint()..color = const Color(0xFFEED7C5);
      final turquoise = Paint()..color = const Color(0xFF48CAE4);
      canvas.drawRect(Rect.fromLTWH(10.0 + ox, 19.0 + oy, 4.5, 5.5), suede);
      canvas.drawRect(Rect.fromLTWH(17.5 + ox, 19.0 + oy, 4.5, 5.5), suede);
      canvas.drawRect(Rect.fromLTWH(14.3 + ox, 19.0 + oy, 3.4, 5.5), suedeDark);
      canvas.drawRect(Rect.fromLTWH(10.2 + ox, 19.4 + oy, 4.0, 1.1), turquoise);
      canvas.drawRect(Rect.fromLTWH(17.8 + ox, 19.4 + oy, 4.0, 1.1), turquoise);
      final tasselSwing = math.sin(animClock * 7.0) * 0.6;
      for (var fx = 10.5; fx <= 21.5; fx += 2.0) {
        canvas.drawRect(
          Rect.fromLTWH(fx + tasselSwing + ox, 24.2 + oy, 1.0, 2.0),
          fringe,
        );
      }
      // Beaded leather headband
      canvas.drawRect(
        Rect.fromLTWH(7.5 + ox, 5.8 + oy, 17.0, 1.8),
        Paint()..color = const Color(0xFF6F4518),
      );
      for (var bx = 9.0; bx <= 22.5; bx += 3.2) {
        canvas.drawRect(
          Rect.fromLTWH(bx + ox, 6.0 + oy, 1.2, 1.2),
          turquoise,
        );
      }
      break;

    case 'flower_crown_poncho':
      // Golden hand-loomed sunshine poncho + meadow daisy & blossom crown
      final ponchoGold = Paint()..color = const Color(0xFFFFBE0B);
      final ponchoCoral = Paint()..color = const Color(0xFFFB5607);
      final creamTrim = Paint()..color = const Color(0xFFFFF8E7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9.0 + ox, 18.6 + oy, 14.0, 6.2),
          const Radius.circular(2.0),
        ),
        ponchoGold,
      );
      canvas.drawRect(
        Rect.fromLTWH(9.5 + ox, 21.2 + oy, 13.0, 1.3),
        ponchoCoral,
      );
      for (var px = 9.8; px <= 21.8; px += 2.2) {
        canvas.drawRect(
          Rect.fromLTWH(px + ox, 24.5 + oy, 1.1, 1.3),
          creamTrim,
        );
      }
      // Woven meadow flower crown
      canvas.drawRect(
        Rect.fromLTWH(8.0 + ox, 5.8 + oy, 16.0, 1.3),
        Paint()..color = const Color(0xFF52B788),
      );
      const blossoms = [
        (9.5, 5.6, Color(0xFFFFAFCC)),
        (12.8, 5.1, Color(0xFFFFD166)),
        (16.0, 4.9, Color(0xFFFFFFFF)),
        (19.2, 5.1, Color(0xFFBDB2FF)),
        (22.5, 5.6, Color(0xFFFFAFCC)),
      ];
      for (final (bx, by, bcol) in blossoms) {
        canvas.drawCircle(Offset(bx + ox, by + oy), 1.45, Paint()..color = bcol);
      }
      break;

    case 'denim_rose_specs':
      // Patchwork faded indigo denim vest + round rose-tinted Lennon glasses
      final denim = Paint()..color = const Color(0xFF3A86FF);
      final denimDark = Paint()..color = const Color(0xFF1D3557);
      final stitchGold = Paint()..color = const Color(0xFFFFD166);
      canvas.drawRect(Rect.fromLTWH(10.0 + ox, 19.0 + oy, 4.8, 6.0), denim);
      canvas.drawRect(Rect.fromLTWH(17.2 + ox, 19.0 + oy, 4.8, 6.0), denim);
      canvas.drawRect(Rect.fromLTWH(14.8 + ox, 19.0 + oy, 2.4, 6.0), denimDark);
      canvas.drawRect(Rect.fromLTWH(10.8 + ox, 20.2 + oy, 3.0, 1.0), stitchGold);
      canvas.drawRect(
        Rect.fromLTWH(18.2 + ox, 22.0 + oy, 2.8, 1.8),
        Paint()..color = const Color(0xFFFF595E),
      );
      if (facingRow != 3) {
        final roseGlass = Paint()..color = const Color(0xFFFF70A6);
        final goldRim = Paint()..color = const Color(0xFFFFD166);
        final lx = 13.2 + faceShift + ox;
        final rx = 18.8 + faceShift + ox;
        final gy = 11.8 + oy;
        canvas.drawCircle(Offset(lx, gy), 2.3, goldRim);
        canvas.drawCircle(Offset(rx, gy), 2.3, goldRim);
        canvas.drawCircle(Offset(lx, gy), 1.65, roseGlass);
        canvas.drawCircle(Offset(rx, gy), 1.65, roseGlass);
        canvas.drawRect(Rect.fromLTWH(lx + 1.5, gy - 0.4, 2.6, 0.9), goldRim);
      }
      break;

    case 'paisley_bandana_vest':
      // Crimson stage bandana + deep teal & electric-orange paisley tunic
      final bandanaRed = Paint()..color = const Color(0xFFE63946);
      final bandanaShade = Paint()..color = const Color(0xFF9B2226);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7.2 + ox, 5.0 + oy, 17.6, 2.8),
          const Radius.circular(1.0),
        ),
        bandanaRed,
      );
      canvas.drawRect(Rect.fromLTWH(6.5 + ox, 6.8 + oy, 2.0, 2.8), bandanaShade);
      // Paisley tunic
      canvas.drawRect(
        Rect.fromLTWH(10.0 + ox, 19.0 + oy, 12.0, 6.0),
        Paint()..color = const Color(0xFF006D77),
      );
      for (final (px, py, col) in const [
        (11.2, 20.0, Color(0xFFFF9F1C)),
        (14.2, 22.8, Color(0xFFFFD166)),
        (17.8, 20.4, Color(0xFFFF70A6)),
        (20.0, 23.0, Color(0xFF80FFDB)),
      ]) {
        canvas.drawCircle(Offset(px + ox, py + oy), 1.05, Paint()..color = col);
      }
      break;

    case 'velvet_bellbottom_coat':
      // Crushed bohemian plum velvet coat + pearl lapel + cream go-go stage boots
      final plumCoat = Paint()..color = const Color(0xFF7209B7);
      final lavenderBoa = Paint()..color = const Color(0xFFE0AAFF);
      final creamBoot = Paint()..color = const Color(0xFFF8F9FA);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9.4 + ox, 18.8 + oy, 13.2, 6.6),
          const Radius.circular(1.5),
        ),
        plumCoat,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9.2 + ox, 18.4 + oy, 13.6, 2.2),
          const Radius.circular(1.2),
        ),
        lavenderBoa,
      );
      for (final px in const [12.5, 14.8, 17.2, 19.5]) {
        canvas.drawCircle(
          Offset(px + ox, 20.8 + oy),
          0.7,
          Paint()..color = const Color(0xFFFFF8E7),
        );
      }
      // Cream stage boots
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10.6 + ox, 25.0 + oy, 4.4, 2.8),
          const Radius.circular(1.0),
        ),
        creamBoot,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(17.2 + ox, 25.0 + oy, 4.4, 2.8),
          const Radius.circular(1.0),
        ),
        creamBoot,
      );
      break;

    case 'heart_specs':
      if (facingRow != 3) {
        final tang = Paint()..color = const Color(0xFFFB8500);
        final spec = Paint()..color = const Color(0xFFFFE5D9);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(10.8 + faceShift + ox, 9.8 + oy, 4.4, 3.2),
            const Radius.circular(1.2),
          ),
          tang,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(16.8 + faceShift + ox, 9.8 + oy, 4.4, 3.2),
            const Radius.circular(1.2),
          ),
          tang,
        );
        canvas.drawRect(
          Rect.fromLTWH(15.0 + faceShift + ox, 10.8 + oy, 2.0, 1.0),
          tang,
        );
        canvas.drawRect(
          Rect.fromLTWH(11.4 + faceShift + ox, 10.2 + oy, 1.1, 1.0),
          spec,
        );
        canvas.drawRect(
          Rect.fromLTWH(17.4 + faceShift + ox, 10.2 + oy, 1.1, 1.0),
          spec,
        );
      }
      break;

    case 'willow_shawl':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8.8 + ox, 18.0 + oy, 14.4, 3.4),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF74C69D),
      );
      canvas.drawRect(
        Rect.fromLTWH(9.6 + ox, 20.6 + oy, 12.8, 1.2),
        Paint()..color = const Color(0xFF40916C),
      );
      break;

    case 'mcgregor_vest':
      final cord = Paint()..color = const Color(0xFFE9C46A);
      canvas.drawRect(Rect.fromLTWH(10.0 + ox, 19.0 + oy, 4.4, 6.0), cord);
      canvas.drawRect(Rect.fromLTWH(17.6 + ox, 19.0 + oy, 4.4, 6.0), cord);
      canvas.drawCircle(
        Offset(12.2 + ox, 21.0 + oy),
        1.0,
        Paint()..color = const Color(0xFFE76F51),
      );
      break;

    case 'amethyst_specs':
      if (facingRow != 3) {
        final am = Paint()..color = const Color(0xFFFF70A6);
        final rim = Paint()..color = const Color(0xFF9D4EDD);
        canvas.drawRect(
          Rect.fromLTWH(10.6 + faceShift + ox, 9.6 + oy, 4.6, 3.4),
          rim,
        );
        canvas.drawRect(
          Rect.fromLTWH(16.8 + faceShift + ox, 9.6 + oy, 4.6, 3.4),
          rim,
        );
        canvas.drawRect(
          Rect.fromLTWH(11.2 + faceShift + ox, 10.1 + oy, 3.4, 2.4),
          am,
        );
        canvas.drawRect(
          Rect.fromLTWH(17.4 + faceShift + ox, 10.1 + oy, 3.4, 2.4),
          am,
        );
      }
      break;

    case 'star_crystal_specs':
      if (facingRow != 3) {
        final crys = Paint()..color = const Color(0xFF72EFDD);
        canvas.drawRect(
          Rect.fromLTWH(10.0 + faceShift + ox, 9.8 + oy, 5.2, 3.2),
          darkOutline,
        );
        canvas.drawRect(
          Rect.fromLTWH(16.8 + faceShift + ox, 9.8 + oy, 5.2, 3.2),
          darkOutline,
        );
        canvas.drawRect(
          Rect.fromLTWH(10.5 + faceShift + ox, 10.2 + oy, 4.2, 2.4),
          crys,
        );
        canvas.drawRect(
          Rect.fromLTWH(17.3 + faceShift + ox, 10.2 + oy, 4.2, 2.4),
          crys,
        );
      }
      break;

    case 'gold_w_vest':
      canvas.drawRect(
        Rect.fromLTWH(10.0 + ox, 19.0 + oy, 12.0, 6.0),
        Paint()..color = const Color(0xFF1F1F24),
      );
      canvas.drawRect(
        Rect.fromLTWH(10.0 + ox, 19.0 + oy, 1.8, 6.0),
        Paint()..color = const Color(0xFFFFD166),
      );
      canvas.drawRect(
        Rect.fromLTWH(20.2 + ox, 19.0 + oy, 1.8, 6.0),
        Paint()..color = const Color(0xFFFFD166),
      );
      canvas.drawRect(
        Rect.fromLTWH(14.0 + ox, 20.0 + oy, 4.0, 3.0),
        Paint()..color = const Color(0xFFFFD166),
      );
      // Red Air McGregor high-top accents!
      canvas.drawRect(
        Rect.fromLTWH(10.8 + ox, 25.0 + oy, 4.2, 2.4),
        Paint()..color = const Color(0xFFE63946),
      );
      canvas.drawRect(
        Rect.fromLTWH(17.2 + ox, 25.0 + oy, 4.2, 2.4),
        Paint()..color = const Color(0xFFE63946),
      );
      break;

    case 'sunset_biolume_shawl':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8.2 + ox, 18.0 + oy, 15.6, 3.2),
          const Radius.circular(1.4),
        ),
        Paint()..color = const Color(0xFFF77F00),
      );
      canvas.drawRect(
        Rect.fromLTWH(9.6 + ox, 20.2 + oy, 12.8, 1.8),
        Paint()..color = const Color(0xFF48CAE4),
      );
      break;

    case 'purple_haze_bandana':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7.4 + ox, 5.0 + oy, 17.2, 3.0),
          const Radius.circular(1.0),
        ),
        Paint()..color = const Color(0xFF9D4EDD),
      );
      canvas.drawRect(
        Rect.fromLTWH(6.5 + ox, 7.0 + oy, 2.0, 3.0),
        Paint()..color = const Color(0xFF7B2CBF),
      );
      break;

    case 'press_photographer_vest':
      // Khaki 1969 press vest + pockets + silver camera strap + white PRESS card
      final khaki = Paint()..color = const Color(0xFFC8B07A);
      final khakiPocket = Paint()..color = const Color(0xFF998252);
      canvas.drawRect(Rect.fromLTWH(9.8 + ox, 18.8 + oy, 4.8, 6.2), khaki);
      canvas.drawRect(Rect.fromLTWH(17.4 + ox, 18.8 + oy, 4.8, 6.2), khaki);
      canvas.drawRect(
          Rect.fromLTWH(10.3 + ox, 21.6 + oy, 3.4, 2.4), khakiPocket);
      canvas.drawRect(
          Rect.fromLTWH(18.3 + ox, 21.6 + oy, 3.4, 2.4), khakiPocket);
      // Diagonal silver camera strap & black rangefinder body
      if (facingRow != 3) {
        canvas.drawLine(
          Offset(11.0 + ox, 18.8 + oy),
          Offset(17.5 + ox, 24.0 + oy),
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..strokeWidth = 1.1,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(14.0 + ox, 21.4 + oy, 4.2, 3.0),
            const Radius.circular(0.8),
          ),
          Paint()..color = const Color(0xFF1F242D),
        );
        canvas.drawCircle(
          Offset(16.1 + ox, 22.9 + oy),
          1.0,
          Paint()..color = const Color(0xFF90E0EF),
        );
      }
      // Press hat band & white PRESS ticket
      canvas.drawRect(
        Rect.fromLTWH(8.0 + ox, 5.6 + oy, 16.0, 1.8),
        Paint()..color = const Color(0xFF5C4728),
      );
      canvas.drawRect(
        Rect.fromLTWH(18.8 + ox, 4.2 + oy, 3.4, 2.4),
        Paint()..color = const Color(0xFFFFF8EB),
      );
      break;

    case 'artisan_patchwork_cape':
      // Hand-loomed 3-grove festival quilt cape (rose, emerald clover, Santurce gold)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8.8 + ox, 18.4 + oy, 4.8, 6.4),
          const Radius.circular(1.4),
        ),
        Paint()..color = const Color(0xFFFF70A6),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(13.6 + ox, 18.4 + oy, 4.8, 6.4),
          const Radius.circular(1.0),
        ),
        Paint()..color = const Color(0xFF52B788),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(18.4 + ox, 18.4 + oy, 4.8, 6.4),
          const Radius.circular(1.4),
        ),
        Paint()..color = const Color(0xFFFFBE0B),
      );
      for (var fx = 9.4; fx <= 22.4; fx += 2.2) {
        canvas.drawRect(
          Rect.fromLTWH(fx + ox, 24.6 + oy, 1.1, 1.4),
          Paint()..color = const Color(0xFFFFF3D6),
        );
      }
      break;

    case 'campfire_ranger_hat':
      // Pine-green Appalachian trail ranger hat + warm crimson campfire kerchief
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(16.0 + ox, 6.0 + oy),
          width: 21.0,
          height: 4.4,
        ),
        Paint()..color = const Color(0xFF1B4332),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10.2 + ox, 2.2 + oy, 11.6, 4.2),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0xFF2D6A4F),
      );
      canvas.drawRect(
        Rect.fromLTWH(10.4 + ox, 5.0 + oy, 11.2, 1.1),
        Paint()..color = const Color(0xFFE76F51),
      );
      // Crimson campfire neck kerchief
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10.4 + ox, 18.4 + oy, 11.2, 2.8),
          const Radius.circular(1.2),
        ),
        Paint()..color = const Color(0xFFD62828),
      );
      break;

    case 'pinball_wizard_jacket':
      // Electric magenta-and-gold quilted arcade satin bomber + lightning star
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9.4 + ox, 18.6 + oy, 13.2, 6.4),
          const Radius.circular(1.8),
        ),
        Paint()..color = const Color(0xFFF72585),
      );
      canvas.drawRect(
        Rect.fromLTWH(9.4 + ox, 18.8 + oy, 2.6, 5.8),
        Paint()..color = const Color(0xFFFFBE0B),
      );
      canvas.drawRect(
        Rect.fromLTWH(20.0 + ox, 18.8 + oy, 2.6, 5.8),
        Paint()..color = const Color(0xFFFFBE0B),
      );
      canvas.drawCircle(
        Offset(16.0 + ox, 21.6 + oy),
        1.8,
        Paint()..color = const Color(0xFF4CC9F0),
      );
      canvas.drawCircle(
        Offset(16.0 + ox, 21.6 + oy),
        0.9,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      break;

    default:
      break;
  }
}
