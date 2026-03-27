import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_state_manager.dart';

import 'package:crazy_ball/game/world/crazy_ball_game.dart';
import 'package:crazy_ball/game/world/crazy_ball_vs_game.dart';
import 'package:crazy_ball/ui/screens/shop_virtual_screen.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sound_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localization/flutter_localization.dart'; // PAQUETE DE IDIOMAS
import '../../l10n/app_locale.dart'; // DICCIONARIO

import '../widgets/vs_podium_overlay.dart';
import '../../main.dart';
import 'settings_screen.dart';
import 'level_screen.dart';

enum ActiveGameMode { classic, vs }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CrazyBallGame _classicGame;
  late final CrazyBallVsGame _vsGame;

  bool _isMenuVisible = true;
  ActiveGameMode _activeMode = ActiveGameMode.classic;
  int _highScore = 0;
  String _selectedSkinAssetPath = 'assets/images/ball/ball_default.png';

  final GlobalKey _classicGameOverKey = GlobalKey();
  final TextEditingController _classicNameController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  int _advPlaysToday = 0;
  int _vsPlaysToday = 0;

  @override
  void initState() {
    super.initState();
    _classicGame = CrazyBallGame();
    _vsGame = CrazyBallVsGame();

    _loadHighScore();
    _loadSelectedSkin();
    _playHomeMusic();
    _checkDailyLives();
    _loadRewardedAd();

    _classicGame.scoreNotifier.addListener(_checkHighScore);
    _vsGame.scoreNotifier.addListener(_checkHighScore);
  }

  @override
  void dispose() {
    SoundManager.instance.stopMusic();
    _classicGame.scoreNotifier.removeListener(_checkHighScore);
    _vsGame.scoreNotifier.removeListener(_checkHighScore);
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _checkDailyLives() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final lastDate = prefs.getString('last_play_date') ?? '';

    if (lastDate != today) {
      await prefs.setInt('adv_plays', 0);
      await prefs.setInt('vs_plays', 0);
      await prefs.setString('last_play_date', today);
      _advPlaysToday = 0;
      _vsPlaysToday = 0;
    } else {
      _advPlaysToday = prefs.getInt('adv_plays') ?? 0;
      _vsPlaysToday = prefs.getInt('vs_plays') ?? 0;
    }
  }

  Future<void> _consumeLifeAndPlay(ActiveGameMode mode) async {
    if (!globalAdsRemoved) {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ActiveGameMode.classic) {
        _advPlaysToday++;
        await prefs.setInt('adv_plays', _advPlaysToday);
      } else {
        _vsPlaysToday++;
        await prefs.setInt('vs_plays', _vsPlaysToday);
      }
    }
    _startGameReal(mode);
  }

  void _handlePlayRequest(ActiveGameMode mode) async {
    await _checkDailyLives();

    if (globalAdsRemoved) {
      _startGameReal(mode);
      return;
    }

    if (mode == ActiveGameMode.classic) {
      if (_advPlaysToday < 5) {
        _consumeLifeAndPlay(mode);
      } else {
        _showAdWallDialog(mode);
      }
    } else {
      if (_vsPlaysToday < 5) {
        _consumeLifeAndPlay(mode);
      } else {
        _showAdWallDialog(mode);
      }
    }
  }

  void _startGameReal(ActiveGameMode mode) {
    SoundManager.instance.playMusic(mode == ActiveGameMode.classic ? 'aventura' : 'vs');
    setState(() {
      _activeMode = mode;
      _isMenuVisible = false;
    });
    
    _loadBannerAd(); 

    if (mode == ActiveGameMode.classic) {
      _classicGame.prepareGame();
    } else {
      _vsGame.prepareGame();
    }
  }

  void _returnToMenu() {
    setState(() {
      _isMenuVisible = true;
      _activeMode = ActiveGameMode.classic;
      _isBannerLoaded = false;
    });
    _bannerAd?.dispose(); 
    _bannerAd = null;
    
    _classicGame.resetToMenu();
    _vsGame.resetToMenu();
    SoundManager.instance.playMusic('home');
  }

  void _loadBannerAd() {
    if (globalAdsRemoved) return;
    _bannerAd = BannerAd(
      adUnitId: getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, error) { ad.dispose(); _isBannerLoaded = false; },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    if (globalAdsRemoved) return;
    RewardedAd.load(
      adUnitId: getDailyLimitRewardId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  void _showAdWallDialog(ActiveGameMode mode) {
    String modeName = mode == ActiveGameMode.classic 
        ? AppLocale.adventure.getString(context).toUpperCase() 
        : AppLocale.vs.getString(context).toUpperCase();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFFF5252), width: 3)),
        title: Text(AppLocale.livesExhausted.getString(context), style: const TextStyle(color: Color(0xFFFF5252), fontFamily: 'Impact', fontSize: 26), textAlign: TextAlign.center),
        content: Text(
          "${AppLocale.usedFreePlays.getString(context)} $modeName.\n\n${AppLocale.wantToPlayAgain.getString(context)}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.cancel.getString(context), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9BE15D)),
            icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.black87),
            label: Text(AppLocale.watchVideo.getString(context), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              if (_isRewardedAdLoaded && _rewardedAd != null) {
                bool rewardEarned = false; 

                _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
                  onAdDismissedFullScreenContent: (ad) {
                    ad.dispose();
                    _rewardedAd = null;
                    _isRewardedAdLoaded = false;
                    _loadRewardedAd(); 

                    if (rewardEarned) {
                      _startGameReal(mode);
                    }
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    ad.dispose();
                    _rewardedAd = null;
                    _isRewardedAdLoaded = false;
                    _loadRewardedAd();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.noAdsAvailable.getString(context))));
                  },
                );

                _rewardedAd!.show(
                  onUserEarnedReward: (_, __) {
                    rewardEarned = true; 
                  }
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.noAdsAvailable.getString(context))));
                _loadRewardedAd();
              }
            },
          ),
        ],
      ),
    );
  }

  void _playHomeMusic() => SoundManager.instance.playMusic('home');

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _highScore = prefs.getInt('highScore') ?? 0; });
  }

  Future<void> _loadSelectedSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final skinId = prefs.getString('selected_skin') ?? 'ball_default';
    if (mounted) setState(() => _selectedSkinAssetPath = _skinIdToAssetPath(skinId));
    _classicGame.updateSkin(skinId);
    _vsGame.updatePlayerSkin(skinId);
  }

  String _skinIdToAssetPath(String id) {
    if (id == 'ball_default') return 'assets/images/ball/ball_default.png';
    if (id.startsWith('ball_level_')) return 'assets/images/ball/level/$id.png';
    if (id.startsWith('ball_common_')) return 'assets/images/ball/pay/common/$id.png';
    if (id.startsWith('ball_rare_')) return 'assets/images/ball/pay/rare/$id.png';
    if (id.startsWith('ball_epic_')) return 'assets/images/ball/pay/epic/$id.png';
    if (id.startsWith('ball_legendary_')) return 'assets/images/ball/pay/legendary/$id.png';
    if (id.startsWith('ball_champion_')) return 'assets/images/ball/pay/champion/$id.png';
    return 'assets/images/ball/ball_default.png';
  }

  void _checkHighScore() async {
    final currentScore = _activeMode == ActiveGameMode.classic ? _classicGame.scoreNotifier.value : _vsGame.scoreNotifier.value;
    if (currentScore > _highScore) {
      _highScore = currentScore;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', _highScore);
    }
  }

  Future<void> _shareClassicScore() async {
    try {
      RenderRepaintBoundary boundary = _classicGameOverKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/score_aventura.png').create();
      await imagePath.writeAsBytes(pngBytes);

      String nickname = _classicNameController.text.trim().isNotEmpty ? _classicNameController.text.trim() : AppLocale.me.getString(context);
      
      String shareTextTranslated = AppLocale.shareAdventureText.getString(context)
          .replaceAll('%1', nickname)
          .replaceAll('%2', _classicGame.scoreNotifier.value.toString());

      await Share.shareXFiles([XFile(imagePath.path)], text: shareTextTranslated);
    } catch (e) {
      debugPrint("Error compartiendo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9), 
      body: Stack(
        children: [
          Offstage(
            offstage: _activeMode != ActiveGameMode.classic,
            child: GameWidget(
              game: _classicGame,
              overlayBuilderMap: {
                'Ready': (context, game) => _buildReadyOverlay(),
                'GameOver': (context, game) => _buildClassicGameOver(),
              },
            ),
          ),
          
          Offstage(
            offstage: _activeMode != ActiveGameMode.vs,
            child: GameWidget(
              game: _vsGame,
              overlayBuilderMap: {
                'Matchmaking': (context, game) => _buildMatchmakingOverlay(),
                'Spectating': (context, game) => _buildVsSpectatingOverlay(),
                'Podium': (context, game) => VsPodiumOverlay(
                      game: _vsGame,
                      onPlayAgain: () { _vsGame.overlays.remove('Podium'); _handlePlayRequest(ActiveGameMode.vs); },
                      onMenu: () { _vsGame.overlays.remove('Podium'); _returnToMenu(); },
                    ),
              },
            ),
          ),

          if (!_isMenuVisible && _activeMode == ActiveGameMode.classic)
            Positioned(
              top: 80, left: 0, right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _classicGame.showScoreNotifier,
                builder: (context, showScore, child) {
                  if (!showScore) return const SizedBox.shrink();
                  return ValueListenableBuilder<int>(
                    valueListenable: _classicGame.scoreNotifier,
                    builder: (context, score, child) => Center(
                      child: _BorderedText(text: score.toString(), fontSize: 80, fillColor: Colors.white, strokeColor: Colors.black),
                    ),
                  );
                }
              ),
            ),

          if (!_isMenuVisible && _activeMode == ActiveGameMode.vs)
            Positioned(
              top: 80, left: 0, right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _vsGame.showScoreNotifier,
                builder: (context, showScore, child) {
                  if (!showScore) return const SizedBox.shrink(); 
                  return ValueListenableBuilder<int>(
                    valueListenable: _vsGame.scoreNotifier,
                    builder: (context, score, child) => Center(
                      child: _BorderedText(text: score.toString(), fontSize: 80, fillColor: Colors.white, strokeColor: Colors.black),
                    ),
                  );
                }
              ),
            ),

          if (!_isMenuVisible && _isBannerLoaded && _bannerAd != null && !globalAdsRemoved)
            ValueListenableBuilder<bool>(
              valueListenable: _activeMode == ActiveGameMode.classic ? _classicGame.showScoreNotifier : _vsGame.showScoreNotifier,
              builder: (context, isPlaying, child) {
                if (!isPlaying) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                );
              },
            ),

          if (_isMenuVisible)
            Center(
              child: Container(
                width: isDesktop ? 400 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const _BorderedText(text: 'BOUNCE ROYALE', fontSize: 54, fillColor: Colors.white, strokeColor: Colors.black87, outerShadow: true)
                        .animate().slideY(begin: -0.5, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 30),
                    Image.asset(_selectedSkinAssetPath, width: 80, height: 80, errorBuilder: (c, e, s) => CustomPaint(size: const Size(60, 60), painter: _MenuBallPainter()))
                        .animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -12, end: 12, duration: 1500.ms, curve: Curves.easeInOut),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                      child: Text("${AppLocale.record.getString(context)}: $_highScore", style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 25), 
                    
                    // BOTÓN NIVELES
                    _GradientButton(
                      text: AppLocale.levels.getString(context), 
                      width: 140, 
                      height: 55, 
                      gradientColors: const [Color(0xFF66BB6A), Color(0xFF1B5E20)], 
                      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const LevelScreen())); }
                    ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
                    
const Spacer(flex: 2),
                    Row(
                      children: [
                        // BOTÓN AVENTURA (Adaptable a cualquier pantalla)
                        Expanded(
                          child: _GradientButton(
                            text: AppLocale.adventure.getString(context), 
                            width: double.infinity, // <-- Magia de diseño adaptable
                            height: 65, 
                            fontSize: 18, // <-- Bajamos a 18 para proteger idiomas largos como el Alemán
                            gradientColors: const [Color(0xFFFFCA28), Color(0xFFE65100)], 
                            onTap: () => _handlePlayRequest(ActiveGameMode.classic)
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut),
                        ),
                        
                        // SEPARADOR PERFECTO
                        const SizedBox(width: 15), 
                        
                        // BOTÓN VS (Adaptable a cualquier pantalla)
                        Expanded(
                          child: _GradientButton(
                            text: AppLocale.vs.getString(context), 
                            width: double.infinity, // <-- Magia de diseño adaptable
                            height: 65, 
                            fontSize: 18, 
                            gradientColors: const [Color(0xFFFF5252), Color(0xFFB71C1C)], 
                            onTap: () => _handlePlayRequest(ActiveGameMode.vs)
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut, delay: 400.ms),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        _GradientButton(icon: Icons.settings_rounded, width: 70, height: 60, gradientColors: const [Color(0xFFBDBDBD), Color(0xFF616161)], onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }),
                        _GradientButton(text: AppLocale.shop.getString(context), width: 120, height: 60, gradientColors: const [Color(0xFFCE93D8), Color(0xFF6A1B9A)], onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopVirtualScreen())); _loadSelectedSkin(); _playHomeMusic(); }),
                        _GradientButton(icon: Icons.leaderboard_rounded, width: 70, height: 60, gradientColors: const [Color(0xFF42A5F5), Color(0xFF1565C0)], onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadyOverlay() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BorderedText(text: AppLocale.readySet.getString(context), fontSize: 55, fillColor: const Color(0xFF9BE15D), strokeColor: Colors.white, strokeWidth: 6, outerShadow: true),
            const SizedBox(height: 120),
            _BorderedText(text: AppLocale.fly.getString(context), fontSize: 45, fillColor: const Color(0xFF9BE15D), strokeColor: Colors.white, strokeWidth: 5, outerShadow: true),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.redAccent, width: 2)),
                  child: Text(AppLocale.tap.getString(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.touch_app, color: Colors.white, size: 40).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -15, duration: 300.ms).scaleXY(begin: 1.0, end: 0.9, duration: 300.ms), 
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMatchmakingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<String>(
            valueListenable: _vsGame.matchmakingMessage,
            builder: (context, msg, child) {
              bool isOffline = msg.contains("⚠️") || msg == 'offlineBots';
              String translatedMsg = AppLocale.EN.containsKey(msg) 
                  ? msg.getString(context) 
                  : msg;
                  
              return _BorderedText(text: translatedMsg, fontSize: isOffline ? 24 : 28, fillColor: isOffline ? Colors.redAccent : Colors.white, strokeColor: Colors.black87, strokeWidth: 5, outerShadow: true)
                  .animate(key: ValueKey(translatedMsg)).fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
            }
          ),
          const SizedBox(height: 40),
          ValueListenableBuilder<int>(
            valueListenable: _vsGame.countdownNotifier,
            builder: (context, count, child) {
              if (count > 3) return const CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 6).animate().fadeIn(duration: 400.ms);
              return _BorderedText(text: count.toString(), fontSize: 100, fillColor: const Color(0xFFFFD700), strokeColor: Colors.black87, strokeWidth: 8, outerShadow: true)
                  .animate(key: ValueKey(count)).scaleXY(begin: 0.3, end: 1.0, duration: 400.ms, curve: Curves.elasticOut).fadeOut(delay: 600.ms, duration: 300.ms);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildVsSpectatingOverlay() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter, 
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BorderedText(text: AppLocale.gameEliminated.getString(context), fontSize: 40, fillColor: Colors.redAccent, strokeColor: Colors.white, outerShadow: true),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: _vsGame.botsAliveNotifier,
                builder: (context, vivos, child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text("${AppLocale.rivalsAlive.getString(context)} $vivos", style: const TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Impact')),
                )
              ),
              const SizedBox(height: 20),
              _GradientButton(
                icon: Icons.exit_to_app_rounded, text: AppLocale.leave.getString(context), width: 200, height: 60, fontSize: 20, 
                gradientColors: const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)], 
                onTap: () { _vsGame.overlays.remove('Spectating'); _returnToMenu(); }
              )
            ],
          ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
        ),
      ),
    );
  }

  Widget _buildClassicGameOver() {
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          RepaintBoundary(
            key: _classicGameOverKey,
            child: Container(
              width: screenW,
              height: screenH,
              decoration: const BoxDecoration(
                color: Color(0xFF4EC0E9),
                image: DecorationImage(image: AssetImage('assets/images/wallpapers/win.png'), fit: BoxFit.cover),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BorderedText(text: AppLocale.gameOver.getString(context), fontSize: 50, fillColor: Colors.amber, strokeColor: Colors.black87, outerShadow: true)
                      .animate().fadeIn().scaleXY(begin: 0.5, end: 1.0, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _classicNameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Impact', fontSize: 32, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 2))]),
                      decoration: InputDecoration(border: InputBorder.none, hintText: AppLocale.yourNickname.getString(context), hintStyle: const TextStyle(color: Colors.white54)),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: _classicGame.scoreNotifier,
                    builder: (context, score, child) => _BorderedText(text: "$score ${AppLocale.pts.getString(context)}", fontSize: 60, fillColor: Colors.white, strokeColor: Colors.black87, outerShadow: true)
                        .animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.95, end: 1.05, duration: 800.ms)
                  ),
                  const SizedBox(height: 40),
                  Image.asset(
                    _selectedSkinAssetPath, width: 120, height: 120, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.circle, size: 120, color: Colors.white),
                  ).animate().slideY(begin: 1.0, end: 0.0, curve: Curves.easeOutBack, duration: 600.ms)
                   .then().animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 1.seconds),
                   const SizedBox(height: 100), 
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GradientButton(
                        icon: Icons.replay_rounded, text: AppLocale.retry.getString(context), width: 190, height: 55, fontSize: 18,
                        gradientColors: const [Color(0xFF9BE15D), Color(0xFF388E3C)], 
                        onTap: () { _classicGame.overlays.remove('GameOver'); _handlePlayRequest(ActiveGameMode.classic); }
                      ).animate().scaleXY(begin: 0, end: 1, delay: 200.ms),
                      const SizedBox(width: 15),
                      _GradientButton(
                        icon: Icons.home_rounded, text: AppLocale.menu.getString(context), width: 140, height: 55, fontSize: 18,
                        gradientColors: const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)], 
                        onTap: () { _classicGame.overlays.remove('GameOver'); _returnToMenu(); }
                      ).animate().scaleXY(begin: 0, end: 1, delay: 400.ms),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _GradientButton(
                    icon: Icons.share_rounded, text: AppLocale.shareScore.getString(context), width: 345, height: 55, fontSize: 18,
                    gradientColors: const [Color(0xFF42A5F5), Color(0xFF1565C0)], 
                    onTap: _shareClassicScore
                  ).animate().scaleXY(begin: 0, end: 1, delay: 600.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFF5722));
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF3E1103)..style = PaintingStyle.stroke..strokeWidth = 3);
    final eyeCenter = Offset(radius + 8, radius - 4);
    canvas.drawCircle(eyeCenter, 10, Paint()..color = Colors.white);
    canvas.drawCircle(eyeCenter, 10, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(radius + 12, radius - 4), 4, Paint()..color = Colors.black);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BorderedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool outerShadow;
  const _BorderedText({required this.text, required this.fontSize, required this.fillColor, required this.strokeColor, this.strokeWidth = 8, this.outerShadow = false});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = strokeColor, shadows: outerShadow ? [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 4))] : null)),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', color: fillColor)),
      ],
    );
  }
}

class _GradientButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final double iconSize;
  final double fontSize; 
  final double width;
  final double height;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  const _GradientButton({this.icon, this.text, this.iconSize = 32, this.fontSize = 24, required this.width, required this.height, required this.gradientColors, required this.onTap});
  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), 
        width: widget.width, height: widget.height,
        margin: EdgeInsets.only(top: _isPressed ? 6.0 : 0.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2), 
          boxShadow: _isPressed ? [] : [BoxShadow(color: widget.gradientColors.last.withOpacity(0.6), offset: const Offset(0, 6), blurRadius: 8), const BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 4)]
        ),
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, child: Container(height: widget.height * 0.4, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), gradient: LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) Icon(widget.icon, size: widget.iconSize, color: Colors.white, shadows: const [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 3)]),
                  if (widget.icon != null && widget.text != null) const SizedBox(width: 8), 
                  if (widget.text != null) _BorderedText(text: widget.text!, fontSize: widget.fontSize, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 5, outerShadow: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}