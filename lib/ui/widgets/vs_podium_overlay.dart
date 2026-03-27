import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart';

import '../../game/world/crazy_ball_vs_game.dart';
import '../../services/sound_manager.dart';

class VsPodiumOverlay extends StatefulWidget {
  final CrazyBallVsGame game;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const VsPodiumOverlay({
    super.key,
    required this.game,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  State<VsPodiumOverlay> createState() => _VsPodiumOverlayState();
}

class _VsPodiumOverlayState extends State<VsPodiumOverlay> {
  int _animationPhase = 0; 
  final GlobalKey _globalKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    setState(() => _animationPhase = 1);
    SoundManager.instance.sfxDestruccion();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() => _animationPhase = 2);
    SoundManager.instance.sfxBote();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() => _animationPhase = 3);
    if (widget.game.didPlayerWin) {
      SoundManager.instance.sfxPoder(); 
    }
  }

  Future<void> _shareScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/victoria.png').create();
      await imagePath.writeAsBytes(pngBytes);

      String nickname = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : AppLocale.me.getString(context);
      
      String shareTextTranslated = AppLocale.shareVsText.getString(context)
          .replaceAll('%1', nickname)
          .replaceAll('%2', widget.game.scoreNotifier.value.toString());

      await Share.shareXFiles([XFile(imagePath.path)], text: shareTextTranslated);
    } catch (e) {
      debugPrint("Error compartiendo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranking = widget.game.finalRankingSkins;
    final bool isWinner = widget.game.didPlayerWin;

    final String backgroundImage = isWinner 
        ? 'assets/images/wallpapers/win.png' 
        : 'assets/images/wallpapers/game_over.png';

    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;

    final double stepW = screenW / 3;
    final double bronzeCX = stepW / 2;             
    final double goldCX = screenW / 2;             
    final double silverCX = screenW - (stepW / 2); 

    final double goldH = screenH * 0.25;
    final double silverH = screenH * 0.20;
    final double bronzeH = screenH * 0.15;
    
    final double podiumBaseY = screenH; 

    double getStartX(int index) => (screenW / (ranking.length + 1)) * (index + 1);
    const double startY = 120.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: screenW,
              height: screenH,
              decoration: BoxDecoration(
                color: const Color(0xFF4EC0E9), 
                image: DecorationImage(image: AssetImage(backgroundImage), fit: BoxFit.cover),
              ),
              child: Stack(
                children: [
                  AnimatedScale(
                    scale: (_animationPhase == 3 && isWinner) ? 1.35 : 1.0,
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeInOut,
                    alignment: Alignment.bottomCenter,
                    child: Stack(
                      children: [
                        _buildAnimatedStep("3", bronzeCX, podiumBaseY, stepW, bronzeH, const Color(0xFFCD7F32)), 
                        _buildAnimatedStep("1", goldCX, podiumBaseY, stepW, goldH, const Color(0xFFFFD700)),    
                        _buildAnimatedStep("2", silverCX, podiumBaseY, stepW, silverH, const Color(0xFFC0C0C0)), 

                        for (int i = 0; i < ranking.length; i++)
                          _buildBall(i, ranking[i], goldCX, silverCX, bronzeCX, getStartX(i), startY, podiumBaseY, goldH, silverH, bronzeH),

                        if (_animationPhase == 3 && isWinner)
                          Positioned(
                            top: podiumBaseY - goldH - 130, left: goldCX - 35, 
                            child: Image.asset(
                              'assets/images/principales/corona.png', width: 70, height: 70, fit: BoxFit.contain,
                              errorBuilder: (_,__,___) => const Icon(Icons.star, color: Colors.amber, size: 70)
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 1.seconds),
                          ),
                      ],
                    ),
                  ),

                  if (_animationPhase == 3 && !isWinner)
                    Positioned(
                      top: 100, left: 0, right: 0,
                      child: Center(
                        child: _BorderedText(
                          text: AppLocale.gameOver.getString(context),
                          fontSize: 65, fillColor: Colors.redAccent, strokeColor: Colors.white, outerShadow: true,
                        ).animate().fadeIn().scaleXY(begin: 0.5, end: 1.0, curve: Curves.elasticOut),
                      ),
                    ),

                  if (_animationPhase == 3 && isWinner) ...[
                    Positioned(
                      top: 60, left: 0, right: 0,
                      child: Center(
                        child: _BorderedText(
                          text: AppLocale.winner.getString(context),
                          fontSize: 60, fillColor: const Color(0xFFFFD700), strokeColor: Colors.black87, outerShadow: true,
                        ).animate().scaleXY(begin: 0, end: 1, curve: Curves.elasticOut),
                      ),
                    ),
                    
                    Positioned(
                      top: 135, left: 0, right: 0,
                      child: Center(
                        child: SizedBox(
                          width: 250,
                          child: TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Impact', fontSize: 32, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 2))]),
                            decoration: InputDecoration(border: InputBorder.none, hintText: AppLocale.yourNickname.getString(context), hintStyle: const TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 800.ms),
                    ),

                    Positioned(
                      top: 200, left: 0, right: 0,
                      child: Center(
                        child: Text(
                          "${widget.game.scoreNotifier.value} ${AppLocale.pts.getString(context)}",
                          style: const TextStyle(fontFamily: 'Impact', fontSize: 45, color: Colors.white, shadows: [Shadow(color: Colors.amber, blurRadius: 15, offset: Offset(0, 0))]),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn().scaleXY(begin: 0.95, end: 1.05, duration: 800.ms),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_animationPhase == 3)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWinner) ...[
                      _PremiumBtn(
                        icon: Icons.share_rounded, text: AppLocale.shareVictory.getString(context), 
                        gradientColors: const [Color(0xFF42A5F5), Color(0xFF1565C0)], 
                        onTap: _shareScreenshot
                      ).animate().scaleXY(begin: 0, end: 1, delay: 500.ms),
                      const SizedBox(height: 15),
                    ],
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PremiumBtn(
                          icon: Icons.replay_rounded, text: AppLocale.retry.getString(context), 
                          gradientColors: const [Color(0xFF9BE15D), Color(0xFF388E3C)], 
                          onTap: widget.onPlayAgain
                        ).animate().scaleXY(begin: 0, end: 1, delay: (isWinner ? 700 : 200).ms),
                        
                        const SizedBox(width: 15),
                        
                        _PremiumBtn(
                          icon: Icons.home_rounded, text: AppLocale.menu.getString(context), 
                          gradientColors: const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)], 
                          onTap: widget.onMenu
                        ).animate().scaleXY(begin: 0, end: 1, delay: (isWinner ? 900 : 400).ms),
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

  Widget _buildAnimatedStep(String number, double cx, double baseY, double w, double h, Color color) {
    return AnimatedPositioned(
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOutBack,
      top: baseY - h,
      left: cx - (w / 2),
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(color: color, border: Border.all(color: Colors.black87, width: 3), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.only(top: 10), child: Text(number, style: const TextStyle(fontFamily: 'Impact', fontSize: 50, color: Colors.black54))),
        ),
      ),
    );
  }

  Widget _buildBall(int index, String path, double goldCX, double silverCX, double bronzeCX, double startX, double startY, double baseY, double goldH, double silverH, double bronzeH) {
    double targetX = startX;
    double targetY = startY;
    double targetSize = 65.0; 

    if (index == 0) {
      targetX = goldCX; targetY = baseY - goldH - targetSize; targetSize = 80.0; 
    } else if (index == 1) {
      targetX = silverCX; targetY = baseY - silverH - targetSize;
    } else if (index == 2) {
      targetX = bronzeCX; targetY = baseY - bronzeH - targetSize;
    }

    bool isLoser = index > 2;

    if (isLoser && _animationPhase >= 1) {
      return Positioned(
        top: startY - 30, left: startX - 45,
        child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 90)
            .animate().scaleXY(begin: 1, end: 2.5).fadeOut(duration: 400.ms),
      );
    }

    double currentX = (_animationPhase >= 2 && !isLoser) ? targetX : startX;
    double currentY = (_animationPhase >= 2 && !isLoser) ? targetY : startY;
    double currentSize = (_animationPhase >= 2 && !isLoser) ? targetSize : 50.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800), curve: Curves.bounceOut,
      top: currentY, left: currentX - (currentSize / 2), width: currentSize, height: currentSize,
      child: Image.asset('assets/images/$path', fit: BoxFit.contain, errorBuilder: (_,__,___) => Icon(Icons.circle, size: currentSize, color: Colors.white)),
    );
  }
}

class _PremiumBtn extends StatefulWidget {
  final IconData icon;
  final String? text;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _PremiumBtn({required this.icon, this.text, required this.gradientColors, required this.onTap});

  @override
  State<_PremiumBtn> createState() => _PremiumBtnState();
}

class _PremiumBtnState extends State<_PremiumBtn> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), 
        height: 55, margin: EdgeInsets.only(top: _isPressed ? 6.0 : 0.0),
        padding: EdgeInsets.symmetric(horizontal: widget.text == null ? 15 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), 
          borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2), 
          boxShadow: _isPressed ? [] : [BoxShadow(color: widget.gradientColors.last.withOpacity(0.6), offset: const Offset(0, 4), blurRadius: 6), const BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 3)]
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), gradient: LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 24, color: Colors.white, shadows: const [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 3)]),
                  if (widget.text != null) ...[
                    const SizedBox(width: 8),
                    _BorderedText(text: widget.text!, fontSize: 18, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4, outerShadow: true),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BorderedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool outerShadow;

  const _BorderedText({required this.text, required this.fontSize, required this.fillColor, required this.strokeColor, this.strokeWidth = 6, this.outerShadow = false});

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