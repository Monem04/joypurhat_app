import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/catalog.dart';

/// Drawn pictures used until real photos are added: landmark scenes for
/// tourist spots and rentals, plates of food for restaurants. Each is a
/// CustomPainter working in a fixed design box that is scaled to fill.

/// Turns SVG path data ("M0 0h10v10Z", arcs and curves included) into a Path.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsQqAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  // Second control point of the last cubic, for the smooth "S" command.
  Offset? lastCtrl;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        // Further pairs after a move are lines.
        cmd = rel ? 'l' : 'L';
        lastCtrl = null;
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        lastCtrl = null;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        lastCtrl = null;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        lastCtrl = null;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastCtrl = Offset(x2, y2);
      case 'S':
        final c1 = lastCtrl == null ? Offset(x, y) : Offset(2 * x - lastCtrl.dx, 2 * y - lastCtrl.dy);
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(c1.dx, c1.dy, x2, y2, x, y);
        lastCtrl = Offset(x2, y2);
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        lastCtrl = null;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        lastCtrl = null;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        lastCtrl = null;
      default:
        i++;
    }
  }
  return path;
}

Color _c(int v) => Color(v);

/// Scales a fixed design box to cover [size] (like CSS "slice").
void _cover(Canvas canvas, Size size, double w, double h) {
  final s = size.width / w > size.height / h ? size.width / w : size.height / h;
  canvas.translate((size.width - w * s) / 2, (size.height - h * s) / 2);
  canvas.scale(s);
}

// ------------------------------------------------------------ scenes

/// Sky top, sky bottom, hill, landmark, ground.
const Map<String, List<int>> _sceneColors = {
  'mosque': [0xFFBAE6FD, 0xFFF0F9FF, 0xFFBBF7D0, 0xFF0F766E, 0xFF86EFAC],
  'temple': [0xFFFED7AA, 0xFFFFF7ED, 0xFFFDE68A, 0xFF9A3412, 0xFFFCD34D],
  'stupa': [0xFFFDE68A, 0xFFFFFBEB, 0xFFD9F99D, 0xFF92400E, 0xFFBEF264],
  'water': [0xFFA5F3FC, 0xFFECFEFF, 0xFFBBF7D0, 0xFF0E7490, 0xFF6EE7B7],
  'river': [0xFFBAE6FD, 0xFFF0F9FF, 0xFFBBF7D0, 0xFF0369A1, 0xFF86EFAC],
  'ruins': [0xFFE9D5FF, 0xFFFAF5FF, 0xFFD9F99D, 0xFF6B21A8, 0xFFA3E635],
  'factory': [0xFFCBD5E1, 0xFFF8FAFC, 0xFFD1FAE5, 0xFF334155, 0xFF86EFAC],
  'park': [0xFFBBF7D0, 0xFFF0FDF4, 0xFF86EFAC, 0xFF15803D, 0xFF4ADE80],
  'memorial': [0xFFFECACA, 0xFFFFF1F2, 0xFFBBF7D0, 0xFF9F1239, 0xFF86EFAC],
  'church': [0xFFDDD6FE, 0xFFF5F3FF, 0xFFBBF7D0, 0xFF4C1D95, 0xFF86EFAC],
  'pillar': [0xFFFED7AA, 0xFFFFFBEB, 0xFFD9F99D, 0xFF78350F, 0xFFBEF264],
  'house': [0xFFA5F3FC, 0xFFECFEFF, 0xFFA7F3D0, 0xFF0E7490, 0xFF6EE7B7],
  'room': [0xFFFEF3C7, 0xFFFFFBEB, 0xFFFDE68A, 0xFF92400E, 0xFFFCD34D],
};

const Map<String, String> _scenePaths = {
  'mosque': 'M112 122V96h106v26ZM128 96a37 37 0 0 1 74 0ZM163 50h4v10h-4ZM100 122V66h9v56ZM221 122V66h9v56Z'
      'M99 66l5.5-11 5.5 11ZM220 66l5.5-11 5.5 11ZM135 96a11 11 0 0 1 22 0ZM173 96a11 11 0 0 1 22 0Z',
  'temple': 'M130 122V90h70v32ZM135 90l30-48 30 48ZM163 34h4v10h-4ZM112 122V104h22v18ZM196 122V104h22v18Z'
      'M115 104l8-14 8 14ZM199 104l8-14 8 14Z',
  'stupa': 'M96 122V108h138v14ZM112 108V94h106v14ZM128 94V80h74v14ZM146 80V68h38v12ZM152 68a13 13 0 0 1 26 0Z',
  'water': 'M30 126c50-14 220-14 270 0c-50 12-220 12-270 0ZM250 116v-22h4v22ZM252 96a15 15 0 1 1 0-30'
      'a15 15 0 1 1 0 30ZM70 116v-18h3v18ZM71.5 100a11 11 0 1 1 0-22a11 11 0 1 1 0 22Z',
  'river': 'M0 120c60-10 120 6 180-2s110-10 150-4v12c-40-6-90 0-150 6S60 128 0 132ZM60 114v-20h4v20Z'
      'M62 96a13 13 0 1 1 0-26a13 13 0 1 1 0 26Z',
  'ruins': 'M104 122V84h16v38ZM128 122V96h14v26ZM150 122V74h18v48ZM176 122V90h14v32ZM198 122V100h16v22Z'
      'M100 84h72v-8h-72ZM146 74h26v-6h-26Z',
  'factory': 'M96 122V88l30-16v16l30-16v16l30-16v50ZM196 122V44h14v78ZM218 122V60h10v62Z',
  'park': 'M70 122v-24h4v24ZM72 100a20 20 0 1 1 0-40a20 20 0 1 1 0 40ZM160 122v-30h5v30Z'
      'M162 94a26 26 0 1 1 0-52a26 26 0 1 1 0 52ZM250 122v-20h4v20ZM252 104a16 16 0 1 1 0-32a16 16 0 1 1 0 32Z',
  'memorial': 'M156 122V52l9-10 9 10v70ZM130 122V78l7-6 7 6v44ZM186 122V78l7-6 7 6v44ZM112 122v-8h106v8Z',
  'church': 'M128 122V84l37-28 37 28v38ZM162 56V30h6v26ZM155 38h20v6h-20ZM104 122V96l14-10 14 10v26Z',
  'pillar': 'M160 122V42h10v80ZM153 46h24v-8h-24ZM157 38a8 8 0 0 1 16 0ZM144 122v-8h42v8ZM70 122v-20h4v20Z'
      'M72 104a14 14 0 1 1 0-28a14 14 0 1 1 0 28Z',
  'house': 'M100 82l65-42 65 42ZM112 122V82h106v40ZM196 62V44h12v26ZM40 122v-22h4v22ZM42 102a16 16 0 1 1 0-32'
      'a16 16 0 1 1 0 32Z',
  'room': 'M70 122V96h150v26ZM70 96V76h44v20ZM228 122V72h40v50ZM150 30h60v40h-60ZM176 30h8v40h-8Z',
};

final Map<String, Path> _pathCache = {};
Path _path(String d) => _pathCache.putIfAbsent(d, () => parseSvgPath(d));
final Path _hill = parseSvgPath('M0 118C60 96 110 104 170 112S280 100 330 108V150H0Z');
final Path _ground = parseSvgPath('M0 132C80 124 160 136 330 126V150H0Z');

/// A landmark silhouette in a little landscape (330 x 150 design box).
class SceneArt extends StatelessWidget {
  const SceneArt({super.key, required this.kind, this.sunX = 276});
  final String kind;
  final double sunX;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ScenePainter(kind, sunX), child: const SizedBox.expand());
}

/// A real photo filling its box. The drawn scene shows while a web photo
/// loads and stays if it cannot load (no internet, broken link).
class PhotoArt extends StatelessWidget {
  const PhotoArt({super.key, required this.photo, this.fallback = 'park'});
  final Photo photo;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final scene = SceneArt(kind: fallback);
    Widget broken(BuildContext context, Object error, StackTrace? stack) => scene;
    if (!photo.isWeb) {
      return Image.asset(photo.src, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: broken);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        scene,
        Image.network(
          photo.src,
          fit: BoxFit.cover,
          errorBuilder: broken,
          frameBuilder: (context, child, frame, sync) =>
              sync || frame != null ? child : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.kind, this.sunX);
  final String kind;
  final double sunX;

  @override
  void paint(Canvas canvas, Size size) {
    final k = _sceneColors.containsKey(kind) ? kind : 'park';
    final c = _sceneColors[k]!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [_c(c[0]), _c(c[1])]),
    );
    canvas.save();
    _cover(canvas, size, 330, 150);
    canvas.drawCircle(Offset(sunX, 35), 15.5, Paint()..color = const Color(0xC8FFFFFF));
    canvas.drawPath(_hill, Paint()..color = _c(c[2]));
    canvas.drawPath(_path(_scenePaths[k]!), Paint()..color = _c(c[3]));
    canvas.drawPath(_ground, Paint()..color = _c(c[4]));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.kind != kind || old.sunX != sunX;
}

// ------------------------------------------------------------ rentals

/// A small building with lit windows for each vacant flat (330 x 112).
class RentArt extends StatelessWidget {
  const RentArt({super.key, required this.vacant});
  final int vacant;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RentPainter(vacant), child: const SizedBox.expand());
}

class _RentPainter extends CustomPainter {
  _RentPainter(this.vacant);
  final int vacant;

  static final _house = parseSvgPath('M110 98V52l55-30 55 30v46Z');
  static final _roof = parseSvgPath('M100 56l65-38 65 38');

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, size.height), [const Color(0xFFCFFAFE), const Color(0xFFECFEFF)]),
    );
    canvas.save();
    _cover(canvas, size, 330, 112);
    const lit = Color(0xFFFDE68A), dark = Color(0xFFBAE6FD), line = Color(0xFF67E8F9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = line;
    canvas.drawRect(const Rect.fromLTWH(0, 98, 330, 14), Paint()..color = const Color(0xFFA7F3D0));
    canvas.drawPath(_house, Paint()..color = Colors.white);
    canvas.drawPath(_house, stroke);
    canvas.drawPath(
      _roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0891B2),
    );
    void box(double x, double y, double w, double h, double r, Color c) => canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), Paint()..color = c);
    box(128, 60, 20, 16, 2, vacant > 0 ? lit : dark);
    box(182, 60, 20, 16, 2, vacant > 1 ? lit : dark);
    box(155, 74, 20, 24, 2, const Color(0xFF0E7490));
    final shop = RRect.fromRectAndRadius(const Rect.fromLTWH(240, 66, 44, 32), const Radius.circular(3));
    canvas.drawRRect(shop, Paint()..color = Colors.white);
    canvas.drawRRect(shop, stroke);
    box(250, 74, 10, 9, 1.5, vacant > 2 ? lit : dark);
    box(265, 74, 10, 9, 1.5, dark);
    canvas.drawCircle(const Offset(62, 80), 16, Paint()..color = const Color(0xFF6EE7B7));
    canvas.drawRect(const Rect.fromLTWH(60, 86, 4, 12), Paint()..color = const Color(0xFF047857));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RentPainter old) => old.vacant != vacant;
}

// ------------------------------------------------------------ food

/// Real restaurants and sweet shops get these colours (no menu photos).
const restaurantCover = [Color(0xFF99F6E4), Color(0xFF0F766E)];
const sweetCover = [Color(0xFFFBCFE8), Color(0xFFBE185D)];
const restaurantPalette = [Color(0xFFFDE68A), Color(0xFFB45309), Color(0xFFFED7AA), Color(0xFF9A3412)];
const sweetPalette = [Color(0xFFFFFFFF), Color(0xFFF9A8D4), Color(0xFFFEF3C7), Color(0xFFF59E0B)];

/// Three plates on a coloured band (330 x 118), the top of a food card.
class FoodCoverArt extends StatelessWidget {
  const FoodCoverArt({super.key, required this.cover, required this.palette});
  final List<Color> cover;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FoodCoverPainter(cover, palette), child: const SizedBox.expand());
}

class _FoodCoverPainter extends CustomPainter {
  _FoodCoverPainter(this.cover, this.palette);
  final List<Color> cover;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = cover.length >= 2 ? cover : restaurantCover;
    final p = palette.length >= 4 ? palette : restaurantPalette;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [bg[0], bg[1]]),
    );
    canvas.save();
    _cover(canvas, size, 330, 118);
    void dot(double x, double y, double r, Color c) => canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
    const plate = Color(0xE0FFFFFF), plate2 = Color(0xF2FFFFFF);
    dot(70, 70, 38, plate);
    dot(70, 70, 29, p[0]);
    dot(60, 62, 8, p[1]);
    dot(81, 78, 7, p[1]);
    dot(76, 58, 4, Colors.white);
    dot(168, 58, 46, plate2);
    dot(168, 58, 36, p[2]);
    dot(154, 50, 10, p[3]);
    dot(180, 68, 9, p[3]);
    dot(174, 44, 5, Colors.white);
    dot(158, 72, 4, Colors.white);
    dot(264, 74, 36, plate);
    dot(264, 74, 27, p[0]);
    dot(255, 68, 7, p[3]);
    dot(272, 82, 5, p[1]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoodCoverPainter old) => old.cover != cover || old.palette != palette;
}

/// Background, plate food, toppings, garnish for each kind of dish.
const Map<String, List<int>> _dishColors = {
  'rice': [0xFFFEF3C7, 0xFFF59E0B, 0xFFB45309, 0xFFFFFFFF],
  'curry': [0xFFFFEDD5, 0xFFEA580C, 0xFF9A3412, 0xFFFDE68A],
  'fish': [0xFFFFEDD5, 0xFFD97706, 0xFF78350F, 0xFFA3E635],
  'sweet': [0xFFFCE7F3, 0xFFFEF3C7, 0xFFF9A8D4, 0xFFFFFFFF],
  'drink': [0xFFE0F2FE, 0xFFF5F5F4, 0xFFFDBA74, 0xFFFFFFFF],
  'soup': [0xFFFEF9C3, 0xFFFACC15, 0xFF65A30D, 0xFFFFFFFF],
  'noodle': [0xFFFEF3C7, 0xFFFCD34D, 0xFFA16207, 0xFF16A34A],
  'chicken': [0xFFFFEDD5, 0xFFC2410C, 0xFF7C2D12, 0xFFFDBA74],
  'burger': [0xFFFEF3C7, 0xFFD97706, 0xFF78350F, 0xFF22C55E],
  'pizza': [0xFFFEE2E2, 0xFFFBBF24, 0xFFDC2626, 0xFF16A34A],
  'fries': [0xFFFEF9C3, 0xFFFDE047, 0xFFEAB308, 0xFFDC2626],
};

/// A drawn plate for one dish (104 x 96).
class DishArt extends StatelessWidget {
  const DishArt({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DishPainter(kind), child: const SizedBox.expand());
}

class _DishPainter extends CustomPainter {
  _DishPainter(this.kind);
  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = _dishColors[kind] ?? _dishColors['curry']!;
    canvas.drawRect(Offset.zero & size, Paint()..color = _c(c[0]));
    canvas.save();
    _cover(canvas, size, 104, 96);
    void dot(double x, double y, double r, Color col) => canvas.drawCircle(Offset(x, y), r, Paint()..color = col);
    dot(52, 48, 38, const Color(0xEBFFFFFF));
    dot(52, 48, 30, _c(c[1]));
    dot(41, 41, 9, _c(c[2]));
    dot(62, 56, 8, _c(c[2]));
    dot(62, 38, 5, _c(c[3]));
    dot(44, 60, 4, _c(c[3]));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DishPainter old) => old.kind != kind;
}
