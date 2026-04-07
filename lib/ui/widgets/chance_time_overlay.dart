// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/chat_service.dart';

/// Full-screen Chance Time overlay.
///
/// Show it via:
/// ```dart
/// showDialog(context: context, builder: (_) => const ChanceTimeOverlay());
/// ```
class ChanceTimeOverlay extends StatefulWidget {
  const ChanceTimeOverlay({super.key});

  @override
  State<ChanceTimeOverlay> createState() => _ChanceTimeOverlayState();
}

class _ChanceTimeOverlayState extends State<ChanceTimeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  List<String> _segments = const []; // 8 events for this spin
  bool _spinning = false;
  bool _landed = false;
  int _landedIndex = 0;
  double _targetAngle = 0;
  String? _charName;

  // Segment colours (Mario Party palette)
  static const List<Color> _segmentColors = [
    Color(0xFFE63946), // red
    Color(0xFFFF9F1C), // orange
    Color(0xFF2EC4B6), // teal
    Color(0xFF9B5DE5), // purple
    Color(0xFF06D6A0), // green
    Color(0xFFFF6B9D), // pink
    Color(0xFFFFD166), // amber
    Color(0xFF118AB2), // blue
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<ChatService>();
      svc.consumeChanceTimeTrigger();
      setState(() {
        _segments = svc.spinWheelEvents();
        _charName = svc.activeCharacter?.name ?? 'Character';
      });
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning || _landed) return;
    setState(() => _spinning = true);

    // Pick a random landing segment
    final rng = Random();
    _landedIndex = rng.nextInt(8);

    // Extra full rotations (5–8) + precise landing angle
    final extraRotations = (rng.nextInt(4) + 5) * 2 * pi;
    // Segment size = 2π/8. Pointer is at top (12 o'clock) = 0.
    // Segment i starts at i*(2π/8), centre at (i+0.5)*(2π/8).
    final segmentAngle = (2 * pi) / 8;
    final landingAngleInWheel = (_landedIndex + 0.5) * segmentAngle;
    // We need the wheel to rotate so that segment is under the pointer.
    // Pointer at top means we want the segment centre at angle 0 (top).
    // Wheel rotation = full rotations + (2π - landingAngle).
    _targetAngle = extraRotations + (2 * pi - landingAngleInWheel);

    _spinAnimation = Tween<double>(
      begin: 0,
      end: _targetAngle,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    ));

    _spinController.reset();
    _spinController.duration = const Duration(milliseconds: 3800);
    _spinController.forward().whenComplete(() {
      setState(() {
        _spinning = false;
        _landed = true;
      });
    });
  }

  String _displayEvent(String raw) =>
      raw.replaceAll('{{char}}', _charName ?? 'Character');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: _segments.isEmpty
          ? const SizedBox.shrink()
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD166).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildWheel(),
          const SizedBox(height: 28),
          if (_landed) _buildResultCard() else _buildSpinButton(),
          const SizedBox(height: 20),
          _buildPressureRow(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Starburst glow
        Container(
          width: 200,
          height: 60,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFFD166).withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const Text(
          'CHANCE TIME!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD166),
            letterSpacing: 2,
            shadows: [
              Shadow(color: Color(0xFFFFD166), blurRadius: 20),
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
            ],
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheel() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 334,
            height: 334,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFFFD166).withOpacity(0.25),
                ],
                stops: const [0.85, 1.0],
              ),
            ),
          ),
          // Spinning wheel
          AnimatedBuilder(
            animation: _spinning
                ? _spinAnimation
                : AlwaysStoppedAnimation(
                    _landed ? _targetAngle % (2 * pi) : 0,
                  ),
            builder: (context, child) {
              final angle = _spinning
                  ? _spinAnimation.value
                  : (_landed ? _targetAngle % (2 * pi) : 0.0);
              return Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: const Size(310, 310),
                  painter: _WheelPainter(
                    segments: _segments,
                    colors: _segmentColors,
                    charName: _charName ?? 'Character',
                  ),
                ),
              );
            },
          ),
          // Gold centre hub
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFF9C4), Color(0xFFFFD166)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 6, spreadRadius: 1),
              ],
            ),
          ),
          // Pointer triangle at top
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(22, 28),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    return GestureDetector(
      onTap: _spin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD166), Color(0xFFFFC233)],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD166).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'SPIN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1200),
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final event = _displayEvent(_segments[_landedIndex]);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _segmentColors[_landedIndex].withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _segmentColors[_landedIndex].withOpacity(0.6),
            ),
          ),
          child: Text(
            event,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _segmentColors[_landedIndex],
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166),
                foregroundColor: const Color(0xFF1A1200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: () {
                final svc = context.read<ChatService>();
                svc.applyChanceTimeResult(
                  _segments[_landedIndex],
                  _charName ?? 'Character',
                );
                Navigator.of(context).pop();
              },
              child: const Text(
                'Apply Event',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPressureRow() {
    return Consumer<ChatService>(
      builder: (_, svc, __) {
        final pressure = svc.chaosPressure;
        final color = Color.lerp(
          const Color(0xFF2EC4B6),
          const Color(0xFFE63946),
          pressure / 80,
        )!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              'Chaos pressure: $pressure%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── CustomPainters ────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<String> segments;
  final List<Color> colors;
  final String charName;

  const _WheelPainter({
    required this.segments,
    required this.colors,
    required this.charName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * pi) / segments.length;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segmentAngle - pi / 2;
      // Segment fill
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        paint,
      );
      // Divider lines
      final borderPaint = Paint()
        ..color = Colors.black38
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // ── Label ──────────────────────────────────────────────────────────
      final midAngle = startAngle + segmentAngle / 2;

      // Raw label: replace {{char}} and keep only first 3 words
      final rawLabel = segments[i].replaceAll('{{char}}', charName);
      final words = rawLabel.split(' ');
      // Split into two lines of ~3 words each for readability
      final line1 = words.take(3).join(' ');
      final line2 = words.length > 3 ? words.skip(3).take(3).join(' ') : '';
      final labelText = line2.isEmpty ? line1 : '$line1\n$line2';

      // Position: 55% of the way from centre to rim
      final labelRadius = radius * 0.58;
      final lx = center.dx + labelRadius * cos(midAngle);
      final ly = center.dy + labelRadius * sin(midAngle);

      canvas.save();
      canvas.translate(lx, ly);
      // Rotate so text reads from centre outward (along the radius)
      canvas.rotate(midAngle + pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.25,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: 80);

      // Dark pill behind the text for contrast
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 8,
          height: tp.height + 6,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        pillRect,
        Paint()..color = Colors.black.withOpacity(0.45),
      );

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer ring
    paint
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius - 2, paint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.segments != segments || old.charName != charName;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
