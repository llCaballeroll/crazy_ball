import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart';

import 'home.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFromSettings; 

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Cambiamos el texto plano por las llaves dinámicas del diccionario
  final List<Map<String, String>> _tutorialKeys = [
    {"title": AppLocale.obTitle1, "desc": AppLocale.obDesc1},
    {"title": AppLocale.obTitle2, "desc": AppLocale.obDesc2},
    {"title": AppLocale.obTitle3, "desc": AppLocale.obDesc3},
    {"title": AppLocale.obTitle4, "desc": AppLocale.obDesc4},
  ];

  Future<void> _finishTutorial() async {
    if (widget.isFromSettings) {
      Navigator.pop(context); 
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLaunch', false);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50), 
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: FadeInDown(
                child: TextButton(
                  onPressed: _finishTutorial,
                  child: Text(AppLocale.skip.getString(context), style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ),
            
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _tutorialKeys.length,
                itemBuilder: (context, index) {
                  final isVisible = _currentPage == index;

                  // Extraemos las llaves y las convertimos al idioma actual del contexto
                  String titleTranslated = _tutorialKeys[index]["title"]!.getString(context);
                  String descTranslated = _tutorialKeys[index]["desc"]!.getString(context);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isVisible)
                          ZoomIn(
                            duration: const Duration(milliseconds: 600),
                            child: Container(
                              height: 250,
                              width: 250,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4EC0E9), 
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white, width: 5),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 10))],
                              ),
                               child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.asset('assets/images/onboarding/onboarding_$index.png', fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 50),
                        
                        if (isVisible)
                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              titleTranslated,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36, 
                                fontFamily: 'Impact', 
                                color: Color(0xFFFFD700),
                                letterSpacing: 1.5,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))]
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        if (isVisible)
                          FadeInUp(
                            delay: const Duration(milliseconds: 400),
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              descTranslated,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.4, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // --- CONTROLES INFERIORES ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _tutorialKeys.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        margin: const EdgeInsets.only(right: 8),
                        height: 12,
                        width: _currentPage == index ? 30 : 12,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFF9BE15D) : Colors.white38,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  
                  BounceInRight(
                    key: ValueKey(_currentPage), 
                    duration: const Duration(milliseconds: 600),
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage == _tutorialKeys.length - 1) {
                          _finishTutorial();
                        } else {
                          _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutBack);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: _currentPage == _tutorialKeys.length - 1 ? const Color(0xFFFF5722) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black87, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black87, offset: Offset(0, 4))],
                        ),
                        child: Text(
                          _currentPage == _tutorialKeys.length - 1 ? AppLocale.letsPlay.getString(context) : AppLocale.next.getString(context),
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            fontFamily: 'Impact',
                            letterSpacing: 1.2,
                            color: _currentPage == _tutorialKeys.length - 1 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}