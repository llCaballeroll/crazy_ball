import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart'; 
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../components/pipe.dart'; 
import '../components/coin.dart';
import '../managers/pipe_manager.dart';

enum GameState { menu, ready, playing, gameOver }

class CrazyBallGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late Ball _ball;
  late PipeManager _pipeManager;
  
  GameState gameState = GameState.menu;
  
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);
  
  int consecutiveBounces = 0;
  bool isFeverActive = false;
  
  bool isInvulnerable = false;
  double invulnerableTimer = 0.0;

  final int feverThreshold = 10; 

  @override
  Color backgroundColor() => const Color(0xFF4EC0E9); 

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.anchor = Anchor.topLeft;

    try { await FlameAudio.audioCache.load('sound.mp3'); } catch (_) {}

    _pipeManager = PipeManager();
    world.add(_pipeManager);

    _ball = Ball();
    world.add(_ball);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isInvulnerable) {
      invulnerableTimer -= dt;
      if (invulnerableTimer <= 0) {
        isInvulnerable = false;
      }
    }
  }

  // MÉTODO NUEVO: Devuelve el lienzo a la normalidad absoluta
  void resetToMenu() {
    gameState = GameState.menu;
    _pipeManager.clearAll();
    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<FeverTextPop>().forEach((t) => t.removeFromParent());
  }

  void prepareGame() {
    gameState = GameState.ready;
    scoreNotifier.value = 0;
    consecutiveBounces = 0;
    isFeverActive = false;
    isInvulnerable = false;
    
    _ball.reset(isReadyState: true);
    _pipeManager.reset(); 
    
    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<FeverTextPop>().forEach((t) => t.removeFromParent());
    overlays.add('Ready'); 
  }

  void startGame() {
    gameState = GameState.playing;
    overlays.remove('Ready');
    _ball.jump(); 
  }

  void gameOver() {
    if (gameState != GameState.playing) return;
    gameState = GameState.gameOver;
    overlays.add('GameOver');
    camera.viewfinder.add(
      MoveEffect.by(Vector2(8, 8), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3))
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == GameState.ready) startGame();
    else if (gameState == GameState.playing) _ball.jump();
  }

  void onWallHit({required bool hitRightWall, required double ballY}) {
    scoreNotifier.value++; 
    consecutiveBounces++;

    if (consecutiveBounces >= feverThreshold && !isFeverActive) {
      isFeverActive = true;
      _ball.activateFever();
      world.add(FeverTextPop(position: _ball.position.clone()));
    }

    try { FlameAudio.play('sound.mp3', volume: 0.5); } catch (_) {}
    _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY); 
  }

  void collectCoin(Coin coin) {
    coin.collect();
    coinsNotifier.value++;
  }

  void smashPipe() {
    isFeverActive = false; 
    consecutiveBounces = 0;
    _ball.deactivateFever();
    
    isInvulnerable = true;
    invulnerableTimer = 0.2; 
    scoreNotifier.value += 2; 
    
    for (var p in _pipeManager.currentPipes) {
      p.children.whereType<RectangleHitbox>().forEach((h) => h.removeFromParent());
      p.add(MoveEffect.by(Vector2(p.isLeftWall ? -150 : 150, 0), EffectController(duration: 0.2)));
      p.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2), onComplete: () => p.removeFromParent()));
    }
    _pipeManager.currentPipes.clear();
    
    camera.viewfinder.add(MoveEffect.by(Vector2(15, 15), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4)));
  }
}

// ================= BOLA =================
class Ball extends CircleComponent with HasGameRef<CrazyBallGame>, CollisionCallbacks {
  double velocityY = 0.0;
  final double gravity = 1500.0; 
  final double jumpForce = -480.0; 
  double speedX = 350.0; 
  bool isMovingRight = true;
  final double ballRadius = 18.0;
  
  bool _inFeverVisuals = false;

  Ball() : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad(); 
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18))); 
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != GameState.playing) return;

    velocityY += gravity * dt;
    position.y += velocityY * dt;
    position.x += (isMovingRight ? speedX : -speedX) * dt;

    if (isMovingRight && position.x >= gameRef.size.x - ballRadius) {
      position.x = gameRef.size.x - ballRadius; 
      isMovingRight = false; 
      gameRef.onWallHit(hitRightWall: true, ballY: position.y); 
    } 
    else if (!isMovingRight && position.x <= ballRadius) {
      position.x = ballRadius; 
      isMovingRight = true; 
      gameRef.onWallHit(hitRightWall: false, ballY: position.y); 
    }

    if (position.y >= gameRef.size.y - ballRadius || position.y <= ballRadius) {
      gameRef.gameOver();
    }
  }

  void jump() { velocityY = jumpForce; }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is Coin) {
      gameRef.collectCoin(other);
    } 
    else if (other is Pipe) {
      if (gameRef.isFeverActive) {
        gameRef.smashPipe(); 
      } else if (!gameRef.isInvulnerable) {
        gameRef.gameOver();
      }
    }
  }

  void activateFever() { 
    _inFeverVisuals = true; 
    add(ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.15, alternate: true)));
  }
  
  void deactivateFever() { _inFeverVisuals = false; }

  void reset({bool isReadyState = false}) {
    position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2); 
    velocityY = 0;
    isMovingRight = true; 
    _inFeverVisuals = false;
    scale = Vector2.all(1.0); 
  }

  @override
  void render(Canvas canvas) {
    // FIX VISUAL: Si estamos en el menú, Flame NO dibuja esta bola, 
    // permitiendo que la bola de Flutter se luzca sola.
    if (gameRef.gameState == GameState.menu) return;

    super.render(canvas);
    final center = Offset(ballRadius, ballRadius);
    
    if (_inFeverVisuals) {
      canvas.drawCircle(center, ballRadius + 6, Paint()..color = Colors.orangeAccent.withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(center, ballRadius, Paint()..color = Colors.red);
    } else {
      canvas.drawCircle(center, ballRadius, Paint()..color = const Color(0xFFFF5722));
    }
    
    canvas.drawCircle(center, ballRadius, Paint()..color = const Color(0xFF3E1103)..style = PaintingStyle.stroke..strokeWidth = 2);

    double eyeOffsetX = isMovingRight ? 6.0 : -6.0;
    final eyeCenter = Offset(ballRadius + eyeOffsetX, ballRadius - 3);
    
    canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.white);
    canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(ballRadius + eyeOffsetX * 1.5, ballRadius - 3), 2.5, Paint()..color = Colors.black);
  }
}

// ================= TEXTO ANIMADO DEL FEVER =================
class FeverTextPop extends TextComponent with HasGameRef<CrazyBallGame> {
  FeverTextPop({required Vector2 position}) : super(
    text: "¡FEVER!", position: position, anchor: Anchor.center,
    textRenderer: TextPaint(style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Impact', shadows: [Shadow(color: Colors.white, blurRadius: 4), Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))]))
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(MoveEffect.by(Vector2(0, -80), EffectController(duration: 0.8, curve: Curves.easeOut)));
    add(ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2, alternate: true)));
    add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2, startDelay: 0.6), onComplete: () => removeFromParent()));
  }
}