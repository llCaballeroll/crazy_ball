import 'dart:math';
import 'package:flame/components.dart';
import '../components/pipe.dart';
import '../components/coin.dart'; 
import '../world/crazy_ball_game.dart';

enum PipePattern { double, triple, single }

class PipeManager extends Component with HasGameRef<CrazyBallGame> {
  final Random random = Random();
  final double gapSizeDouble = 230.0; 
  final double gapSizeTriple = 140.0; 
  
  List<Pipe> currentPipes = [];

  void spawnPipes({required bool onLeftWall, bool isFirst = false, double? ballY}) {
    for (var pipe in currentPipes) {
      pipe.slideOut();
    }
    currentPipes.clear();

    final double screenHeight = gameRef.size.y;
    PipePattern pattern;

    if (isFirst) {
      pattern = PipePattern.double;
    } else {
      int randVar = random.nextInt(100);
      if (randVar < 60) pattern = PipePattern.double;
      else if (randVar < 85) pattern = PipePattern.triple;
      else pattern = PipePattern.single;
    }

    switch (pattern) {
      case PipePattern.double:
        _spawnDoublePipes(screenHeight, onLeftWall, isFirst, ballY);
        break;
      case PipePattern.triple:
        _spawnTriplePipes(screenHeight, onLeftWall, ballY);
        break;
      case PipePattern.single:
        _spawnSinglePipes(screenHeight, onLeftWall, ballY);
        break;
    }
  }

  void _addAndRegisterPipe(Pipe pipe) {
    currentPipes.add(pipe);
    gameRef.world.add(pipe);
  }

  void _spawnDoublePipes(double screenHeight, bool onLeftWall, bool isFirst, double? ballY) {
    double center;

    if (isFirst || ballY == null) {
      center = screenHeight / 2;
    } else {
      double delta = (random.nextDouble() * 2 - 1) * 120.0; 
      center = ballY + delta;

      final double minSafeCenter = gapSizeDouble / 2 + 80;
      final double maxSafeCenter = screenHeight - minSafeCenter;
      center = center.clamp(minSafeCenter, maxSafeCenter);
    }

    _addAndRegisterPipe(Pipe(yPosition: 0, height: center - gapSizeDouble / 2, isLeftWall: onLeftWall, hasBottomCap: true));
    _addAndRegisterPipe(Pipe(yPosition: center + gapSizeDouble / 2, height: screenHeight - (center + gapSizeDouble / 2), isLeftWall: onLeftWall, hasTopCap: true));

    if (!isFirst && random.nextInt(100) < 40) {
      final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
      gameRef.world.add(Coin(position: Vector2(coinX, center)));
    }
  }

  void _spawnTriplePipes(double screenHeight, bool onLeftWall, double? ballY) {
    double safeBallY = ballY ?? (screenHeight / 2);
    double topCenter;
    double bottomCenter;

    if (safeBallY < screenHeight / 2) {
      topCenter = (safeBallY + (random.nextDouble() * 80 - 40)).clamp(gapSizeTriple / 2 + 80, screenHeight / 2 - 40);
      bottomCenter = topCenter + gapSizeTriple + 150; 
      bottomCenter = bottomCenter.clamp(topCenter + gapSizeTriple + 80, screenHeight - gapSizeTriple / 2 - 80);
    } else {
      bottomCenter = (safeBallY + (random.nextDouble() * 80 - 40)).clamp(screenHeight / 2 + 40, screenHeight - gapSizeTriple / 2 - 80);
      topCenter = bottomCenter - gapSizeTriple - 150;
      topCenter = topCenter.clamp(gapSizeTriple / 2 + 80, bottomCenter - gapSizeTriple - 80);
    }

    _addAndRegisterPipe(Pipe(yPosition: 0, height: topCenter - gapSizeTriple / 2, isLeftWall: onLeftWall, hasBottomCap: true));
    _addAndRegisterPipe(Pipe(yPosition: topCenter + gapSizeTriple / 2, height: (bottomCenter - gapSizeTriple / 2) - (topCenter + gapSizeTriple / 2), isLeftWall: onLeftWall, hasTopCap: true, hasBottomCap: true));
    _addAndRegisterPipe(Pipe(yPosition: bottomCenter + gapSizeTriple / 2, height: screenHeight - (bottomCenter + gapSizeTriple / 2), isLeftWall: onLeftWall, hasTopCap: true));

    if (random.nextBool()) {
      final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
      double targetCenter = safeBallY < screenHeight / 2 ? bottomCenter : topCenter; 
      gameRef.world.add(Coin(position: Vector2(coinX, targetCenter)));
    }
  }

  void _spawnSinglePipes(double screenHeight, bool onLeftWall, double? ballY) {
    double safeBallY = ballY ?? screenHeight / 2;
    double obstacleHeight = screenHeight * 0.55; 
    bool isTopOnly = safeBallY < screenHeight / 2;

    if (isTopOnly) {
      _addAndRegisterPipe(Pipe(yPosition: 0, height: obstacleHeight, isLeftWall: onLeftWall, hasBottomCap: true));
    } else {
      _addAndRegisterPipe(Pipe(yPosition: screenHeight - obstacleHeight, height: obstacleHeight, isLeftWall: onLeftWall, hasTopCap: true));
    }

    if (random.nextBool()) {
      final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
      double coinY = isTopOnly ? screenHeight - 120 : 120;
      gameRef.world.add(Coin(position: Vector2(coinX, coinY)));
    }
  }

  // MÉTODO NUEVO: Limpia el tablero sin generar nuevos obstáculos
  void clearAll() {
    for (var pipe in currentPipes) {
      pipe.removeFromParent();
    }
    currentPipes.clear();
  }

  void reset() {
    clearAll();
    spawnPipes(onLeftWall: false, isFirst: true); 
  }
}