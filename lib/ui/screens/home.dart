import 'package:crazy_ball/game/world/crazy_ball_game.dart';
import 'package:crazy_ball/game/world/crazy_ball_vs_game.dart';
import 'package:crazy_ball/ui/screens/shop_virtual_screen.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart'; 

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

  @override
  void initState() {
    super.initState();
    _classicGame = CrazyBallGame();
    _vsGame = CrazyBallVsGame();
    
    _loadHighScore();
    _classicGame.scoreNotifier.addListener(_checkHighScore);
    _vsGame.scoreNotifier.addListener(_checkHighScore);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _highScore = prefs.getInt('highScore') ?? 0; });
  }

  void _checkHighScore() async {
    final currentScore = _activeMode == ActiveGameMode.classic 
        ? _classicGame.scoreNotifier.value 
        : _vsGame.scoreNotifier.value;
        
    if (currentScore > _highScore) {
      _highScore = currentScore;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', _highScore);
    }
  }

  void _onPlayClassicTapped() {
    setState(() { 
      _activeMode = ActiveGameMode.classic;
      _isMenuVisible = false; 
    });
    _classicGame.prepareGame();
  }

  void _onPlayVsTapped() {
    setState(() { 
      _activeMode = ActiveGameMode.vs;
      _isMenuVisible = false; 
    });
    _vsGame.prepareGame();
  }

  void _returnToMenu() {
    setState(() { 
      _isMenuVisible = true; 
      _activeMode = ActiveGameMode.classic; 
    });
    _classicGame.resetToMenu();
    _vsGame.resetToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9), 
      body: Stack(
        children: [
          // FIX: Usamos Offstage para mantener ambos motores cargados y con las medidas de pantalla correctas
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
                'Ready': (context, game) => _buildReadyOverlay(),
                'GameOver': (context, game) => _buildVsGameOver(),
                'Victory': (context, game) => _buildVsVictory(),
              },
            ),
          ),
          
          if (!_isMenuVisible)
            Positioned(
              top: 80, left: 0, right: 0,
              child: ValueListenableBuilder<int>(
                valueListenable: _activeMode == ActiveGameMode.classic ? _classicGame.scoreNotifier : _vsGame.scoreNotifier,
                builder: (context, score, child) {
                  return Center(
                    child: _BorderedText(
                      text: score.toString(),
                      fontSize: 80,
                      fillColor: Colors.white,
                      strokeColor: Colors.black,
                    ),
                  );
                },
              ),
            ),

          if (_isMenuVisible)
            Center(
              child: Container(
                width: isDesktop ? 400 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    const _BorderedText(
                      text: 'CRAZY BALL',
                      fontSize: 54,
                      fillColor: Colors.white,
                      strokeColor: Colors.black87,
                      outerShadow: true,
                    ).animate().slideY(begin: -0.5, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 30),
                    
                    CustomPaint(
                      size: const Size(60, 60),
                      painter: _MenuBallPainter(),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .moveY(begin: -12, end: 12, duration: 1500.ms, curve: Curves.easeInOut), 
                    
                    const SizedBox(height: 30),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                      child: Text("Récord: $_highScore", style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    
                    const SizedBox(height: 25), 

                    _RetroButton(
                      text: "NIVELES", width: 140, height: 55, color: const Color(0xFF9BE15D), 
                      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const LevelScreen())); }
                    ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
                    
                    const Spacer(flex: 2),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RetroButton(
                          text: "AVENTURA", width: 140, height: 65, color: const Color(0xFFFFD700),
                          onTap: _onPlayClassicTapped, 
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut),
                        
                        _RetroButton(
                          text: "VS", width: 140, height: 65, color: const Color(0xFFFF5722), 
                          onTap: _onPlayVsTapped, 
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut, delay: 400.ms),
                      ],
                    ),
                    
                    const Spacer(flex: 2),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        _RetroButton(icon: Icons.settings_rounded, width: 70, height: 60, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }),
                        _RetroButton(text: "TIENDA", width: 120, height: 60, onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopVirtualScreen()));}),
                        _RetroButton(icon: Icons.leaderboard_rounded, width: 70, height: 60, onTap: () {}),
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

  // --- OVERLAYS COMUNES ---
  Widget _buildReadyOverlay() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _BorderedText(text: "Ready! Set!", fontSize: 55, fillColor: Color(0xFF9BE15D), strokeColor: Colors.white, strokeWidth: 6, outerShadow: true),
            const SizedBox(height: 120),
            const _BorderedText(text: "FLY!", fontSize: 45, fillColor: Color(0xFF9BE15D), strokeColor: Colors.white, strokeWidth: 5, outerShadow: true),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.redAccent, width: 2)),
                  child: const Text("TAP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.touch_app, color: Colors.white, size: 40)
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .moveY(begin: 0, end: -15, duration: 300.ms) 
                    .scaleXY(begin: 1.0, end: 0.9, duration: 300.ms), 
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildClassicGameOver() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BorderedText(text: "¡CRASH!", fontSize: 50, fillColor: Colors.redAccent, strokeColor: Colors.white, outerShadow: true),
          const SizedBox(height: 20),
          ValueListenableBuilder<int>(
            valueListenable: _classicGame.scoreNotifier,
            builder: (context, score, child) => _BorderedText(text: "Puntos: $score", fontSize: 35, fillColor: Colors.white, strokeColor: Colors.black)
          ),
          const SizedBox(height: 40),
          _RetroButton(text: "REINTENTAR", width: 200, height: 65, onTap: () { _classicGame.overlays.remove('GameOver'); _classicGame.prepareGame(); }),
          const SizedBox(height: 15),
          _RetroButton(text: "MENÚ", width: 160, height: 55, color: const Color(0xFFE0E0E0), onTap: () { _classicGame.overlays.remove('GameOver'); _returnToMenu(); })
        ],
      ),
    );
  }

  Widget _buildVsGameOver() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter, 
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BorderedText(text: "¡ELIMINADO!", fontSize: 40, fillColor: Colors.redAccent, strokeColor: Colors.white, outerShadow: true),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: _vsGame.botsAliveNotifier,
                builder: (context, vivos, child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text("Rivales Vivos: $vivos", style: const TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Impact')),
                )
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RetroButton(text: "REINTENTAR", width: 160, height: 55, onTap: () { _vsGame.overlays.remove('GameOver'); _vsGame.prepareGame(); }),
                  const SizedBox(width: 15),
                  _RetroButton(text: "MENÚ", width: 140, height: 55, color: const Color(0xFFE0E0E0), onTap: () { _vsGame.overlays.remove('GameOver'); _returnToMenu(); })
                ],
              )
            ],
          ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
        ),
      ),
    );
  }

  Widget _buildVsVictory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BorderedText(text: "¡VICTORIA!", fontSize: 55, fillColor: Color(0xFFFFD700), strokeColor: Colors.white, outerShadow: true)
            .animate().scaleXY(begin: 0.5, end: 1, duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 10),
          const _BorderedText(text: "ÚLTIMO SUPERVIVIENTE", fontSize: 24, fillColor: Colors.white, strokeColor: Colors.black),
          const SizedBox(height: 40),
          ValueListenableBuilder<int>(
            valueListenable: _vsGame.scoreNotifier,
            builder: (context, score, child) => _BorderedText(text: "Puntos: $score", fontSize: 35, fillColor: Colors.white, strokeColor: Colors.black)
          ),
          const SizedBox(height: 40),
          _RetroButton(text: "JUGAR DE NUEVO", width: 220, height: 65, color: const Color(0xFF9BE15D), onTap: () { _vsGame.overlays.remove('Victory'); _vsGame.prepareGame(); }),
          const SizedBox(height: 15),
          _RetroButton(text: "MENÚ", width: 160, height: 55, color: const Color(0xFFE0E0E0), onTap: () { _vsGame.overlays.remove('Victory'); _returnToMenu(); })
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

  const _BorderedText({
    required this.text, required this.fontSize, required this.fillColor, required this.strokeColor, this.strokeWidth = 8, this.outerShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(text, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = strokeColor, shadows: outerShadow ? [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 4))] : null)),
        Text(text, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', color: fillColor)),
      ],
    );
  }
}

class _RetroButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final double iconSize;
  final double width;
  final double height;
  final Color color;
  final VoidCallback onTap;

  const _RetroButton({this.icon, this.text, this.iconSize = 32, required this.width, required this.height, this.color = const Color(0xFFFFD700), required this.onTap});

  @override
  State<_RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<_RetroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), width: widget.width, height: widget.height,
        margin: EdgeInsets.only(top: _isPressed ? 6.0 : 0.0),
        decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black87, width: 3), boxShadow: _isPressed ? [] : [const BoxShadow(color: Colors.black87, offset: Offset(0, 6))]),
        child: Center(
          child: widget.icon != null ? Icon(widget.icon, size: widget.iconSize, color: Colors.white, shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2)]) : _BorderedText(text: widget.text!, fontSize: 24, fillColor: Colors.white, strokeColor: Colors.black, strokeWidth: 5),
        ),
      ),
    );
  }
}