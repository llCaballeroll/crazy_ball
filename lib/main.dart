import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localization/flutter_localization.dart'; // PAQUETE DE IDIOMAS
import 'l10n/app_locale.dart'; // NUESTROS DICCIONARIOS

import 'ui/screens/splash_screen.dart';
import 'services/ad_state_manager.dart'; 

void main() async {
  // 1. Inicializa el motor de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. ¡AQUÍ ESTÁ LA SOLUCIÓN! Inicializa el motor de traducciones antes de arrancar
  await FlutterLocalization.instance.ensureInitialized();
  
  // 3. Inicializamos Google Mobile Ads y cargamos el estado (Si compró quitar anuncios)
  await MobileAds.instance.initialize();
  await loadAdState();
  
  // 4. Control de Primer Inicio para NO asustar al jugador con un AppOpenAd
  final prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  
  if (isFirstLaunch) {
    await prefs.setBool('is_first_launch', false);
  } else {
    // Si no es su primera vez, precargamos el anuncio de apertura
    AppOpenAdManager.instance.loadAd();
  }

  // 5. Forzamos la orientación vertical para evitar bugs en el inicio
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CrazyBallApp());
}

class CrazyBallApp extends StatefulWidget {
  const CrazyBallApp({super.key});

  @override
  State<CrazyBallApp> createState() => _CrazyBallAppState();
}

class _CrazyBallAppState extends State<CrazyBallApp> with WidgetsBindingObserver {
  // Inicializamos el gestor de traducciones
  final FlutterLocalization _localization = FlutterLocalization.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configuramos los idiomas, dejando Inglés (en) como paracaídas de seguridad
    _localization.init(
      mapLocales: AppLocale.supportedLocales,
      initLanguageCode: 'en',
    );
    _localization.onTranslatedLanguage = _onTranslatedLanguage;
  }

  // Refresca la app si el usuario cambia el idioma del teléfono en tiempo real
  void _onTranslatedLanguage(Locale? locale) {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppOpenAdManager.instance.showAdIfAvailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bounce Royale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Impact'),
      
      // Conectamos los delegados de traducción a la app
      supportedLocales: _localization.supportedLocales,
      localizationsDelegates: _localization.localizationsDelegates,
      
      home: const SplashScreen(),
    );
  }
}