import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --------------------------------------------------------------------------
// 0. CONFIGURACIÓN DE ENTORNO
// --------------------------------------------------------------------------

/// ⚠️ IMPORTANTE:
/// false -> Usa IDs de prueba (Seguro para testers y desarrollo).
/// true  -> Usa IDs reales (CAMBIAR A TRUE SOLO ANTES DE SUBIR A LAS TIENDAS).
const bool isProductionMode = false;

// --------------------------------------------------------------------------
// 1. CONSTANTES GLOBALES (IDs REALES - BOUNCE ROYALE)
// --------------------------------------------------------------------------

const String iapProductId = 'remove_ads_permanent';

// --- ANDROID (IDS REALES) ---
const String _androidProdAppOpenId      = 'ca-app-pub-8524103630580503/2813032683';
const String _androidProdBannerId       = 'ca-app-pub-8524103630580503/5940657851';
const String _androidProdDailyLimitId   = 'ca-app-pub-8524103630580503/1510458254';
const String _androidProdStoreBoxId     = 'ca-app-pub-8524103630580503/9197376588';

// --- IOS (IDS REALES) ---
const String _iosProdAppOpenId          = 'ca-app-pub-8524103630580503/3659210496';
const String _iosProdBannerId           = 'ca-app-pub-8524103630580503/6571213241';
const String _iosProdDailyLimitId       = 'ca-app-pub-8524103630580503/8859566287';
const String _iosProdStoreBoxId         = 'ca-app-pub-8524103630580503/5258131578';

// --------------------------------------------------------------------------
// 2. CONSTANTES GLOBALES (IDs DE PRUEBA OFICIALES DE GOOGLE)
// --------------------------------------------------------------------------

// --- ANDROID TEST IDS ---
const String _androidTestAppOpenId      = 'ca-app-pub-3940256099942544/9257395921';
const String _androidTestBannerId       = 'ca-app-pub-3940256099942544/6300978111';
const String _androidTestRewardedId     = 'ca-app-pub-3940256099942544/5224354917'; 

// --- IOS TEST IDS ---
const String _iosTestAppOpenId          = 'ca-app-pub-3940256099942544/5662855259';
const String _iosTestBannerId           = 'ca-app-pub-3940256099942544/2934735716';
const String _iosTestRewardedId         = 'ca-app-pub-3940256099942544/1712485313';

// --------------------------------------------------------------------------
// 3. HELPERS DE IDs (Retornan Prueba o Producción según tu plataforma)
// --------------------------------------------------------------------------

bool get _useTestIds => !isProductionMode;

String getAppOpenAdUnitId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestAppOpenId : _androidProdAppOpenId;
  if (Platform.isIOS) return _useTestIds ? _iosTestAppOpenId : _iosProdAppOpenId;
  throw UnsupportedError('Plataforma no soportada');
}

String getBannerAdUnitId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestBannerId : _androidProdBannerId;
  if (Platform.isIOS) return _useTestIds ? _iosTestBannerId : _iosProdBannerId; 
  throw UnsupportedError('Plataforma no soportada');
}

String getDailyLimitRewardId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestRewardedId : _androidProdDailyLimitId;
  if (Platform.isIOS) return _useTestIds ? _iosTestRewardedId : _iosProdDailyLimitId;
  throw UnsupportedError('Plataforma no soportada');
}

String getStoreBoxRewardId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestRewardedId : _androidProdStoreBoxId;
  if (Platform.isIOS) return _useTestIds ? _iosTestRewardedId : _iosProdStoreBoxId;
  throw UnsupportedError('Plataforma no soportada');
}

// --------------------------------------------------------------------------
// 4. ESTADO GLOBAL DE ANUNCIOS
// --------------------------------------------------------------------------

bool globalAdsRemoved = false;
const String _adRemovalKey = 'anuncios_eliminados';

Future<void> loadAdState() async {
  final prefs = await SharedPreferences.getInstance();
  globalAdsRemoved = prefs.getBool(_adRemovalKey) ?? false;
}

Future<void> setAdsRemoved(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_adRemovalKey, value);
  globalAdsRemoved = value;
}

// --------------------------------------------------------------------------
// 5. GESTOR DE APP OPEN ADS (Con límite de 3 horas de enfriamiento)
// --------------------------------------------------------------------------

class AppOpenAdManager {
  AppOpenAdManager._privateConstructor();
  static final AppOpenAdManager instance = AppOpenAdManager._privateConstructor();

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _lastAdShowTime;
  
  // Tiempo de espera para no molestar al jugador si sale y entra rápido
  final Duration _adInterval = const Duration(hours: 3); 

  void loadAd() {
    if (globalAdsRemoved) return;
    if (_appOpenAd != null) return;

    AppOpenAd.load(
      adUnitId: getAppOpenAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  void showAdIfAvailable() {
    if (globalAdsRemoved) return;
    
    // Validar si ya pasaron las 3 horas desde la última vez que lo vio
    if (_lastAdShowTime != null && DateTime.now().difference(_lastAdShowTime!) < _adInterval) return;
    
    if (_appOpenAd == null) { 
      loadAd(); 
      return; 
    }
    if (_isShowingAd) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        _lastAdShowTime = DateTime.now(); 
        ad.dispose();
        _appOpenAd = null;
        loadAd(); 
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
    );

    _appOpenAd!.show();
  }
}