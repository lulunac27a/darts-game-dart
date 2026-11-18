import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const TargetGameApp());
}

class TargetGameApp extends StatelessWidget {
  const TargetGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random _random = Random();
  Timer? _gameTimer;

  int _score = 0;
  int _timeLeft = 20;
  bool _isPlaying = false;

  // Normalized coordinates (0.0 to 1.0)
  double _targetX = 0.5;
  double _targetY = 0.5;

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 20;
      _isPlaying = true;
      _moveTarget();
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 1) {
          _timeLeft--;
        } else {
          _timeLeft = 0;
          _isPlaying = false;
          timer.cancel();
        }
      });
    });
  }

  void _moveTarget() {
    // Keep target away from the extreme screen edges
    _targetX = 0.1 + _random.nextDouble() * 0.8;
    _targetY = 0.15 + _random.nextDouble() * 0.7;
  }

  void _onTargetTapped() {
    if (!_isPlaying) return;
    setState(() {
      _score++;
      _moveTarget();
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Score: $_score'),
            Text('Time: ${_timeLeft}s'),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_isPlaying)
            Positioned(
              left: _targetX * (screenSize.width - 64),
              top: _targetY * (screenSize.height - 160),
              child: GestureDetector(
                onTapDown: (_) => _onTargetTapped(),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.gps_fixed, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
          if (!_isPlaying)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLeft == 0 ? 'Game Over!' : 'Target Tapper',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  if (_timeLeft == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Final Score: $_score', style: const TextStyle(fontSize: 22)),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _startGame,
                    child: Text(_timeLeft == 0 ? 'Play Again' : 'Start Game'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
