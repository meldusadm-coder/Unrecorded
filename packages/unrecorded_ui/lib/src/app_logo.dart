import 'package:flutter/material.dart';

/// Simple brand mark: "U" with a signal arc — works at small sizes.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(color: color),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Signal arc above
    final arcPath = Path()
      ..moveTo(w * 0.15, h * 0.35)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.85, h * 0.35);
    canvas.drawPath(arcPath, paint);

    // "U" shape
    final uPath = Path()
      ..moveTo(w * 0.28, h * 0.38)
      ..lineTo(w * 0.28, h * 0.72)
      ..quadraticBezierTo(w * 0.28, h * 0.95, w * 0.5, h * 0.95)
      ..quadraticBezierTo(w * 0.72, h * 0.95, w * 0.72, h * 0.72)
      ..lineTo(w * 0.72, h * 0.38);
    canvas.drawPath(uPath, paint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
