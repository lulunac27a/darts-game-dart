import 'dart:io';
import 'dart:math';

void main() {
  final random = Random();
  int score = 301;
  int round = 1;

  // Standard clockwise dartboard layout
  const board = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
    3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  print('🎯 WELCOME TO 301 DARTS!');
  print('Goal: Reach exactly 0 points. Going below 0 busts your round.\n');

  while (score > 0) {
    print('--- Round $round | Current Score: $score ---');
    int roundStartScore = score;

    for (int throwNum = 1; throwNum <= 3; throwNum++) {
      stdout.write(
        'Throw $throwNum/3 - Aim at (1-20, 25 for Bull, or "q" to quit): ',
      );
      String? input = stdin.readLineSync()?.trim().toLowerCase();

      if (input == 'q') {
        print('Game exited. Final score: $score');
        return;
      }

      int? target = int.tryParse(input ?? '');
      if (target == null || ((target < 1 || target > 20) && target != 25)) {
        print('Invalid target! Enter a number from 1 to 20, or 25 for Bull.');
        throwNum--;
        continue;
      }

      // Simulate throw accuracy and ring multiplier
      int points = calculateThrow(target, board, random);
      score -= points;

      if (score == 0) {
        print('🏆 BULLSEYE FINISH! You reached 0 in $round rounds!');
        return;
      } else if (score < 0) {
        print('💥 BUST! Score went below 0. Reverting to $roundStartScore.\n');
        score = roundStartScore;
        break;
      } else {
        print('Score remaining: $score\n');
      }
    }
    round++;
  }
}

int calculateThrow(int target, List<int> board, Random random) {
  int accuracy = random.nextInt(100);

  // Aiming for the Bullseye (25 / 50)
  if (target == 25) {
    if (accuracy < 15) {
      print('🎯 DOUBLE BULL! (50 points)');
      return 50;
    } else if (accuracy < 45) {
      print('⭕ Single Bull! (25 points)');
      return 25;
    } else {
      int stray = board[random.nextInt(board.length)];
      print('💨 Missed the bull! Hit Single $stray ($stray points)');
      return stray;
    }
  }

  // Aiming for numbers 1-20
  int targetIndex = board.indexOf(target);
  int hitNumber = target;

  // 30% chance to drift to an adjacent wedge on the dartboard
  if (accuracy >= 70) {
    int offset = random.nextBool() ? 1 : -1;
    hitNumber = board[(targetIndex + offset + board.length) % board.length];
  }

  // Determine multiplier (Single, Double, or Triple)
  int ringRoll = random.nextInt(100);
  if (ringRoll < 10) {
    print('🔥 TRIPLE $hitNumber! (${hitNumber * 3} points)');
    return hitNumber * 3;
  } else if (ringRoll < 25) {
    print('✨ DOUBLE $hitNumber! (${hitNumber * 2} points)');
    return hitNumber * 2;
  } else if (ringRoll < 95) {
    print('📍 Single $hitNumber ($hitNumber points)');
    return hitNumber;
  } else {
    print('❌ Missed the board completely! (0 points)');
    return 0;
  }
}
