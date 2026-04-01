import 'dart:math';
import 'dart:io'; 
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ¡NUEVO! Importamos el diccionario para localizar los mensajes de estado
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart';

import '../../services/sound_manager.dart';
import '../components/pipe.dart';
import '../components/coin.dart';
import 'crazy_ball_game.dart' show skinIdToFlamePath;

// ==========================================
// MODO DEBUG / DESARROLLADOR
const bool kEnableDebugMenu = false; 
// ==========================================

const List<String> _kBotSkinPaths = [
  'ball/ball_default.png',
  'ball/level/ball_level_01.png',
  'ball/level/ball_level_02.png',
  'ball/level/ball_level_03.png',
  'ball/level/ball_level_04.png',
  'ball/level/ball_level_05.png',
  'ball/level/ball_level_06.png',
  'ball/level/ball_level_07.png',
  'ball/level/ball_level_08.png',
  'ball/level/ball_level_09.png',
  'ball/pay/common/ball_common_01.png',
  'ball/pay/common/ball_common_02.png',
  'ball/pay/common/ball_common_03.png',
  'ball/pay/common/ball_common_04.png',
  'ball/pay/rare/ball_rare_01.png',
  'ball/pay/rare/ball_rare_02.png',
  'ball/pay/rare/ball_rare_03.png',
  'ball/pay/epic/ball_epic_01.png',
  'ball/pay/epic/ball_epic_02.png',
  'ball/pay/epic/ball_epic_03.png',
  'ball/pay/legendary/ball_legendary_01.png',
  'ball/pay/legendary/ball_legendary_02.png',
  'ball/pay/legendary/ball_legendary_03.png',
  'ball/pay/champion/ball_champion_01.png',
  'ball/pay/champion/ball_champion_02.png',
  'ball/pay/champion/ball_champion_03.png',
];

enum VsGameState { menu, matchmaking, ready, playing, spectating, matchEnded }

class CrazyBallVsGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late VsBall _playerBall;
  late List<VsBotBall> _bots;
  late VsPipeManager _pipeManager;

  VsGameState gameState = VsGameState.menu;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> showScoreNotifier = ValueNotifier<bool>(false); 
  final ValueNotifier<int> botsAliveNotifier = ValueNotifier<int>(5);
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);

  // El UI enviará la llave del idioma si no encuentra texto directo
  final ValueNotifier<String> matchmakingMessage = ValueNotifier<String>('connecting');
  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(6); 

  List<int> _deathOrderIds = [];
  Map<int, String> _participantSkins = {};
  List<String> finalRankingSkins = [];
  bool didPlayerWin = false;

  bool isFeverActive = false;
  int consecutiveBounces = 0;
  bool isInvulnerable = false;
  double invulnerableTimer = 0.0;
  double _wallHitCooldown = 0.0;

  double targetGapY = 0;

  String playerSkinId = 'ball_default';
  bool _playerBallLoaded = false;

  SpriteComponent? _bgComponent;

  bool _isOnline = false;
  double _netCheckTimer = 0.0;

  @override
  Color backgroundColor() => const Color(0xFF4EC0E9);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.anchor = Anchor.topLeft;

    try {
      _bgComponent = SpriteComponent(sprite: await loadSprite('wallpapers/n_1.jpeg'), size: size);
      camera.backdrop.add(_bgComponent!);
    } catch (e) {
      debugPrint("No se pudo cargar el fondo VS: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      playerSkinId = prefs.getString('selected_skin') ?? 'ball_default';
    } catch (_) {}

    _pipeManager = VsPipeManager();
    world.add(_pipeManager);

    _playerBall = VsBall();
    world.add(_playerBall);
    _playerBallLoaded = true;

    _bots = List.generate(5, (index) => VsBotBall(index: index));
    world.addAll(_bots);

    if (kEnableDebugMenu) {
      camera.viewport.add(DebugButtonVs());
    }

    _checkInternetSilently();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _bgComponent?.size = size;
  }

  Future<void> _checkInternetSilently() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 1000));
      socket.destroy();
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameState == VsGameState.menu) {
      _netCheckTimer -= dt;
      if (_netCheckTimer <= 0) {
        _netCheckTimer = 3.0; 
        _checkInternetSilently();
      }
    }

    if (isInvulnerable) {
      invulnerableTimer -= dt;
      if (invulnerableTimer <= 0) isInvulnerable = false;
    }
    if (_wallHitCooldown > 0) _wallHitCooldown -= dt;
  }

  void updatePlayerSkin(String skinId) {
    playerSkinId = skinId;
    if (_playerBallLoaded) _playerBall.reloadSprite();
  }

  void resetToMenu() {
    gameState = VsGameState.menu;
    showScoreNotifier.value = false;
    isFeverActive = false;
    consecutiveBounces = 0;
    isInvulnerable = false;
    
    _deathOrderIds.clear();
    _participantSkins.clear();
    finalRankingSkins.clear();

    _pipeManager.clearAll();
    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<VsFeverTextPop>().forEach((t) => t.removeFromParent());
    world.children.whereType<VsPipeDebris>().forEach((d) => d.removeFromParent());
    overlays.remove('Matchmaking');
    overlays.remove('Spectating');
    overlays.remove('Podium');
    _checkInternetSilently(); 
  }

  void prepareGame() async {
    gameState = VsGameState.matchmaking;
    showScoreNotifier.value = false;
    scoreNotifier.value = 0;
    consecutiveBounces = 0;
    botsAliveNotifier.value = 5;
    isFeverActive = false;
    isInvulnerable = false;
    _deathOrderIds.clear();
    finalRankingSkins.clear();
    _participantSkins.clear();
    targetGapY = size.y / 2;

    _pipeManager.reset();
    world.children.whereType<Coin>().forEach((c) => c.removeFromParent());
    world.children.whereType<VsFeverTextPop>().forEach((t) => t.removeFromParent());
    world.children.whereType<VsPipeDebris>().forEach((d) => d.removeFromParent());

    bool hasInternet = _isOnline;
    int playerRank = hasInternet ? Random().nextInt(6) : 0; 
    
    double startY = size.y / 2;
    double startX = size.x / 2 + 20; 
    
    int botIdx = 0;
    List<dynamic> allPlayers = []; 

    _participantSkins[-1] = _playerBall.skinFlamePath; 

    for (int i = 0; i < 6; i++) {
      Vector2 pos = Vector2(startX - (i * 18), startY + (i * 22));
      if (i == playerRank) {
        _playerBall.reset(pos);
        allPlayers.add(_playerBall);
      } else {
        _bots[botIdx].resetBot(pos);
        _participantSkins[botIdx] = _bots[botIdx].skinFlamePath; 
        allPlayers.add(_bots[botIdx]);
        botIdx++;
      }
    }

    overlays.add('Matchmaking');
    countdownNotifier.value = 6; 

    if (!hasInternet) {
      matchmakingMessage.value = 'offlineBots'; // Usa la llave de traducción
      for (var p in allPlayers) {
        p.join(); 
      }
      await Future.delayed(const Duration(seconds: 1)); 
    } else {
      matchmakingMessage.value = 'searchingPlayers'; // Usa la llave de traducción
      allPlayers.shuffle();
      
      for (var p in allPlayers) {
        int delayMs = 200 + Random().nextInt(300); 
        await Future.delayed(Duration(milliseconds: delayMs));
        if (gameState != VsGameState.matchmaking) return; 
        
        p.join();
        SoundManager.instance.sfxMoneda(); 
      }
      
      matchmakingMessage.value = 'roomFull'; // Usa la llave de traducción
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (gameState != VsGameState.matchmaking) return;

    for (int i = 3; i > 0; i--) {
      countdownNotifier.value = i;
      SoundManager.instance.sfxBote(); 
      await Future.delayed(const Duration(seconds: 1));
      if (gameState != VsGameState.matchmaking) return;
    }

    if (gameState == VsGameState.matchmaking) {
      startGame();
    }
  }

  void startGame() {
    gameState = VsGameState.playing;
    showScoreNotifier.value = true;
    overlays.remove('Matchmaking');
    _playerBall.jump();
    for (var bot in _bots) {
      bot.jump();
    }
  }

  void onEntityDied(int id, bool isPlayer) {
    if (gameState == VsGameState.matchEnded || gameState == VsGameState.menu) return;

    _deathOrderIds.add(id);

    if (isPlayer) {
      showScoreNotifier.value = false;
      gameState = VsGameState.spectating;
      overlays.add('Spectating'); 
      SoundManager.instance.sfxMorir();
      SoundManager.instance.vibrate(); 
      camera.viewfinder.add(MoveEffect.by(Vector2(8, 8), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3)));
    } else {
      botsAliveNotifier.value--;
    }

    _checkMatchEnd();
  }

  void _checkMatchEnd() {
    if (_deathOrderIds.length == 5) {
      showScoreNotifier.value = false;
      gameState = VsGameState.matchEnded;
      overlays.remove('Spectating');
      
      int winnerId = _participantSkins.keys.firstWhere((id) => !_deathOrderIds.contains(id));
      didPlayerWin = (winnerId == -1);
      
      finalRankingSkins = [
        _participantSkins[winnerId]!,
        ..._deathOrderIds.reversed.map((id) => _participantSkins[id]!)
      ];
      
      overlays.add('Podium'); 
    }
  }

  void triggerDebugPodium(bool win) {
    gameState = VsGameState.matchEnded;
    showScoreNotifier.value = false;
    didPlayerWin = win;
    scoreNotifier.value = 1500; 
    
    String playerPath = _playerBall.skinFlamePath;
    
    if (win) {
      finalRankingSkins = [
        playerPath, _kBotSkinPaths[1], _kBotSkinPaths[2], _kBotSkinPaths[3], _kBotSkinPaths[4], _kBotSkinPaths[5]
      ];
    } else {
      finalRankingSkins = [
        _kBotSkinPaths[0], _kBotSkinPaths[1], _kBotSkinPaths[2], _kBotSkinPaths[3], playerPath, _kBotSkinPaths[5]
      ];
    }
    
    overlays.remove('Matchmaking');
    overlays.remove('Spectating');
    overlays.add('Podium');
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (kEnableDebugMenu && event.canvasPosition.x < 80 && event.canvasPosition.y < 180) return;
    
    if (gameState == VsGameState.playing && !_playerBall.isDead) {
      _playerBall.jump();
    }
  }

  void onWallHit({required bool hitRightWall, required double ballY, required bool isPlayer}) {
    if (isPlayer) {
      scoreNotifier.value++;
      consecutiveBounces++;
      if (consecutiveBounces >= 10 && !isFeverActive) {
        isFeverActive = true;
        _playerBall.activateFever();
        world.add(VsFeverTextPop(position: _playerBall.position.clone()));
        SoundManager.instance.sfxPoder();
      }
      SoundManager.instance.sfxBote();
      _wallHitCooldown = 0.3;
      _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY);
    } else {
      if ((gameState == VsGameState.spectating || gameState == VsGameState.matchEnded) && _wallHitCooldown <= 0) {
        _wallHitCooldown = 0.3;
        _pipeManager.spawnPipes(onLeftWall: hitRightWall, ballY: ballY);
      }
    }
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
    if (gameState != VsGameState.playing) return;
    isFeverActive = false;
    consecutiveBounces = 0;
    _playerBall.deactivateFever();
    _triggerPipeDestruction();
  }

  void botSmashPipe(VsBotBall bot) {
    if (gameState != VsGameState.playing && gameState != VsGameState.spectating) return;
    bot.deactivateFever();
    _triggerPipeDestruction();
  }

  void _triggerPipeDestruction() {
    SoundManager.instance.sfxDestruccion();
    isInvulnerable = true;
    invulnerableTimer = 0.2;

    for (var p in _pipeManager.currentPipes) {
      p.children.whereType<RectangleHitbox>().forEach((h) => h.removeFromParent());
      
      final centerP = p.position + Vector2(35, p.size.y / 2);
      for(int i = 0; i < 8; i++) {
        world.add(VsPipeDebris(position: centerP.clone()));
      }

      p.add(MoveEffect.by(Vector2(p.isLeftWall ? -150 : 150, 0), EffectController(duration: 0.2)));
      p.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2), onComplete: () => p.removeFromParent()));
    }
    _pipeManager.currentPipes.clear();
    camera.viewfinder.add(MoveEffect.by(Vector2(15, 15), EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4)));
  }

  // MÉTODOS DEL MENÚ DEBUG (No se traducen, son solo para los desarrolladores)
  void openDebugMenu() {
    if (buildContext == null) return;
    paused = true; 
    showDialog(
      context: buildContext!,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white, width: 3)),
          title: const Text("🐞 MENÚ DEV (VS)", style: TextStyle(color: Colors.white, fontFamily: 'Impact', fontSize: 24), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9BE15D), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  triggerDebugPodium(true);
                },
                child: const Text("PROBAR VICTORIA", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  triggerDebugPodium(false); 
                },
                child: const Text("PROBAR DERROTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

class DebugButtonVs extends PositionComponent with TapCallbacks, HasGameRef<CrazyBallVsGame> {
  late final TextPainter _textPainter;

  DebugButtonVs() : super(position: Vector2(15, 120), size: Vector2(50, 50));

  @override
  Future<void> onLoad() async {
    _textPainter = TextPainter(
      text: const TextSpan(text: "🐞", style: TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == VsGameState.menu || gameRef.gameState == VsGameState.matchmaking) return;

    final rect = size.toRect();
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = Colors.black87);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    _textPainter.paint(canvas, const Offset(10, 6));
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameRef.gameState != VsGameState.menu && gameRef.gameState != VsGameState.matchmaking) {
      gameRef.openDebugMenu();
    }
  }
}

class VsBall extends CircleComponent with HasGameRef<CrazyBallVsGame>, CollisionCallbacks {
  double velocityY = 0.0;
  final double gravity = 1500.0;
  final double jumpForce = -480.0;
  double speedX = 350.0;
  bool isMovingRight = true;
  bool isDead = false;
  final double ballRadius = 18.0;
  
  bool _inFeverVisuals = false;
  double _feverTimer = 0.0;
  double _glowTimer = 0.0;
  
  Sprite? _sprite;
  bool hasJoined = false; 

  String get skinFlamePath => skinIdToFlamePath(gameRef.playerSkinId);

  VsBall() : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18)));
  }

  Future<void> _loadSprite() async {
    try {
      _sprite = await gameRef.loadSprite(skinFlamePath);
    } catch (_) {
      _sprite = null;
    }
  }

  void reloadSprite() { _loadSprite(); }

  @override
  void update(double dt) {
    super.update(dt);
    
    _glowTimer += dt;

    if (gameRef.gameState == VsGameState.menu || gameRef.gameState == VsGameState.ready || gameRef.gameState == VsGameState.matchmaking) return;
    if (!hasJoined) return;

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
    velocityY = -250.0; 
    gameRef.onEntityDied(-1, true);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Coin) {
      gameRef.collectCoin(other);
    } else if (other is Pipe && !isDead) {
      if (gameRef.isFeverActive) gameRef.smashPipe();
      else if (!gameRef.isInvulnerable) {
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

  void reset(Vector2 startPos) {
    position = startPos;
    velocityY = 0;
    isMovingRight = true;
    isDead = false;
    _inFeverVisuals = false;
    _feverTimer = 0.0;
    _glowTimer = 0.0;
    hasJoined = false;
    scale = Vector2.zero();
  }

  void join() {
    hasJoined = true;
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3, curve: Curves.easeOutBack)));
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == VsGameState.menu || !hasJoined) return;

    final center = Offset(ballRadius, ballRadius);

    if (!isDead && !_inFeverVisuals) {
      double pulse = 1.0 + 0.15 * sin(_glowTimer * 6);
      canvas.drawCircle(
        center, ballRadius * 1.5 * pulse, Paint()..color = Colors.amberAccent.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0)
      );
      canvas.drawCircle(
        center, ballRadius * 1.25 * pulse, Paint()..color = Colors.white.withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      );
    }

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
      canvas.drawCircle(
        center, ballRadius,
        Paint()..color = _inFeverVisuals ? Colors.red : const Color(0xFFFF5722),
      );
      canvas.drawCircle(center, ballRadius, Paint()..color = const Color(0xFF3E1103)..style = PaintingStyle.stroke..strokeWidth = 2);
      double eyeOffsetX = isMovingRight ? 6.0 : -6.0;
      final eyeCenter = Offset(ballRadius + eyeOffsetX, ballRadius - 3);
      canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.white);
      canvas.drawCircle(eyeCenter, 7, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(Offset(ballRadius + eyeOffsetX * 1.5, ballRadius - 3), 2.5, Paint()..color = Colors.black);
    }
  }
}

class VsBotBall extends CircleComponent with HasGameRef<CrazyBallVsGame>, CollisionCallbacks {
  final int index;
  double velocityY = 0.0;
  final double gravity = 1500.0;
  final double jumpForce = -480.0;
  double speedX = 350.0;
  bool isMovingRight = true;
  bool isDead = false;

  bool hasJoined = false; 

  int consecutiveBounces = 0;
  bool isFeverActive = false;
  bool _inFeverVisuals = false;
  double _feverTimer = 0.0;

  final Random _random = Random();
  double _reactionDelay = 0;
  double _skillLevel = 1.0;
  double _offsetNoise = 0.0;

  Sprite? _sprite;
  late String skinFlamePath;

  VsBotBall({required this.index}) : super(radius: 18, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadRandomSprite();
    add(CircleHitbox(radius: 12, anchor: Anchor.center, position: Vector2(18, 18)));
  }

  Future<void> _loadRandomSprite() async {
    skinFlamePath = _kBotSkinPaths[_random.nextInt(_kBotSkinPaths.length)];
    try {
      _sprite = await gameRef.loadSprite(skinFlamePath);
    } catch (_) {
      _sprite = null;
    }
  }

  void resetBot(Vector2 startPos) {
    position = startPos;
    velocityY = 0;
    isMovingRight = true;
    isDead = false;
    hasJoined = false; 

    consecutiveBounces = 0;
    isFeverActive = false;
    _inFeverVisuals = false;
    _feverTimer = 0.0;

    _skillLevel = 0.7 + (_random.nextDouble() * 0.3);
    _offsetNoise = (_random.nextDouble() * 2 - 1) * 30;
    _loadRandomSprite();
    
    scale = Vector2.zero();
  }

  void join() {
    hasJoined = true;
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3, curve: Curves.easeOutBack)));
  }

  @override
  void update(double dt) {
    super.update(dt); 
    
    if (gameRef.gameState == VsGameState.menu || gameRef.gameState == VsGameState.ready || gameRef.gameState == VsGameState.matchmaking) return;
    if (!hasJoined) return;

    if (_inFeverVisuals) {
      _feverTimer += dt;
    }

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
      _handleWallHit();
      gameRef.onWallHit(hitRightWall: true, ballY: position.y, isPlayer: false);
    } else if (!isMovingRight && position.x <= radius) {
      position.x = radius;
      isMovingRight = true;
      _handleWallHit();
      gameRef.onWallHit(hitRightWall: false, ballY: position.y, isPlayer: false);
    }

    if (position.y >= gameRef.size.y + radius || position.y <= -radius) {
      die();
    }
  }

  void _handleWallHit() {
    consecutiveBounces++;
    if (consecutiveBounces >= 10 && !isFeverActive) {
      isFeverActive = true;
      _inFeverVisuals = true;
      _feverTimer = 0.0;
      add(ScaleEffect.by(Vector2.all(1.2), EffectController(duration: 0.15, alternate: true)));
    }
  }

  void deactivateFever() {
    isFeverActive = false;
    _inFeverVisuals = false;
    consecutiveBounces = 0;
    scale = Vector2.all(1.0);
  }

  void jump() { 
    if (!isDead) velocityY = jumpForce; 
  }

  void die() {
    if (isDead) return;
    isDead = true;
    velocityY = -250.0; 
    gameRef.onEntityDied(index, false);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Pipe && !isDead) {
      if (isFeverActive) {
        gameRef.botSmashPipe(this); 
      } else {
        die();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameState == VsGameState.menu || !hasJoined) return;

    final center = Offset(radius, radius);

    if (_inFeverVisuals) {
      final paint = Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Colors.yellowAccent, Colors.orange, Colors.redAccent],
          stops: [0.1, 0.4, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 18));

      final path = Path();
      const int points = 12;
      final double innerRadius = radius + 2;
      final double outerRadius = radius + 18;
      final double angleOffset = _feverTimer * 15.0; 

      for (int i = 0; i < points * 2; i++) {
        double currentR = i.isEven ? outerRadius + sin(_feverTimer * 30 + i) * 4 : innerRadius;
        double angle = (i * pi / points) + angleOffset;
        double x = center.dx + cos(angle) * currentR;
        double y = center.dy + sin(angle) * currentR;
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    if (_sprite != null) {
      Paint paint = Paint()..color = Colors.white.withOpacity(isDead ? 0.35 : 0.85);
      canvas.saveLayer(Rect.fromCircle(center: center, radius: radius + 2), paint);
      _sprite!.render(canvas, position: Vector2.zero(), size: Vector2(radius * 2, radius * 2));
      canvas.restore();
    } else {
      canvas.drawCircle(center, radius, Paint()..color = isDead ? Colors.grey.withOpacity(0.5) : Colors.black.withOpacity(0.3));
      canvas.drawCircle(center, radius, Paint()..color = isDead ? Colors.black54 : Colors.black.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }
}

enum VsPipePattern { double, single }

class VsPipeManager extends Component with HasGameRef<CrazyBallVsGame> {
  final Random random = Random();
  List<Pipe> currentPipes = [];

  void spawnPipes({required bool onLeftWall, bool isFirst = false, double? ballY}) {
    for (var pipe in currentPipes) { pipe.slideOut(); }
    currentPipes.clear();

    final double screenHeight = gameRef.size.y;
    VsPipePattern pattern = isFirst
        ? VsPipePattern.double
        : (random.nextInt(100) < 70 ? VsPipePattern.double : VsPipePattern.single);

    if (pattern == VsPipePattern.double) {
      double center = (isFirst || ballY == null)
          ? screenHeight / 2
          : (ballY + (random.nextDouble() * 2 - 1) * 120.0).clamp(200.0, screenHeight - 200.0);

      gameRef.targetGapY = center;

      _addPipe(Pipe(yPosition: 0, height: center - 115, isLeftWall: onLeftWall, hasBottomCap: true));
      _addPipe(Pipe(yPosition: center + 115, height: screenHeight, isLeftWall: onLeftWall, hasTopCap: true));

      if (!isFirst && random.nextInt(100) < 40) {
        final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
        gameRef.world.add(Coin(position: Vector2(coinX, center)));
      }
    } else {
      double obstacleHeight = screenHeight * 0.55;
      bool isTop = (ballY ?? screenHeight / 2) < screenHeight / 2;

      gameRef.targetGapY = isTop ? screenHeight - 150 : 150;

      _addPipe(Pipe(
        yPosition: isTop ? 0 : screenHeight - obstacleHeight,
        height: obstacleHeight,
        isLeftWall: onLeftWall,
        hasBottomCap: isTop,
        hasTopCap: !isTop,
      ));

      if (random.nextBool()) {
        final double coinX = onLeftWall ? 35.0 : gameRef.size.x - 35.0;
        double coinY = isTop ? screenHeight - 120 : 120;
        gameRef.world.add(Coin(position: Vector2(coinX, coinY)));
      }
    }
  }

  void _addPipe(Pipe pipe) {
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

class VsPipeDebris extends PositionComponent with HasGameRef<CrazyBallVsGame> {
  late Vector2 velocity;
  final double gravity = 1500;
  late double rotationSpeed;
  final Random _rnd = Random();

  VsPipeDebris({required Vector2 position}) : super(position: position, size: Vector2(18, 18), anchor: Anchor.center) {
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

class VsFeverTextPop extends TextComponent with HasGameRef<CrazyBallVsGame> {
  VsFeverTextPop({required Vector2 position}) : super(
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