import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'home.dart';

class TutorialScreen extends StatefulWidget {
  // Nos permite saber si debemos regresar a Ajustes o ir al Home
  final bool isFromSettings; 

  const TutorialScreen({super.key, this.isFromSettings = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _tutorialData = [
    {
      "title": "¡TOCA PARA VOLAR!",
      "desc": "Toca la pantalla para impulsar tu bola hacia arriba. ¡Controla tu ritmo!",
    },
    {
      "title": "REBOTA Y SOBREVIVE",
      "desc": "Choca contra los bordes laterales para ganar puntos y esquiva las tuberías.",
    },
    {
      "title": "EL RIESGO PAGA",
      "desc": "Atrapa las monedas brillantes en los huecos peligrosos para comprar en la tienda.",
    },
    {
      "title": "¡MODO FEVER!",
      "desc": "Sobrevive 10 rebotes seguidos para volverte invencible y destrozar el siguiente obstáculo.",
    }
  ];

  // Función inteligente de salida
  void _finishTutorial() {
    if (widget.isFromSettings) {
      Navigator.pop(context); // Regresa a la pantalla de Ajustes
    } else {
      // Reemplaza el tutorial con el Home para que no pueda volver atrás con el botón de retroceso de Android
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
            // Botón de Omitir (Arriba a la derecha)
            Align(
              alignment: Alignment.topRight,
              child: FadeInDown(
                child: TextButton(
                  onPressed: _finishTutorial,
                  child: const Text("OMITIR", style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ),
            
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _tutorialData.length,
                itemBuilder: (context, index) {
                  // Validamos si es la página actual para animar solo lo que se ve
                  final isVisible = _currentPage == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- IMAGEN / ANIMACIÓN PRINCIPAL ---
                        if (isVisible)
                          ZoomIn(
                            duration: const Duration(milliseconds: 600),
                            child: Container(
                              height: 250,
                              width: 250,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4EC0E9), // Color placeholder
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white, width: 5),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 10))],
                              ),
                              child: const Center(
                                child: Icon(Icons.videogame_asset_rounded, size: 100, color: Colors.white54),
                              ),
                              // CUANDO TENGAS LAS IMÁGENES, DESCOMENTA ESTO:
                              // child: ClipRRect(
                              //   borderRadius: BorderRadius.circular(25),
                              //   child: Image.asset('assets/images/tutorial_$index.png', fit: BoxFit.cover),
                              // ),
                            ),
                          ),
                        
                        const SizedBox(height: 50),
                        
                        // --- TÍTULO ---
                        if (isVisible)
                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _tutorialData[index]["title"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36, 
                                fontFamily: 'Impact', 
                                color: Color(0xFFFFD700), // Amarillo vibrante
                                letterSpacing: 1.5,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))]
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // --- DESCRIPCIÓN ---
                        if (isVisible)
                          FadeInUp(
                            delay: const Duration(milliseconds: 400),
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _tutorialData[index]["desc"]!,
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
                  // Indicadores (Puntitos)
                  Row(
                    children: List.generate(
                      _tutorialData.length,
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
                  
                  // Botón Siguiente / A Jugar
                  BounceInRight(
                    key: ValueKey(_currentPage), // Fuerza la animación al cambiar de estado
                    duration: const Duration(milliseconds: 600),
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage == _tutorialData.length - 1) {
                          _finishTutorial();
                        } else {
                          _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutBack);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: _currentPage == _tutorialData.length - 1 ? const Color(0xFFFF5722) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black87, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black87, offset: Offset(0, 4))],
                        ),
                        child: Text(
                          _currentPage == _tutorialData.length - 1 ? "¡A JUGAR!" : "SIGUIENTE",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            fontFamily: 'Impact',
                            letterSpacing: 1.2,
                            color: _currentPage == _tutorialData.length - 1 ? Colors.white : Colors.black87,
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