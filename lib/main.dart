import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/screens/home.dart';
import 'ui/screens/tutorial_screen.dart';

void main() async {
  // Aseguramos que los bindings de Flutter estén listos antes de usar SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  // Revisamos si es la primera vez que abre la app
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  // Si es la primera vez, lo marcamos como falso para los futuros inicios
  if (isFirstLaunch) {
    await prefs.setBool('isFirstLaunch', false);
  }

  runApp(CrazyBallApp(isFirstLaunch: isFirstLaunch));
}

class CrazyBallApp extends StatelessWidget {
  final bool isFirstLaunch;
  
  const CrazyBallApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crazy Ball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Impact', // Define la fuente global para evitar declararla en cada texto
      ),
      // MAGIA AQUÍ: Decide qué pantalla mostrar al inicio
      home: isFirstLaunch 
          ? const TutorialScreen(isFromSettings: false) 
          : const HomeScreen(),
    );
  }
}