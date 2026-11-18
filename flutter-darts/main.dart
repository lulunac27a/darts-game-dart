import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const DartsGameApp());
}

class DartsGameApp extends StatelessWidget {
  const DartsGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Official Darts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DartsGameScreen(),
    );
  }
}

class DartThrow {
  final Offset position; // Normalized coordinates (-1.0 to 1.0)
  final int points;
  final String label;

  DartThrow(this.position, this.points, this.label);
}

class DartsGameScreen extends StatefulWidget {
  const DartsGameScreen({super.key});

  @override
  State<DartsGameScreen> createState() => _DartsGameScreenState();
}

class _DartsGameScreenState extends State<DartsGameScreen>
    with TickerProviderStateMixin {
  static const List<int> boardNumbers = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
    3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];

  late AnimationController _aimController;
  late AnimationController _throwController;

  int _score = 0;
  int _dartsLeft = 9; // 3 rounds of 3 darts
  String _lastCallout = 'Tap anywhere to throw!';

  Offset _currentAim = Offset.zero;
  Offset? _flyingTarget;
  final List<DartThrow> _landedDarts = [];

  @override
  void initState() {
    super.initState();

    _aimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addListener(() {
        if (_flyingTarget == null && _dartsLeft > 0) {
          final t = _aimController.value * 2 * pi;
          setState(() {
            _currentAim = Offset(
              sin(t) * 0.80,
              sin(t * 2) * 0.65,
            );
          });
        }
      });

    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onDartLanded();
        }
      });

    _aimController.repeat();
  }

  void _throwDart() {
    if (_flyingTarget != null || _dartsLeft <= 0) return;

    final rng = Random();
    final jitterX = (rng.nextDouble() - 0.5) * 0.06;
    final jitterY = (rng.nextDouble() - 0.5) * 0.06;

    setState(() {
      _flyingTarget = Offset(
        (_currentAim.dx + jitterX).clamp(-1.0, 1.0),
        (_currentAim.dy + jitterY).clamp(-1.0, 1.0),
      );
    });

    _throwController.forward(from: 0.0);
  }

  void _onDartLanded() {
    final target = _flyingTarget!;
    final distance = target.distance;

    // 1. Determine Wedge Number from Angle
    // Rotate by +90 deg (+pi/2) so top (0, -1) becomes 0 rad, plus half a slice (pi/20)
    final sliceAngle = (2 * pi) / 20;
    double angle = atan2(target.dy, target.dx) + (pi / 2) + (sliceAngle / 2);
    if (angle < 0) angle += 2 * pi;
    if (angle >= 2 * pi) angle -= 2 * pi;

    final sliceIndex = (angle / sliceAngle).floor() % 20;
    final baseNumber = boardNumbers[sliceIndex];

    // 2. Determine Ring Multiplier from Radius (Scoring area ends at 0.82)
    int earned = 0;
    String label = 'Miss! (0)';

    if (distance <= 0.055) {
      earned = 50;
      label = 'BULLSEYE! +50';
    } else if (distance <= 0.13) {
      earned = 25;
      label = 'Outer Bull! +25';
    } else if (distance <= 0.45) {
      earned = baseNumber;
      label = 'Single $baseNumber (+$earned)';
    } else if (distance <= 0.52) {
      earned = baseNumber * 3;
      label = 'TRIPLE $baseNumber! (+$earned)';
    } else if (distance <= 0.75) {
      earned = baseNumber;
      label = 'Single $baseNumber (+$earned)';
    } else if (distance <= 0.82) {
      earned = baseNumber * 2;
      label = 'DOUBLE $baseNumber! (+$earned)';
    }

    setState(() {
      _score += earned;
      _dartsLeft -= 1;
      _lastCallout = _dartsLeft == 0 ? 'Game Over! Total: $_score' : label;
      _landedDarts.add(DartThrow(target, earned, label));
      _flyingTarget = null;
    });
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _dartsLeft = 9;
      _lastCallout = 'Tap anywhere to throw!';
      _landedDarts.clear();
      _flyingTarget = null;
    });
  }

  @override
  void dispose() {
    _aimController.dispose();
    _throwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12161C),
      appBar: AppBar(
        title: const Text('Official Dartboard'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Game',
            onPressed: _resetGame,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dartsLeft > 0 ? _throwDart : _resetGame,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBadge(label: 'SCORE', value: '$_score'),
                _StatBadge(label: 'DARTS LEFT', value: '$_dartsLeft'),
              ],
            ),
            Text(
              _lastCallout,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amberAccent,
              ),
            ),
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AnimatedBuilder(
                    animation: _throwController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: DartboardPainter(
                          boardNumbers: boardNumbers,
                          aim: _currentAim,
                          landedDarts: _landedDarts,
                          flyingTarget: _flyingTarget,
                          flightProgress: _throwController.value,
                          showAim: _dartsLeft > 0 && _flyingTarget == null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton.icon(
                onPressed: _dartsLeft > 0 ? _throwDart : _resetGame,
                icon: Icon(_dartsLeft > 0 ? Icons.gps_fixed : Icons.replay),
                label: Text(_dartsLeft > 0 ? 'THROW DART' : 'PLAY AGAIN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2630),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class DartboardPainter extends CustomPainter {
  final List<int> boardNumbers;
  final Offset aim;
  final List<DartThrow> landedDarts;
  final Offset? flyingTarget;
  final double flightProgress;
  final bool showAim;

  DartboardPainter({
    required this.boardNumbers,
    required this.aim,
    required this.landedDarts,
    required this.flyingTarget,
    required this.flightProgress,
    required this.showAim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sliceAngle = (2 * pi) / 20;

    // 1. Outer Black Number Ring
    canvas.drawCircle(center, radius * 0.98, Paint()..color = const Color(0xFF111111));

    // 2. Draw 20 Alternating Slices & Multipliers
    const blackSector = Color(0xFF1A1A1A);
    const creamSector = Color(0xFFF2E8CF);
    const redRing = Color(0xFFD32F2F);
    const greenRing = Color(0xFF2E7D32);

    for (int i = 0; i < 20; i++) {
      // Center slice 0 (20) at -pi/2 (12 o'clock)
      final startAngle = (-pi / 2) - (sliceAngle / 2) + (i * sliceAngle);
      final isEven = i % 2 == 0;

      final singleColor = isEven ? blackSector : creamSector;
      final multiplierColor = isEven ? redRing : greenRing;

      // Double Ring (0.75 to 0.82)
      _drawWedge(canvas, center, radius * 0.82, startAngle, sliceAngle, multiplierColor);
      // Outer Single (0.52 to 0.75)
      _drawWedge(canvas, center, radius * 0.75, startAngle, sliceAngle, singleColor);
      // Triple Ring (0.45 to 0.52)
      _drawWedge(canvas, center, radius * 0.52, startAngle, sliceAngle, multiplierColor);
      // Inner Single (0.13 to 0.45)
      _drawWedge(canvas, center, radius * 0.45, startAngle, sliceAngle, singleColor);

      // Draw Wedge Number on Outer Rim (radius * 0.90)
      final labelAngle = (-pi / 2) + (i * sliceAngle);
      final labelPos = Offset(
        center.dx + cos(labelAngle) * (radius * 0.90),
        center.dy + sin(labelAngle) * (radius * 0.90),
        );
        _drawNumber(canvas, '${boardNumbers[i]}', labelPos, radius * 0.068);
    }

    // 3. Draw Wire Ring Borders
    final wirePaint = Paint()
    ..color = Colors.grey.shade400
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
    for (final r in [0.13, 0.45, 0.52, 0.75, 0.82]) {
        canvas.drawCircle(center, radius * r, wirePaint);
    }

    // 4. Draw Outer Bull & Inner Bullseye
    canvas.drawCircle(center, radius * 0.13, Paint()..color = greenRing);
    canvas.drawCircle(center, radius * 0.13, wirePaint);
    canvas.drawCircle(center, radius * 0.055, Paint()..color = redRing);
    canvas.drawCircle(center, radius * 0.055, wirePaint);

    // 5. Draw Landed Darts
    for (final dart in landedDarts) {
        final pos = Offset(
        center.dx + dart.position.dx * radius,
        center.dy + dart.position.dy * radius,
    );
    _drawDartPin(canvas, pos, scale: 1.0);
    }

    // 6. Draw Flying Dart Animation
    if (flyingTarget != null) {
        final startPos = Offset(center.dx, size.height + 40);
        final endPos = Offset(
            center.dx + flyingTarget!.dx * radius,
            center.dy + flyingTarget!.dy * radius,
        );
        final currentPos = Offset.lerp(startPos, endPos, flightProgress)!;
        final scale = 2.4 - (1.4 * flightProgress);
        _drawDartPin(canvas, currentPos, scale: scale);
    }

    // 7. Draw Aim Crosshair
    if (showAim) {
        final aimPos = Offset(
            center.dx + aim.dx * radius,
            center.dy + aim.dy * radius,
        );
        final aimPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
        canvas.drawCircle(aimPos, 13, aimPaint);
        canvas.drawLine(
            Offset(aimPos.dx - 18, aimPos.dy),
            Offset(aimPos.dx + 18, aimPos.dy),
            aimPaint,
        );
        canvas.drawLine(
            Offset(aimPos.dx, aimPos.dy - 18),
            Offset(aimPos.dx, aimPos.dy + 18),
            aimPaint,
        );
        }
    }
    void _drawWedge(
    Canvas canvas,
    Offset center,
    double r,
    double startAngle,
    double sweepAngle,
    Color color,
    ) {
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(rect, startAngle, sweepAngle, true, Paint()..color = color);
    }
    void _drawNumber(Canvas canvas, String text, Offset pos, double fontSize) {
        final textPainter = TextPainter(
        text: TextSpan(
        text: text,
        style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        ),
        ),
        textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
        );
    }
    void _drawDartPin(Canvas canvas, Offset pos, {required double scale}) {
        canvas.drawCircle(
        pos.translate(3 * scale, 5 * scale),
        5 * scale,
        Paint()..color = Colors.black54,
        );
        canvas.drawCircle(
        pos,
        8 * scale,
        Paint()..color = Colors.amber,
        );
        canvas.drawCircle(
        pos,
        2.5 * scale,
        Paint()..color = Colors.black,
        );
    }
    @override
    bool shouldRepaint(covariant DartboardPainter oldDelegate) => true;
}