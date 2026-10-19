import 'dart:math' as math;
import 'package:flutter/material.dart';

/// রিয়েল ও খাঁটি ব্র্যান্ড আইকন (WhatsApp, bKash, Nagad, CellFin, Facebook)
/// রেজোলিউশন-ইন্ডিপেনডেন্ট ভেক্টর পেইন্টার দ্বারা বাস্তবায়িত।
class BrandIcon extends StatelessWidget {
  const BrandIcon._({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
  });

  final BrandType type;
  final double size;
  final Color? color;

  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color bkashPink = Color(0xFFE2136E);
  static const Color nagadOrange = Color(0xFFF7941D);
  static const Color cellfinBlue = Color(0xFF0072BC);
  static const Color facebookBlue = Color(0xFF1877F2);

  factory BrandIcon.whatsapp({Key? key, double size = 20, Color? color}) =>
      BrandIcon._(key: key, type: BrandType.whatsapp, size: size, color: color);

  factory BrandIcon.bkash({Key? key, double size = 20, Color? color}) =>
      BrandIcon._(key: key, type: BrandType.bkash, size: size, color: color);

  factory BrandIcon.nagad({Key? key, double size = 20, Color? color}) =>
      BrandIcon._(key: key, type: BrandType.nagad, size: size, color: color);

  factory BrandIcon.cellfin({Key? key, double size = 20, Color? color}) =>
      BrandIcon._(key: key, type: BrandType.cellfin, size: size, color: color);

  factory BrandIcon.facebook({Key? key, double size = 20, Color? color}) =>
      BrandIcon._(key: key, type: BrandType.facebook, size: size, color: color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandPainter(type: type, customColor: color),
      ),
    );
  }
}

enum BrandType { whatsapp, bkash, nagad, cellfin, facebook }

class _BrandPainter extends CustomPainter {
  const _BrandPainter({required this.type, this.customColor});

  final BrandType type;
  final Color? customColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (type) {
      case BrandType.whatsapp:
        _drawWhatsApp(canvas, w, h);
        break;
      case BrandType.bkash:
        _drawBkash(canvas, w, h);
        break;
      case BrandType.nagad:
        _drawNagad(canvas, w, h);
        break;
      case BrandType.cellfin:
        _drawCellFin(canvas, w, h);
        break;
      case BrandType.facebook:
        _drawFacebook(canvas, w, h);
        break;
    }
  }

  void _drawWhatsApp(Canvas canvas, double w, double h) {
    final bgPaint = Paint()
      ..color = customColor ?? BrandIcon.whatsappGreen
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Speech bubble with tail pointing at bottom-left
    final bubblePath = Path();
    final cx = w * 0.52;
    final cy = h * 0.48;
    final r = w * 0.45;

    // Circular arc around top and right
    bubblePath.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.72,
      math.pi * 1.80,
    );

    // Bottom-left speech pointer/tail
    bubblePath.lineTo(w * 0.12, h * 0.88);
    bubblePath.lineTo(w * 0.32, h * 0.82);
    bubblePath.close();

    canvas.drawPath(bubblePath, bgPaint);

    // White telephone receiver handset inside
    final phonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(w * 0.50, h * 0.47);
    canvas.rotate(-math.pi * 0.18);

    final handset = Path();
    final hw = w * 0.52;
    final hh = h * 0.52;

    handset.moveTo(-hw * 0.38, -hh * 0.10);
    handset.cubicTo(-hw * 0.38, -hh * 0.38, -hw * 0.12, -hh * 0.42, 0, -hh * 0.42);
    handset.cubicTo(hw * 0.22, -hh * 0.42, hw * 0.38, -hh * 0.25, hw * 0.38, 0);
    handset.cubicTo(hw * 0.38, hh * 0.22, hw * 0.20, hh * 0.42, 0, hh * 0.42);
    handset.cubicTo(-hw * 0.22, hh * 0.42, -hw * 0.38, hh * 0.20, -hw * 0.38, -hh * 0.10);

    // Earpiece & mouthpiece bulbous curves
    final phoneShape = Path();
    phoneShape.moveTo(-hw * 0.28, -hh * 0.35);
    phoneShape.cubicTo(-hw * 0.10, -hh * 0.42, hw * 0.10, -hh * 0.42, hw * 0.28, -hh * 0.35);
    phoneShape.cubicTo(hw * 0.36, -hh * 0.30, hw * 0.38, -hh * 0.12, hw * 0.24, -hh * 0.05);
    phoneShape.lineTo(hw * 0.12, hh * 0.02);
    phoneShape.cubicTo(hw * 0.08, hh * 0.05, hw * 0.05, hh * 0.10, hw * 0.02, hh * 0.15);
    phoneShape.cubicTo(-hw * 0.05, hh * 0.10, -hw * 0.10, hh * 0.05, -hw * 0.12, hh * 0.02);
    phoneShape.lineTo(-hw * 0.24, -hh * 0.05);
    phoneShape.cubicTo(-hw * 0.38, -hh * 0.12, -hw * 0.36, -hh * 0.30, -hw * 0.28, -hh * 0.35);
    phoneShape.close();

    canvas.drawPath(phoneShape, phonePaint);
    canvas.restore();
  }

  void _drawBkash(Canvas canvas, double w, double h) {
    // Official bKash geometric origami bird in #E2136E
    final baseColor = customColor ?? BrandIcon.bkashPink;

    final scaleX = w / 24.0;
    final scaleY = h / 24.0;

    Offset pt(double x, double y) => Offset(x * scaleX, y * scaleY);

    // 1. Head / Beak (facing top-left)
    final headPaint = Paint()..color = baseColor.withValues(alpha: 0.95);
    final head = Path()
      ..moveTo(pt(6.5, 4.0).dx, pt(6.5, 4.0).dy)
      ..lineTo(pt(2.5, 8.0).dx, pt(2.5, 8.0).dy)
      ..lineTo(pt(9.0, 8.0).dx, pt(9.0, 8.0).dy)
      ..close();
    canvas.drawPath(head, headPaint);

    // 2. Upper Swept Wing (flying up-right)
    final wingTopPaint = Paint()..color = baseColor;
    final wingTop = Path()
      ..moveTo(pt(9.0, 8.0).dx, pt(9.0, 8.0).dy)
      ..lineTo(pt(21.5, 2.5).dx, pt(21.5, 2.5).dy)
      ..lineTo(pt(15.0, 12.0).dx, pt(15.0, 12.0).dy)
      ..close();
    canvas.drawPath(wingTop, wingTopPaint);

    // 3. Central Origami Body / Chest
    final bodyPaint = Paint()..color = baseColor.withValues(alpha: 0.88);
    final body = Path()
      ..moveTo(pt(2.5, 8.0).dx, pt(2.5, 8.0).dy)
      ..lineTo(pt(9.0, 8.0).dx, pt(9.0, 8.0).dy)
      ..lineTo(pt(15.0, 12.0).dx, pt(15.0, 12.0).dy)
      ..lineTo(pt(8.0, 16.0).dx, pt(8.0, 16.0).dy)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // 4. Lower Wing
    final wingLowPaint = Paint()..color = baseColor.withValues(alpha: 0.92);
    final wingLow = Path()
      ..moveTo(pt(8.0, 16.0).dx, pt(8.0, 16.0).dy)
      ..lineTo(pt(15.0, 12.0).dx, pt(15.0, 12.0).dy)
      ..lineTo(pt(19.0, 16.5).dx, pt(19.0, 16.5).dy)
      ..close();
    canvas.drawPath(wingLow, wingLowPaint);

    // 5. Tail
    final tailPaint = Paint()..color = baseColor.withValues(alpha: 0.85);
    final tail = Path()
      ..moveTo(pt(8.0, 16.0).dx, pt(8.0, 16.0).dy)
      ..lineTo(pt(19.0, 16.5).dx, pt(19.0, 16.5).dy)
      ..lineTo(pt(13.5, 22.0).dx, pt(13.5, 22.0).dy)
      ..close();
    canvas.drawPath(tail, tailPaint);
  }

  void _drawNagad(Canvas canvas, double w, double h) {
    // Official Nagad swirling dynamic flame petals in #F7941D & red
    final baseColor = customColor ?? BrandIcon.nagadOrange;

    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.46;

    // Background circle or ring
    final bgPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Swirling white flame petals inside
    final swirlPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final p1 = Path();
    p1.moveTo(center.dx, center.dy);
    p1.cubicTo(
      w * 0.30, h * 0.25,
      w * 0.40, h * 0.15,
      w * 0.55, h * 0.18,
    );
    p1.cubicTo(
      w * 0.65, h * 0.25,
      w * 0.55, h * 0.40,
      center.dx, center.dy,
    );
    p1.close();
    canvas.drawPath(p1, swirlPaint);

    // Second swoosh (rotated 120 deg)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi * 2 / 3);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(p1, swirlPaint);

    // Third swoosh (rotated 240 deg)
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi * 2 / 3);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(p1, swirlPaint);
    canvas.restore();

    // Center circular core dot
    final centerDotPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.22, centerDotPaint);
  }

  void _drawCellFin(Canvas canvas, double w, double h) {
    // CellFin Interconnected dual loops in #0072BC
    final baseColor = customColor ?? BrandIcon.cellfinBlue;

    final loopPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..isAntiAlias = true;

    final r = w * 0.26;
    // Left circle
    canvas.drawCircle(Offset(w * 0.38, h * 0.5), r, loopPaint);
    // Right circle
    canvas.drawCircle(Offset(w * 0.62, h * 0.5), r, loopPaint);
  }

  void _drawFacebook(Canvas canvas, double w, double h) {
    // Official Facebook blue circle with white 'f'
    final baseColor = customColor ?? BrandIcon.facebookBlue;
    final center = Offset(w * 0.5, h * 0.5);
    final r = w * 0.48;

    final bgPaint = Paint()..color = baseColor;
    canvas.drawCircle(center, r, bgPaint);

    final fPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final fPath = Path();
    final scaleX = w / 24.0;
    final scaleY = h / 24.0;
    Offset pt(double x, double y) => Offset(x * scaleX, y * scaleY);

    // White 'f' letter path
    fPath.moveTo(pt(13.5, 23.5).dx, pt(13.5, 23.5).dy);
    fPath.lineTo(pt(13.5, 14.5).dx, pt(13.5, 14.5).dy);
    fPath.lineTo(pt(16.5, 14.5).dx, pt(16.5, 14.5).dy);
    fPath.lineTo(pt(17.0, 11.0).dx, pt(17.0, 11.0).dy);
    fPath.lineTo(pt(13.5, 11.0).dx, pt(13.5, 11.0).dy);
    fPath.lineTo(pt(13.5, 8.8).dx, pt(13.5, 8.8).dy);
    fPath.cubicTo(
      pt(13.5, 7.8).dx, pt(13.5, 7.8).dy,
      pt(13.8, 7.0).dx, pt(13.8, 7.0).dy,
      pt(15.2, 7.0).dx, pt(15.2, 7.0).dy,
    );
    fPath.lineTo(pt(17.0, 7.0).dx, pt(17.0, 7.0).dy);
    fPath.lineTo(pt(17.0, 4.0).dx, pt(17.0, 4.0).dy);
    fPath.cubicTo(
      pt(16.0, 3.8).dx, pt(16.0, 3.8).dy,
      pt(14.8, 3.5).dx, pt(14.8, 3.5).dy,
      pt(13.0, 3.5).dx, pt(13.0, 3.5).dy,
    );
    fPath.cubicTo(
      pt(9.5, 3.5).dx, pt(9.5, 3.5).dy,
      pt(8.0, 5.5).dx, pt(8.0, 5.5).dy,
      pt(8.0, 9.0).dx, pt(8.0, 9.0).dy,
    );
    fPath.lineTo(pt(8.0, 11.0).dx, pt(8.0, 11.0).dy);
    fPath.lineTo(pt(5.5, 11.0).dx, pt(5.5, 11.0).dy);
    fPath.lineTo(pt(5.5, 14.5).dx, pt(5.5, 14.5).dy);
    fPath.lineTo(pt(8.0, 14.5).dx, pt(8.0, 14.5).dy);
    fPath.lineTo(pt(8.0, 23.5).dx, pt(8.0, 23.5).dy);
    fPath.close();

    canvas.drawPath(fPath, fPaint);
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.customColor != customColor;
  }
}
