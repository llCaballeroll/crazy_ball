import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame/flame.dart';

// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart';

import '../../services/sound_manager.dart';
import 'home.dart';
import 'onboarding_screen.dart'; // Asegúrate de que el nombre del archivo coincida con tu estructura

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Tiempo visual mínimo para que se vea el logo
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _startAppInitialization();
  }

  Future<void> _startAppInitialization() async {
    _progressController.animateTo(0.8, duration: const Duration(seconds: 2));

    final minTimeFuture = Future.delayed(const Duration(seconds: 2));
    final loadAssetsFuture = _preloadGameAssets();

    try {
      await Future.wait([minTimeFuture, loadAssetsFuture]);
    } catch (e) {
      debugPrint("Error inicializando assets: $e");
    }

    if (mounted) {
      await _progressController.animateTo(1.0, duration: const Duration(milliseconds: 300));
      _navigateToNextScreen();
    }
  }

  Future<void> _preloadGameAssets() async {
    await SoundManager.instance.init();
    await Flame.images.loadAll([
      'ball/ball_default.png',
    ]);
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (!mounted) return;

    if (isFirstLaunch) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/principales/splash_bg.png', 
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text("BOUNCE ROYALE", style: TextStyle(fontSize: 50, color: Colors.white)),
            ),
          ),

          Positioned(
            bottom: 60, 
            left: 40,   
            right: 40,  
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    Text(
                      AppLocale.loadingAssets.getString(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 2.0,
                        shadows: [Shadow(offset: Offset(2, 2), color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 15),

                    Container(
                      height: 32, 
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black87, width: 4), 
                        boxShadow: const [BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 6)],
                      ),
                      child: Stack(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                width: constraints.maxWidth * _progressAnimation.value, 
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFF5722)],
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          Center(
                            child: Text(
                              "${(_progressAnimation.value * 100).toInt()}%",
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(offset: Offset(1, 1), color: Colors.black87, blurRadius: 2)]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}