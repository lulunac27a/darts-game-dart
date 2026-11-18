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
      title: 'Swipe Darts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DartsGameScreen(),
    );
  }
}

class DartThrow {
  final Offset position; // Normalized board coordinates (-1.0 to 1.0)
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
    with SingleTickerProviderStateMixin {
  static const List<int> boardNumbers = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];

  late AnimationController _throwController;

  int _score = 0;
  int _dartsLeft = 9;
  String _lastCallout = 'Swipe up from the bottom to throw!';

  // Swipe tracking state
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Flight animation state
  Offset? _flightStartNormalized;
  Offset? _flyingTarget;
  final List<DartThrow> _landedDarts = [];

  @override
  void initState() {
    super.initState();
    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onDartLanded();
        }
      });
  }

  void _onPanStart(DragStartDetails details) {
    if (_flyingTarget != null || _dartsLeft <= 0) return;
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStart == null || _flyingTarget != null || _dartsLeft <= 0) return;
    setState(() {
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details, double boardSize) {
    if (_dragStart == null || _dragCurrent == null || _flyingTarget != null) {
      return;
    }

    final velocity = details.velocity.pixelsPerSecond;
    final swipeVector = _dragCurrent! - _dragStart!;

    // Require an upward swipe
    if (velocity.dy >= -150 || swipeVector.dy >= -20) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
        _lastCallout = 'Flick upward faster to reach the board!';
      });
      return;
    }

    // 1. Horizontal target based on release X + horizontal flick velocity
    final centerX = boardSize / 2;
    final normalizedStartX =
        ((_dragCurrent!.dx - centerX) / centerX).clamp(-0.9, 0.9);
    final lateralDrift = (velocity.dx / 2600).clamp(-0.75, 0.75);
    final targetX = (normalizedStartX * 0.5 + lateralDrift).clamp(-1.05, 1.05);

    // 2. Vertical target based on upward flick speed (-2800 px/s = top, -1600 px/s = bullseye)
    final upwardSpeed = -velocity.dy;
    final power = ((upwardSpeed - 600) / 2200).clamp(0.0, 1.25);
    // Map power: 0.50 -> center (0.0), 1.0 -> top edge (-0.85), 0.1 -> bottom edge (+0.85)
    final targetY = (0.85 - (power * 1.70)).clamp(-1.05, 1.05);

    // Subtle natural scatter
    final rng = Random();
    final jitterX = (rng.nextDouble() - 0.5) * 0.04;
    final jitterY = (rng.nextDouble() - 0.5) * 0.04;

    setState(() {
      _flightStartNormalized = Offset(normalizedStartX, 1.25);
      _flyingTarget = Offset(
        (targetX + jitterX).clamp(-1.05, 1.05),
        (targetY + jitterY).clamp(-1.05, 1.05),
      );
      _dragStart = null;
      _dragCurrent = null;
    });

    _throwController.forward(from: 0.0);
  }

  void _onDartLanded() {
    final target = _flyingTarget!;
    final distance = target.distance;

    // 1. Determine Wedge Number from Angle
    final sliceAngle = (2 * pi) / 20;
    double angle = atan2(target.dy, target.dx) + (pi / 2) + (sliceAngle / 2);
    if (angle < 0) angle += 2 * pi;
    if (angle >= 2 * pi) angle -= 2 * pi;

    final sliceIndex = (angle / sliceAngle).floor() % 20;
    final baseNumber = boardNumbers[sliceIndex];

    // 2. Determine Ring Multiplier
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
      _flightStartNormalized = null;
    });
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _dartsLeft = 9;
      _lastCallout = 'Swipe up from the bottom to throw!';
      _landedDarts.clear();
      _flyingTarget = null;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  @override
  void dispose() {
    _throwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12161C),
      appBar: AppBar(
        title: const Text('Swipe Darts'),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize =
              min(constraints.maxWidth - 24, constraints.maxHeight * 0.58);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: (details) => _onPanEnd(details, boardSize),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Scoreboard HUD
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatBadge(label: 'SCORE', value: '$_score'),
                      _StatBadge(label: 'DARTS LEFT', value: '$_dartsLeft'),
                    ],
                  ),
                ),

                // Callout Banner
                Text(
                  _lastCallout,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),

                // Dartboard Canvas
                SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: AnimatedBuilder(
                    animation: _throwController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: DartboardPainter(
                          boardNumbers: boardNumbers,
                          landedDarts: _landedDarts,
                          flightStart: _flightStartNormalized,
                          flyingTarget: _flyingTarget,
                          flightProgress: Curves.easeOutCubic.transform(
                            _throwController.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Launch Zone / Replay Button
                Container(
                  height: 110,
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2029),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _dragStart != null
                          ? Colors.cyanAccent
                          : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: _dartsLeft > 0
                      ? CustomPaint(
                          painter: SwipeGuidePainter(
                            dragStart: _dragStart,
                            dragCurrent: _dragCurrent,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swipe_up,
                                  color: _dragStart != null
                                      ? Colors.cyanAccent
                                      : Colors.white54,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _dragStart != null
                                      ? 'Release to Throw!'
                                      : 'SWIPE UP HERE TO THROW',
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: _dragStart != null
                                        ? Colors.cyanAccent
                                        : Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: ElevatedButton.icon(
                            onPressed: _resetGame,
                            icon: const Icon(Icons.replay),
                            label: const Text('PLAY AGAIN'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2630),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class SwipeGuidePainter extends CustomPainter {
  final Offset? dragStart;
  final Offset? dragCurrent;
  SwipeGuidePainter({required this.dragStart, required this.dragCurrent});
  @override
  void paint(Canvas canvas, Size size) {
    if (dragStart == null || dragCurrent == null) return;
    final vector = dragCurrent! - dragStart!;
    final center = Offset(size.width / 2, size.height * 0.75);
    final tip = center + Offset(vector.dx * 0.6, vector.dy.clamp(-80.0, 20.0));
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, linePaint);
    canvas.drawCircle(tip, 6, Paint()..color = Colors.amberAccent);
  }

  @override
  bool shouldRepaint(covariant SwipeGuidePainter oldDelegate) => true;
}

class DartboardPainter extends CustomPainter {
  final List boardNumbers;
  final List landedDarts;
  final Offset? flightStart;
  final Offset? flyingTarget;
  final double flightProgress;
  DartboardPainter({
    required this.boardNumbers,
    required this.landedDarts,
    required this.flightStart,
    required this.flyingTarget,
    required this.flightProgress,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sliceAngle = (2 * pi) / 20;

    // 1. Outer Black Number Ring
    canvas.drawCircle(
      center,
      radius * 0.98,
      Paint()..color = const Color(0xFF111111),
    );

    // 2. Draw 20 Alternating Slices & Multipliers
    const blackSector = Color(0xFF1A1A1A);
    const creamSector = Color(0xFFF2E8CF);
    const redRing = Color(0xFFD32F2F);
    const greenRing = Color(0xFF2E7D32);
    for (int i = 0; i < 20; i++) {
      final startAngle = (-pi / 2) - (sliceAngle / 2) + (i * sliceAngle);
      final isEven = i % 2 == 0;
      final singleColor = isEven ? blackSector : creamSector;
      final multiplierColor = isEven ? redRing : greenRing;
      _drawWedge(canvas, center, radius * 0.82, startAngle, sliceAngle,
          multiplierColor);
      _drawWedge(
          canvas, center, radius * 0.75, startAngle, sliceAngle, singleColor);
      _drawWedge(canvas, center, radius * 0.52, startAngle, sliceAngle,
          multiplierColor);
      _drawWedge(
          canvas, center, radius * 0.45, startAngle, sliceAngle, singleColor);
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

    // 6. Draw Flying Dart Animation with Arc Lift
    if (flyingTarget != null && flightStart != null) {
      final startPos = Offset(
        center.dx + flightStart!.dx * radius,
        center.dy + flightStart!.dy * radius,
      );
      final endPos = Offset(
        center.dx + flyingTarget!.dx * radius,
        center.dy + flyingTarget!.dy * radius,
      );

      // Parabolic arc height in mid-flight
      final arcLift = sin(flightProgress * pi) * 45.0;
      final currentPos =
          Offset.lerp(startPos, endPos, flightProgress)!.translate(0, -arcLift);
      final scale = 2.6 - (1.6 * flightProgress);
      _drawDartPin(canvas, currentPos, scale: scale);
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
