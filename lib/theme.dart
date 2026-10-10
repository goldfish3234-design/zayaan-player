import 'package:flutter/material.dart';

class C {
  static const bg1 = Color(0xFF161B42);
  static const bg2 = Color(0xFF080B20);
  static const card = Color(0xFF0D1230);
  static const card2 = Color(0xFF151B45);
  static const pink = Color(0xFFFF2D6F);
  static const red = Color(0xFFFF4B2B);
  static const yellow = Color(0xFFFFD60A);
  static const violet = Color(0xFF7C3AED);
  static const blue = Color(0xFF4C8DFF);
  static const orange = Color(0xFFFF8A3D);
  static const green = Color(0xFF34E26B);
  static const muted = Color(0xFF8A90B2);
  static const line = Color(0x14FFFFFF);
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, red],
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg2,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.pink,
      brightness: Brightness.dark,
    ).copyWith(primary: C.pink, surface: C.card),
  );
}

class GradientBg extends StatelessWidget {
  final Widget child;
  const GradientBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.bg1, C.bg2],
        ),
      ),
      child: child,
    );
  }
}

class _ZPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108;
    final p = Path()
      ..moveTo(30 * s, 30 * s)
      ..lineTo(78 * s, 30 * s)
      ..lineTo(78 * s, 41 * s)
      ..lineTo(47 * s, 67 * s)
      ..lineTo(78 * s, 67 * s)
      ..lineTo(78 * s, 78 * s)
      ..lineTo(30 * s, 78 * s)
      ..lineTo(30 * s, 67 * s)
      ..lineTo(61 * s, 41 * s)
      ..lineTo(30 * s, 41 * s)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD60A), Color(0xFFFF2D6F), Color(0xFF7C3AED)],
      ).createShader(Rect.fromLTWH(30 * s, 30 * s, 48 * s, 48 * s));
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The ZAYAAN logo: a vibrant gradient "Z".
class ZMark extends StatelessWidget {
  final double size;
  final bool plate;
  const ZMark({super.key, this.size = 40, this.plate = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: plate
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1250), Color(0xFF070A1F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: C.pink.withValues(alpha: 0.35),
                    blurRadius: size * 0.4,
                  ),
                ],
              )
            : const BoxDecoration(),
        child: CustomPaint(painter: _ZPainter()),
      ),
    );
  }
}
