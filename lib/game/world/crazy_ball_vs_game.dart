import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart'; 
import 'package:flutter/material.dart';

enum VsGameState { menu, ready, playing, gameOver, victory }

class CrazyBallVsGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late VsBall _playerBall;
  late List<VsBotBall> _bots;
  late VsPipeManager _pipeManager;
  
  VsGameState gameState = VsGameState.menu;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> botsAliveNotifier = ValueNotifier<int>(5);
  
  // NUEVO: Añadimos el notificador de monedas para el modo VS
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);
  
  bool isFeverActive = false;
  int consecutiveBounces = 0;
  bool isInvulnerable = false;
  double invulnerableTimer = 0.0;
  double _wallHitCooldown = 0.0; 

  double targetGapY = 0;

  @override
  Color backgroundColor() => const Color(0xFF4EC0E9); 

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.anchor = Anchor.topLeft;

    _pipeManager = VsPipeManager();
    world.add(_pipeManager);

    _playerBall = VsBall();
    world.add(_playerBall);

    _bots = List.generate(5, (index) => VsBotBall(index: index));
    world.addAll(_bots);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isInvulnerable) {
      invulnerableTimer -= dt;
      if (invulnerableTimer <= 0) isInvulnerable = false;
    }
    if (_wallHitCooldown > 0) _wallHitCooldown -= dt;
  }

  void resetToMenu() {
    gameState = VsGameState.menu;
    _pipeManager.clearAll();
    world.children.whereType<VsCoin>().forEach((c) => c.removeFromParent());
    world.children.whereType<VsFeverTextPop>().forEach((t) => t.removeFromParent());
  }

  void prepareGame() {
    gameState = VsGameState.ready;
    scoreNotifier.value = 0;
    consecutiveBounces = 0;
    botsAliveNotifier.value = 5;
    isFeverActive = false;
    isInvulnerable = false;
    targetGapY = size.y / 2; 
    
    _pipeManager.reset(); 
    world.children.whereType<VsCoin>().forEach((c) => c.removeFromParent());
    world.children.whereType<VsFeverTextPop>().forEach((t) => t.removeFromParent());
    
    double startY = size.y / 2;
    double startX = size.x / 2;
    
    _playerBall.reset(Vector2(startX, startY));
    for (int i = 0; i < _bots.length; i++) {
      _bots[i].resetBot(Vector2(startX - 25 - (i * 12), startY + 25 + (i * 15)));
    }

    overlays.add('Ready'); 
  }

  void startGame() {
    gameState = VsGameState.playing;
    overlays.remove('Ready');
    _playerBall.jump(); 
    for (var bot in _bots) {
      bot.jump();
    }
  }

  void gameOver() {
    if (gameState != VsGameState.playing) return;
    gameState = VsGameState.gameOver; 
    overlays.add('GameOver');
    camera.viewfinder.add(MoveEffect.by(Vector2(8, 8), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3)));
  }

  void victory() {
    if (gameState != VsGameState.playing) return;
    gameState = VsGameState.victory;
    overlays.add('Victory');
  }

  void onBotDied() {
    botsAliveNotifier.value--;
    if (botsAliveNotifier.value <= 0 && gameState == VsGameState.playing) {
      victory(); 
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == VsGameState.ready) startGame();
    else if (gameState == VsGameState.playing) _playerBall.jump();
  }

  void onWallHit({required bool hitRightWall, required double ballY, required bool isPlayer}) {
    if (isPlayer) {
      scoreNotifier.value++; 
      consecutiveBounces++;
      if (consecutiveBounces >= 10 && !isFeverActive) {
        isFeverActive = true;
        _playerBall.activateFever();
        world.add(VsFeverTextPop(position: _playerBall.position.clone()));
      }
      _wallHitCooldown = 0.3; 
      _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY); 
    } else {
      if ((gameState == VsGameState.gameOver || gameState == VsGameState.victory) && _wallHitCooldown <= 0) {
        _wallHitCooldown = 0.3; 
        _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY); 
      }
    }
  }

  // NUEVO: Método de recolección de monedas
  void collectCoin(VsCoin coin) {
    coin.collect();
    coinsNotifier.value++;
  }

  void smashPipe() {
    isFeverActive = false; 
    consecutiveBounces = 0;
    _playerBall.deactivateFever();
    
    isInvulnerable = true;
    invulnerableTimer = 0.2; 
    scoreNotifier.value += 2; 
    
    for (var p in _pipeManager.currentPipes) {
      p.children.whereType<RectangleHitbox>().forEach((h) => h.removeFromParent());
      p.add(MoveEffect.by(Vector2(p.isLeft ? -150 : 150, 0), EffectController(duration: 0.2)));
      p.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2), onComplete: () => p.removeFromParent()));
    }
    _pipeManager.currentPipes.clear();
    camera.viewfinder.add(MoveEffect.by(Vector2(15, 15), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4)));
  }
}

// ================= JUGADOR (VS) =================
class VsBall extends CircleComponent with HasGameRef<CrazyBallVsGame>, CollisionCallbacks {
  double velocityY = 0.0;
  final double gravity = 1500.0; 
  final double jumpForce = -480.0; 
  double speedX = 350.0; 
  bool isMovingRight = true;
  bool isDead = false;
  final double ballRadius = 18.0;
  bool _inFeverVisuals = false;

  VsBall() : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad(); 
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18))); 
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState == VsGameState.menu || gameRef.gameState == VsGameState.ready) return;

    velocityY += gravity * dt;
    position.y += velocityY * dt;
    
    if (isDead) return; 
    position.x += (isMovingRight ? speedX : -speedX) * dt;

    if (isMovingRight && position.x >= gameRef.size.x - ballRadius) {
      position.x = gameRef.size.x - ballRadius; 
      isMovingRight = false; 
      gameRef.onWallHit(hitRightWall: true, ballY: position.y, isPlayer: true); 
    } else if (!isMovingRight && position.x <= ballRadius) {
      position.x = ballRadius; 
      isMovingRight = true; 
      gameRef.onWallHit(hitRightWall: false, ballY: position.y, isPlayer: true); 
    }

    if (position.y >= gameRef.size.y - ballRadius || position.y <= ballRadius) die();
  }

  void jump() { if (!isDead) velocityY = jumpForce; }

  void die() {
    if (isDead) return;
    isDead = true;
    gameRef.gameOver();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    // NUEVO: Lógica de recolección de monedas
    if (other is VsCoin) {
      gameRef.collectCoin(other);
    } else if (other is VsPipe && !isDead) {
      if (gameRef.isFeverActive) gameRef.smashPipe(); 
      else if (!gameRef.isInvulnerable) die();
    }
  }

  void activateFever() { 
    _inFeverVisuals = true; 
    add(ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.15, alternate: true)));
  }
  
  void deactivateFever() { _inFeverVisuals = false; }

  void reset(Vector2 startPos) {
    position = startPos; 
    velocityY = 0;
    isMovingRight = true; 
    isDead = false;
    _inFeverVisuals = false;
    scale = Vector2.all(1.0); 
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == VsGameState.menu) return;
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

// ================= IA DEL BOT =================
class VsBotBall extends CircleComponent with HasGameRef<CrazyBallVsGame>, CollisionCallbacks {
  final int index;
  double velocityY = 0.0;
  final double gravity = 1500.0; 
  final double jumpForce = -480.0; 
  double speedX = 350.0; 
  bool isMovingRight = true;
  bool isDead = false;
  
  final Random _random = Random();
  double _reactionDelay = 0; 
  double _skillLevel = 1.0; 
  double _offsetNoise = 0.0; 

  VsBotBall({required this.index}) : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad(); 
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18))); 
  }

  void resetBot(Vector2 startPos) {
    position = startPos;
    velocityY = 0;
    isMovingRight = true;
    isDead = false;
    _skillLevel = 0.7 + (_random.nextDouble() * 0.3); 
    _offsetNoise = (_random.nextDouble() * 2 - 1) * 30; 
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState == VsGameState.menu || gameRef.gameState == VsGameState.ready) return;

    velocityY += gravity * dt;
    position.y += velocityY * dt;
    
    if (isDead) return;

    position.x += (isMovingRight ? speedX : -speedX) * dt;

    double actualTarget = gameRef.targetGapY;
    
    if (!gameRef._playerBall.isDead) {
      actualTarget = (actualTarget * 0.6) + (gameRef._playerBall.position.y * 0.4);
    }
    
    double noisyTarget = actualTarget + _offsetNoise;

    if (velocityY > 0 && position.y > noisyTarget) {
      _reactionDelay -= dt;
      if (_reactionDelay <= 0) {
        jump();
        _reactionDelay = 0.05 + ((1.0 - _skillLevel) * 0.2);
        _offsetNoise = (_random.nextDouble() * 2 - 1) * (30 + ((1.0 - _skillLevel) * 60));
      }
    } else if (velocityY < 0) {
      _reactionDelay = 0.1;
    }

    if (isMovingRight && position.x >= gameRef.size.x - radius) {
      position.x = gameRef.size.x - radius; 
      isMovingRight = false; 
      gameRef.onWallHit(hitRightWall: true, ballY: position.y, isPlayer: false);
    } else if (!isMovingRight && position.x <= radius) {
      position.x = radius; 
      isMovingRight = true; 
      gameRef.onWallHit(hitRightWall: false, ballY: position.y, isPlayer: false);
    }

    if (position.y >= gameRef.size.y + radius || position.y <= -radius) die();
  }

  void jump() { if (!isDead) velocityY = jumpForce; }

  void die() {
    if (isDead) return;
    isDead = true;
    gameRef.onBotDied();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is VsPipe && !isDead) {
      die();
      velocityY = 0; 
    }
    // Nota: Los bots ignoran las monedas para no robártelas y ser más justos
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == VsGameState.menu) return;
    super.render(canvas);
    final center = Offset(radius, radius);
    
    Color botColor = isDead ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.3);
    canvas.drawCircle(center, radius, Paint()..color = botColor);
    canvas.drawCircle(center, radius, Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

// ================= GESTOR DE TUBOS (VS) =================
enum VsPipePattern { double, single }

class VsPipeManager extends Component with HasGameRef<CrazyBallVsGame> {
  final Random random = Random();
  List<VsPipe> currentPipes = [];

  void spawnPipes({required bool onLeftWall, bool isFirst = false, double? ballY}) {
    for (var pipe in currentPipes) { pipe.slideOut(); }
    currentPipes.clear();

    final double screenHeight = gameRef.size.y;
    VsPipePattern pattern = isFirst ? VsPipePattern.double : (random.nextInt(100) < 70 ? VsPipePattern.double : VsPipePattern.single);

    if (pattern == VsPipePattern.double) {
      double center = (isFirst || ballY == null) ? screenHeight / 2 : (ballY + (random.nextDouble() * 2 - 1) * 120.0).clamp(200.0, screenHeight - 200.0);
      
      gameRef.targetGapY = center; 
      
      _addPipe(VsPipe(yPos: 0, height: center - 115, isLeft: onLeftWall, bottomCap: true));
      _addPipe(VsPipe(yPos: center + 115, height: screenHeight, isLeft: onLeftWall, topCap: true));

      // NUEVO: Probabilidad de Moneda (40%)
      if (!isFirst && random.nextInt(100) < 40) {
        final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
        gameRef.world.add(VsCoin(position: Vector2(coinX, center)));
      }

    } else {
      double obstacleHeight = screenHeight * 0.55;
      bool isTop = (ballY ?? screenHeight / 2) < screenHeight / 2;
      
      gameRef.targetGapY = isTop ? screenHeight - 150 : 150; 
      
      _addPipe(VsPipe(yPos: isTop ? 0 : screenHeight - obstacleHeight, height: obstacleHeight, isLeft: onLeftWall, bottomCap: isTop, topCap: !isTop));

      // NUEVO: Probabilidad de Moneda en hueco simple (50%)
      if (random.nextBool()) {
        final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
        double coinY = isTop ? screenHeight - 120 : 120;
        gameRef.world.add(VsCoin(position: Vector2(coinX, coinY)));
      }
    }
  }

  void _addPipe(VsPipe pipe) {
    currentPipes.add(pipe);
    gameRef.world.add(pipe);
  }

  void clearAll() {
    for (var pipe in currentPipes) pipe.removeFromParent();
    currentPipes.clear();
  }

  void reset() {
    clearAll();
    spawnPipes(onLeftWall: false, isFirst: true); 
  }
}

// ================= MONEDA (VS) =================
class VsCoin extends CircleComponent with HasGameRef<CrazyBallVsGame> {
  final double coinRadius = 12.0;

  VsCoin({required Vector2 position}) : super(radius: 12.0, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(radius: coinRadius, isSolid: true));
    add(MoveEffect.by(
      Vector2(0, -8),
      EffectController(duration: 0.6, alternate: true, infinite: true, curve: Curves.easeInOut),
    ));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(coinRadius, coinRadius);
    
    canvas.drawCircle(center, coinRadius + 2, Paint()..color = const Color(0x66FFD700)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(center, coinRadius, Paint()..color = const Color(0xFFFFD700));
    canvas.drawCircle(center, coinRadius - 2, Paint()..color = const Color(0xFFF57F17)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawRect(Rect.fromCenter(center: center, width: 4, height: 10), Paint()..color = Colors.white70);
  }

  void collect() {
    add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.15), onComplete: () => removeFromParent()));
  }
}

// ================= TUBO (VS) =================
class VsPipe extends PositionComponent with HasGameRef<CrazyBallVsGame> {
  final bool isLeft;
  final bool topCap;
  final bool bottomCap;

  VsPipe({required double yPos, required double height, required this.isLeft, this.topCap = false, this.bottomCap = false}) 
      : super(position: Vector2(0, yPos), size: Vector2(70, height));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position.x = isLeft ? -70 : gameRef.size.x;
    add(MoveEffect.to(Vector2(isLeft ? 0 : gameRef.size.x - 70, position.y), EffectController(duration: 0.25, curve: Curves.easeOutCubic)));
    add(RectangleHitbox(position: Vector2(0, 0), size: Vector2(70, size.y)));
  }

  void slideOut() {
    add(MoveEffect.to(Vector2(isLeft ? -70 : gameRef.size.x, position.y), EffectController(duration: 0.2, curve: Curves.easeIn), onComplete: () => removeFromParent()));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final Gradient grad = LinearGradient(colors: const [Color(0xFF81C748), Color(0xFFC4F088), Color(0xFF5A9B25)], stops: const [0.0, 0.3, 1.0]);
    final Paint border = Paint()..color = const Color(0xFF2C4A12)..style = PaintingStyle.stroke..strokeWidth = 3;
    
    final Rect bRect = Rect.fromLTRB(5, topCap ? 28 : 0, 65, size.y - (bottomCap ? 28 : 0));
    canvas.drawRect(bRect, Paint()..shader = grad.createShader(bRect));
    canvas.drawRect(bRect, border);

    if (topCap) _drawCap(canvas, grad, border, 0);
    if (bottomCap) _drawCap(canvas, grad, border, size.y - 28);
  }

  void _drawCap(Canvas canvas, Gradient grad, Paint border, double y) {
    final RRect cap = RRect.fromRectAndRadius(Rect.fromLTWH(0, y, 70, 28), const Radius.circular(4));
    canvas.drawRRect(cap, Paint()..shader = grad.createShader(cap.outerRect));
    canvas.drawRRect(cap, border);
  }
}

// ================= TEXTO ANIMADO DEL FEVER (VS) =================
class VsFeverTextPop extends TextComponent with HasGameRef<CrazyBallVsGame> {
  VsFeverTextPop({required Vector2 position}) : super(
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