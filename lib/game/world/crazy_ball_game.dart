import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ¡NUEVO! Importamos el diccionario para los textos que pudieran usarse aquí
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart'; 

import '../components/pipe.dart';
import '../components/coin.dart';
import '../managers/pipe_manager.dart';
import '../../services/sound_manager.dart';

// ==========================================
// MODO DEBUG / DESARROLLADOR
// Cambia a 'false' antes de publicar a producción
const bool kEnableDebugMenu = false;
// ==========================================

enum GameState { menu, ready, playing, gameOver }

String skinIdToFlamePath(String id) {
  if (id == 'ball_default') return 'ball/ball_default.png';
  if (id.startsWith('ball_level_')) return 'ball/level/$id.png';
  if (id.startsWith('ball_common_')) return 'ball/pay/common/$id.png';
  if (id.startsWith('ball_rare_')) return 'ball/pay/rare/$id.png';
  if (id.startsWith('ball_epic_')) return 'ball/pay/epic/$id.png';
  if (id.startsWith('ball_legendary_')) return 'ball/pay/legendary/$id.png';
  if (id.startsWith('ball_champion_')) return 'ball/pay/champion/$id.png';
  return 'ball/ball_default.png';
}

class CrazyBallGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late Ball _ball;
  late PipeManager _pipeManager;

  GameState gameState = GameState.menu;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> showScoreNotifier = ValueNotifier<bool>(false); 
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);

  int consecutiveBounces = 0;
  bool isFeverActive = false;

  bool isInvulnerable = false;
  double invulnerableTimer = 0.0;

  final int feverThreshold = 10;

  String playerSkinId = 'ball_default';
  bool _ballLoaded = false;

  SpriteComponent? _bgComponent;
  String _currentBgName = 'wallpapers/n_1.jpeg';

  @override
  Color backgroundColor() => const Color(0xFF4EC0E9);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.anchor = Anchor.topLeft;

    try {
      _bgComponent = SpriteComponent(sprite: await loadSprite(_currentBgName), size: size);
      camera.backdrop.add(_bgComponent!);
    } catch (e) {
      debugPrint("No se pudo cargar el fondo: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      playerSkinId = prefs.getString('selected_skin') ?? 'ball_default';
    } catch (_) {}

    _pipeManager = PipeManager();
    world.add(_pipeManager);

    _ball = Ball();
    world.add(_ball);
    _ballLoaded = true;

    // Agregar botón Debug si está habilitado
    if (kEnableDebugMenu) {
      camera.viewport.add(DebugButton());
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _bgComponent?.size = size;
  }

  void _updateBackground(String newBgName) async {
    if (_currentBgName == newBgName) return;
    _currentBgName = newBgName;
    try {
      _bgComponent?.sprite = await loadSprite(_currentBgName);
    } catch (e) {
      debugPrint("No se pudo cambiar el fondo: $e");
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isInvulnerable) {
      invulnerableTimer -= dt;
      if (invulnerableTimer <= 0) isInvulnerable = false;
    }
  }

  void updateSkin(String skinId) {
    playerSkinId = skinId;
    if (_ballLoaded) _ball.reloadSprite();
  }

  void resetToMenu() {
    gameState = GameState.menu;
    showScoreNotifier.value = false;
    isFeverActive = false;
    consecutiveBounces = 0;
    isInvulnerable = false;
    _updateBackground('wallpapers/n_1.jpeg'); 
    _pipeManager.clearAll();
    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<FeverTextPop>().forEach((t) => t.removeFromParent());
    world.children.whereType<PipeDebris>().forEach((d) => d.removeFromParent());
  }

  void prepareGame() {
    gameState = GameState.ready;
    showScoreNotifier.value = false;
    scoreNotifier.value = 0;
    consecutiveBounces = 0;
    isFeverActive = false;
    isInvulnerable = false;
    _updateBackground('wallpapers/n_1.jpeg'); 

    _ball.reset(isReadyState: true);
    _pipeManager.reset();

    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<FeverTextPop>().forEach((t) => t.removeFromParent());
    world.children.whereType<PipeDebris>().forEach((d) => d.removeFromParent());
    overlays.add('Ready');
  }

  void startGame() {
    gameState = GameState.playing;
    showScoreNotifier.value = true;
    overlays.remove('Ready');
    _ball.jump();
  }

  void gameOver() {
    if (gameState != GameState.playing) return;
    gameState = GameState.gameOver;
    showScoreNotifier.value = false;
    overlays.add('GameOver');
    SoundManager.instance.sfxMorir();
    SoundManager.instance.vibrate(); 
    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(8, 8),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (kEnableDebugMenu && event.canvasPosition.x < 80 && event.canvasPosition.y < 180) return;

    if (gameState == GameState.ready) startGame();
    else if (gameState == GameState.playing && !_ball.isDead) _ball.jump();
  }

  void onWallHit({required bool hitRightWall, required double ballY}) {
    scoreNotifier.value++;
    consecutiveBounces++;

    int currentScore = scoreNotifier.value;
    if (currentScore >= 1000) {
      _updateBackground('wallpapers/n_6.jpeg');
    } else if (currentScore >= 500) {
      _updateBackground('wallpapers/n_5.jpeg');
    } else if (currentScore >= 300) {
      _updateBackground('wallpapers/n_4.jpeg');
    } else if (currentScore >= 150) {
      _updateBackground('wallpapers/n_3.jpeg');
    } else if (currentScore >= 60) {
      _updateBackground('wallpapers/n_2.jpeg');
    }

    if (consecutiveBounces >= feverThreshold && !isFeverActive) {
      isFeverActive = true;
      _ball.activateFever();
      world.add(FeverTextPop(position: _ball.position.clone()));
      SoundManager.instance.sfxPoder();
    }

    SoundManager.instance.sfxBote();
    _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY);
  }

  void collectCoin(Coin coin) async {
    coin.collect();
    coinsNotifier.value++;
    SoundManager.instance.sfxMoneda();

    final prefs = await SharedPreferences.getInstance();
    int currentCoins = prefs.getInt('coins') ?? 0;
    await prefs.setInt('coins', currentCoins + 1);
  }

  void smashPipe() {
    if (gameState != GameState.playing) return;
    isFeverActive = false;
    consecutiveBounces = 0;
    _ball.deactivateFever();
    SoundManager.instance.sfxDestruccion();

    isInvulnerable = true;
    invulnerableTimer = 0.2;
    scoreNotifier.value += 2;

    for (var p in _pipeManager.currentPipes) {
      p.children.whereType<RectangleHitbox>().forEach((h) => h.removeFromParent());
      
      final centerP = p.position + Vector2(35, p.size.y / 2);
      for(int i = 0; i < 8; i++) {
        world.add(PipeDebris(position: centerP.clone()));
      }

      p.add(MoveEffect.by(Vector2(p.isLeftWall ? -150 : 150, 0), EffectController(duration: 0.2)));
      p.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2), onComplete: () => p.removeFromParent()));
    }
    _pipeManager.currentPipes.clear();

    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(15, 15),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4),
      ),
    );
  }

  // MÉTODOS DEL MENÚ DEBUG (Se dejan los textos originales en español al ser una herramienta de desarrollador)
  void openDebugMenu() {
    if (buildContext == null) return;
    
    paused = true; 
    
    showDialog(
      context: buildContext!,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white, width: 3)),
          title: const Text("🐞 MENÚ DEV (AVENTURA)", style: TextStyle(color: Colors.white, fontFamily: 'Impact', fontSize: 24), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9BE15D), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  int s = scoreNotifier.value;
                  if (s < 60) scoreNotifier.value = 60;
                  else if (s < 150) scoreNotifier.value = 150;
                  else if (s < 300) scoreNotifier.value = 300;
                  else if (s < 500) scoreNotifier.value = 500;
                  else scoreNotifier.value = 1000;

                  s = scoreNotifier.value;
                  if (s >= 1000) _updateBackground('wallpapers/n_6.jpeg');
                  else if (s >= 500) _updateBackground('wallpapers/n_5.jpeg');
                  else if (s >= 300) _updateBackground('wallpapers/n_4.jpeg');
                  else if (s >= 150) _updateBackground('wallpapers/n_3.jpeg');
                  else if (s >= 60) _updateBackground('wallpapers/n_2.jpeg');

                  Navigator.pop(context);
                },
                child: const Text("SALTAR NIVEL (+ PUNTOS)", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  isFeverActive = true;
                  _ball.activateFever();
                  world.add(FeverTextPop(position: _ball.position.clone()));
                  SoundManager.instance.sfxPoder();
                  Navigator.pop(context);
                },
                child: const Text("ACTIVAR PODER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async {
                  coinsNotifier.value += 100;
                  final prefs = await SharedPreferences.getInstance();
                  int currentCoins = prefs.getInt('coins') ?? 0;
                  await prefs.setInt('coins', currentCoins + 100);
                  Navigator.pop(context);
                },
                child: const Text("+100 MONEDAS", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      }
    ).then((_) {
      paused = false; 
    });
  }
}

// ================= BOTÓN DEBUG (UI) =================
class DebugButton extends PositionComponent with TapCallbacks, HasGameRef<CrazyBallGame> {
  late final TextPainter _textPainter;

  DebugButton() : super(position: Vector2(15, 120), size: Vector2(50, 50));

  @override
  Future<void> onLoad() async {
    _textPainter = TextPainter(
      text: const TextSpan(text: "🐞", style: TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = Colors.black87);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    _textPainter.paint(canvas, const Offset(10, 6));
  }

  @override
  void onTapDown(TapDownEvent event) {
    gameRef.openDebugMenu();
  }
}

// ================= BOLA =================
class Ball extends CircleComponent with HasGameRef<CrazyBallGame>, CollisionCallbacks {
  double velocityY = 0.0;
  final double gravity = 1500.0;
  final double jumpForce = -480.0;
  double speedX = 350.0;
  bool isMovingRight = true;
  bool isDead = false;
  final double ballRadius = 18.0;

  bool _inFeverVisuals = false;
  double _feverTimer = 0.0;
  Sprite? _sprite;

  Ball() : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18)));
  }

  Future<void> _loadSprite() async {
    try {
      _sprite = await gameRef.loadSprite(skinIdToFlamePath(gameRef.playerSkinId));
    } catch (_) {
      _sprite = null;
    }
  }

  void reloadSprite() {
    _loadSprite(); 
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != GameState.playing) return;

    if (_inFeverVisuals) {
      _feverTimer += dt;
    }

    velocityY += gravity * dt;
    position.y += velocityY * dt;

    if (isDead) return;

    position.x += (isMovingRight ? speedX : -speedX) * dt;

    if (isMovingRight && position.x >= gameRef.size.x - ballRadius) {
      position.x = gameRef.size.x - ballRadius;
      isMovingRight = false;
      gameRef.onWallHit(hitRightWall: true, ballY: position.y);
    } else if (!isMovingRight && position.x <= ballRadius) {
      position.x = ballRadius;
      isMovingRight = true;
      gameRef.onWallHit(hitRightWall: false, ballY: position.y);
    }

    if (position.y >= gameRef.size.y - ballRadius || position.y <= ballRadius) {
      die();
    }
  }

  void jump() { 
    if (!isDead) velocityY = jumpForce; 
  }

  void die() {
    if (isDead) return;
    isDead = true;
    velocityY = -250.0; 
    gameRef.gameOver();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Coin) {
      gameRef.collectCoin(other);
    } else if (other is Pipe && !isDead) {
      if (gameRef.isFeverActive) {
        gameRef.smashPipe();
      } else if (!gameRef.isInvulnerable) {
        SoundManager.instance.sfxChoque();
        die();
      }
    }
  }

  void activateFever() {
    _inFeverVisuals = true;
    _feverTimer = 0.0;
    add(ScaleEffect.by(Vector2.all(1.2), EffectController(duration: 0.15, alternate: true)));
  }

  void deactivateFever() { _inFeverVisuals = false; }

  void reset({bool isReadyState = false}) {
    position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    velocityY = 0;
    isMovingRight = true;
    isDead = false;
    _inFeverVisuals = false;
    _feverTimer = 0.0;
    scale = Vector2.all(1.0);
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == GameState.menu) return;

    final center = Offset(ballRadius, ballRadius);

    if (_inFeverVisuals) {
      final paint = Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Colors.yellowAccent, Colors.orange, Colors.redAccent],
          stops: [0.1, 0.4, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: ballRadius + 18));

      final path = Path();
      const int points = 12; 
      final double innerRadius = ballRadius + 2;
      final double outerRadius = ballRadius + 18;
      final double angleOffset = _feverTimer * 15.0; 

      for (int i = 0; i < points * 2; i++) {
        double radius = i.isEven ? outerRadius + sin(_feverTimer * 30 + i) * 4 : innerRadius;
        double angle = (i * pi / points) + angleOffset;
        double x = center.dx + cos(angle) * radius;
        double y = center.dy + sin(angle) * radius;
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    if (_sprite != null) {
      _sprite!.render(canvas, position: Vector2.zero(), size: Vector2(ballRadius * 2, ballRadius * 2));
    } else {
      // Fallback
      canvas.drawCircle(
        center, ballRadius,
        Paint()..color = _inFeverVisuals ? Colors.red : const Color(0xFFFF5722),
      );
      canvas.drawCircle(
        center, ballRadius,
        Paint()..color = const Color(0xFF3E1103)..style = PaintingStyle.stroke..strokeWidth = 2,
      );
      double eyeOffsetX = isMovingRight ? 6.0 : -6.0;
      final eyeCenter = Offset(ballRadius + eyeOffsetX, ballRadius - 3);
      canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.white);
      canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(Offset(ballRadius + eyeOffsetX * 1.5, ballRadius - 3), 2.5, Paint()..color = Colors.black);
    }
  }
}

// ================= EFECTO DE ESCOMBROS (DEBRIS) =================
class PipeDebris extends PositionComponent with HasGameRef<CrazyBallGame> {
  late Vector2 velocity;
  final double gravity = 1500;
  late double rotationSpeed;
  final Random _rnd = Random();

  PipeDebris({required Vector2 position}) : super(position: position, size: Vector2(18, 18), anchor: Anchor.center) {
    velocity = Vector2((_rnd.nextDouble() - 0.5) * 800, -_rnd.nextDouble() * 600 - 200);
    rotationSpeed = (_rnd.nextDouble() - 0.5) * 15;
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocity.y += gravity * dt;
    position += velocity * dt;
    angle += rotationSpeed * dt;
    if (position.y > gameRef.size.y + 50) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final path = Path()
       ..moveTo(0, size.y * 0.4)
       ..lineTo(size.x * 0.4, 0)
       ..lineTo(size.x, size.y * 0.3)
       ..lineTo(size.x * 0.8, size.y)
       ..lineTo(size.x * 0.2, size.y)
       ..close();
    
    canvas.drawPath(path, Paint()..color = const Color(0xFF5A9B25));
    canvas.drawPath(path, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final innerPath = Path()
       ..moveTo(size.x * 0.2, size.y * 0.5)
       ..lineTo(size.x * 0.5, size.y * 0.2)
       ..lineTo(size.x * 0.8, size.y * 0.5)
       ..lineTo(size.x * 0.5, size.y * 0.8)
       ..close();
    canvas.drawPath(innerPath, Paint()..color = Colors.grey[600]!);
  }
}

// ================= TEXTO ANIMADO DEL FEVER =================
// Este texto no requiere traducción, "FEVER" es universal y funciona como nombre propio de la mecánica.
class FeverTextPop extends TextComponent with HasGameRef<CrazyBallGame> {
  FeverTextPop({required Vector2 position}) : super(
    text: "¡FEVER!", position: position, anchor: Anchor.center,
    textRenderer: TextPaint(
      style: const TextStyle(
        color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold,
        fontFamily: 'Impact',
        shadows: [
          Shadow(color: Colors.white, blurRadius: 4),
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
    ),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(MoveEffect.by(Vector2(0, -80), EffectController(duration: 0.8, curve: Curves.easeOut)));
    add(ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2, alternate: true)));
    add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2, startDelay: 0.6), onComplete: () => removeFromParent()));
  }
}