import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RingProgress extends StatelessWidget {
  final int count;
  final int target;
  final Color color;

  const RingProgress({
    super.key,
    required this.count,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final int laps = count ~/ target;
    final int remainder = count % target;
    final double progress = target == 0 ? 0 : remainder / target;

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // ── Glow layer ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.20),
                  blurRadius: 80,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),

          // ── Ring painter ─────────────────────────────
          CustomPaint(
            painter: _RingPainter(progress: progress, color: color),
          ),

          // ── Center content ───────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lap badge
                if (laps > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '$laps × completed',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                // Count number
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: count),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) {
                    return Text(
                      '$value',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                // Target label
                Text(
                  'of $target',
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom arc painter ────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const strokeWidth = 12.0;

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = strokeWidth + 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * progress;

    // Always draw track
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, glowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}