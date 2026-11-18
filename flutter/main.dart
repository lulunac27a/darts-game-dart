import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: CatcherGame()));
}

class CatcherGame extends FlameGame with HasCollisionDetection {
  late final PlayerBasket player;
  late final TextComponent scoreText;
  late final TextComponent livesText;

  int score = 0;
  int lives = 3;
  bool isGameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    // 1. Add the player paddle at the bottom center
    player = PlayerBasket()..position = Vector2(size.x / 2, size.y - 80);
    add(player);

    // 2. Add HUD text components
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
    livesText = TextComponent(
      text: 'Lives: 3',
      position: Vector2(size.x - 110, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
            color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
    addAll([scoreText, livesText]);

    // 3. Spawn falling orbs every 0.9 seconds
    add(
      SpawnComponent(
        factory: (_) => FallingOrb(),
        period: 0.9,
      ),
    );
  }

  void increaseScore() {
    if (isGameOver) return;
    score++;
    scoreText.text = 'Score: $score';
  }

  void loseLife() {
    if (isGameOver) return;
    lives--;
    livesText.text = 'Lives: $lives';

    if (lives <= 0) {
      isGameOver = true;
      pauseEngine();
      add(
        TextComponent(
          text: 'GAME OVER\nFinal Score: $score',
          anchor: Anchor.center,
          position: size / 2,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }
}

class PlayerBasket extends PositionComponent
    with DragCallbacks, HasGameReference<CatcherGame> {
  PlayerBasket()
      : super(
          size: Vector2(110, 24),
          anchor: Anchor.center,
        );

  final Paint _paint = Paint()..color = const Color(0xFF00E5FF);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)),
      _paint,
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (game.isGameOver) return;
    position.x += event.localDelta.x;
    // Keep the paddle inside the screen edges
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
  }
}

class FallingOrb extends CircleComponent
    with CollisionCallbacks, HasGameReference<CatcherGame> {
  static final Random _random = Random();
  late final double speed;

  FallingOrb() : super(radius: 16, anchor: Anchor.center) {
    paint = Paint()..color = const Color(0xFFFFD166);
    speed = 220 + _random.nextDouble() * 180;
  }

  @override
  Future<void> onLoad() async {
    final margin = radius * 2;
    position = Vector2(
      margin + _random.nextDouble() * (game.size.x - margin * 2),
      -radius,
    );
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Multiply by dt so speed stays consistent regardless of frame rate
    position.y += speed * dt;

    if (position.y - radius > game.size.y) {
      removeFromParent();
      game.loseLife();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerBasket) {
      removeFromParent();
      game.increaseScore();
    }
  }
}
