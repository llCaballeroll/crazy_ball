import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// --------------------------------------------------------------------------
// 0. CONFIGURACIÓN DE ENTORNO
// --------------------------------------------------------------------------

/// ⚠️ IMPORTANTE:
/// false -> Usa IDs de prueba (Seguro para desarrollo).
/// true  -> Usa IDs reales (Producción).
const bool isProductionMode = false;

// --------------------------------------------------------------------------
// 1. CONSTANTES GLOBALES
// --------------------------------------------------------------------------

const String iapProductId = 'remove_ads_permanent';

// --- ANDROID (IDS REALES) ---
const String _androidProdBannerId       = ''; // Crazy_And_Ban_Game_Bottom
const String _androidProdAppOpenId      = ''; // Crazy_And_AppOpen_Open_App
const String _androidProdStoreBoxId     = ''; // Crazy_And_Rew_Store_FreeBox
const String _androidProdDailyLimitId   = ''; // Crazy_And_Rew_Game_DailyLimit
const String _androidProdInterstitialId = ''; // Crazy_And_Int_Game_BetweenGames

// --- ANDROID (TEST IDS - PROPORCIONADOS POR GOOGLE) ---
const String _androidTestBannerId       = 'ca-app-pub-3940256099942544/6300978111';
const String _androidTestAppOpenId      = 'ca-app-pub-3940256099942544/9257395921';
const String _androidTestRewardedId     = 'ca-app-pub-3940256099942544/5224354917'; 
const String _androidTestInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

// --- IOS (Placeholders o Test) ---
const String _iosTestBannerId           = 'ca-app-pub-3940256099942544/2934735716';
const String _iosTestAppOpenId          = 'ca-app-pub-3940256099942544/5662855259';
const String _iosTestRewardedId         = 'ca-app-pub-3940256099942544/1712485313';
const String _iosTestInterstitialId     = 'ca-app-pub-3940256099942544/4411468910';

// --------------------------------------------------------------------------
// 2. HELPERS DE IDs
// --------------------------------------------------------------------------

bool get _useTestIds => !isProductionMode;

String getBannerAdUnitId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestBannerId : _androidProdBannerId;
  if (Platform.isIOS) return _iosTestBannerId; 
  throw UnsupportedError('Plataforma no soportada');
}

String getAppOpenAdUnitId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestAppOpenId : _androidProdAppOpenId;
  if (Platform.isIOS) return _iosTestAppOpenId;
  throw UnsupportedError('Plataforma no soportada');
}

String getStoreBoxRewardId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestRewardedId : _androidProdStoreBoxId;
  if (Platform.isIOS) return _iosTestRewardedId;
  throw UnsupportedError('Plataforma no soportada');
}

String getDailyLimitRewardId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestRewardedId : _androidProdDailyLimitId;
  if (Platform.isIOS) return _iosTestRewardedId;
  throw UnsupportedError('Plataforma no soportada');
}

String getInterstitialAdUnitId() {
  if (Platform.isAndroid) return _useTestIds ? _androidTestInterstitialId : _androidProdInterstitialId;
  if (Platform.isIOS) return _iosTestInterstitialId;
  throw UnsupportedError('Plataforma no soportada');
}

// --------------------------------------------------------------------------
// 3. ESTADO GLOBAL
// --------------------------------------------------------------------------

bool globalAdsRemoved = false;
const String _adRemovalKey = 'anuncios_eliminados';
const String _gamesPlayedKey = 'games_played_count';

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
// 4. GESTOR DE APP OPEN ADS
// --------------------------------------------------------------------------

class AppOpenAdManager {
  AppOpenAdManager._privateConstructor();
  static final AppOpenAdManager instance = AppOpenAdManager._privateConstructor();

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _lastAdShowTime;
  final Duration _adInterval = const Duration(hours: 4); 

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
    if (_lastAdShowTime != null && DateTime.now().difference(_lastAdShowTime!) < _adInterval) return;
    if (_appOpenAd == null) { loadAd(); return; }
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

// --------------------------------------------------------------------------
// 5. GESTOR DE INTERSTITIAL ADS (CADA 8 PARTIDAS)
// --------------------------------------------------------------------------

class InterstitialAdManager {
  InterstitialAdManager._privateConstructor();
  static final InterstitialAdManager instance = InterstitialAdManager._privateConstructor();
  InterstitialAd? _interstitialAd;

  void loadAd() {
    if (globalAdsRemoved) return;
    InterstitialAd.load(
      adUnitId: getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  Future<void> checkAndShowAdIfNeeded() async {
    if (globalAdsRemoved) return;
    
    final prefs = await SharedPreferences.getInstance();
    int gamesPlayed = (prefs.getInt(_gamesPlayedKey) ?? 0) + 1; // Incrementamos la partida jugada
    
    // Si ya llegamos a 8 partidas, mostramos el anuncio
    if (gamesPlayed >= 8) {
      if (_interstitialAd != null) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) { ad.dispose(); _interstitialAd = null; loadAd(); },
          onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _interstitialAd = null; loadAd(); },
        );
        _interstitialAd!.show();
        gamesPlayed = 0; // Reiniciamos el contador después de mostrarlo
      } else {
        loadAd(); // Si por algo falló la carga previa, lo intentamos de nuevo
      }
    }
    
    // Guardamos el progreso
    await prefs.setInt(_gamesPlayedKey, gamesPlayed);
  }
}