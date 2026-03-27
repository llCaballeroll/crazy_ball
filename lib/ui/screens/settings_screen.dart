import 'package:flutter/material.dart';
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart';
import '../../l10n/app_locale.dart';

import 'onboarding_screen.dart';
import '../../services/sound_manager.dart'; 
import '../../services/ad_state_manager.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMusicOn = true;
  bool _isSoundOn = true;
  bool _isVibrationOn = true;
  String _appVersion = "1.0.0";

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();

    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('Error restaurando compras: $error');
    });
  }

  @override
  void dispose() {
    _subscription.cancel(); 
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.restored || purchaseDetails.status == PurchaseStatus.purchased) {
        
        if (purchaseDetails.productID == 'crazyball_remove_ads') {
          setAdsRemoved(true); 
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocale.purchaseRestoredSuccess.getString(context), style: const TextStyle(fontFamily: 'Impact', letterSpacing: 1.2)), 
                backgroundColor: Colors.green
              )
            );
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocale.storeConnectionError.getString(context), style: const TextStyle(fontFamily: 'Impact', letterSpacing: 1.2)), 
              backgroundColor: Colors.redAccent
            )
          );
        }
      }
    }
    
    if (mounted) {
      setState(() { _isRestoring = false; });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMusicOn = prefs.getBool('musicOn') ?? true;
      _isSoundOn = prefs.getBool('soundOn') ?? true;
      _isVibrationOn = prefs.getBool('vibrationOn') ?? true;
    });
  }

  Future<void> _toggleSetting(String key, bool currentValue) async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !currentValue;
    await prefs.setBool(key, newValue);
    
    setState(() {
      if (key == 'musicOn') {
        _isMusicOn = newValue;
        SoundManager.instance.toggleMusic(newValue); 
      }
      if (key == 'soundOn') {
        _isSoundOn = newValue;
        SoundManager.instance.toggleSound(newValue); 
      }
      if (key == 'vibrationOn') {
        _isVibrationOn = newValue;
        SoundManager.instance.toggleVibration(newValue); 
      }
    });
  }

  Future<void> _loadAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = "${packageInfo.version} (${packageInfo.buildNumber})";
    });
  }

  @override
  Widget build(BuildContext context) {
    String versionText = AppLocale.version.getString(context).replaceAll('%1', _appVersion);

    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9), 
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black87, width: 3)),
                      child: const Icon(Icons.arrow_back_rounded, size: 30, color: Colors.black87),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocale.settings.getString(context),
                        style: const TextStyle(fontSize: 40, fontFamily: 'Impact', color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(2, 2))]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), 
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildSectionTitle(AppLocale.audioAndControls.getString(context)),
                  _buildSwitchTile(AppLocale.music.getString(context), Icons.music_note_rounded, _isMusicOn, () => _toggleSetting('musicOn', _isMusicOn)),
                  _buildSwitchTile(AppLocale.soundEffects.getString(context), Icons.volume_up_rounded, _isSoundOn, () => _toggleSetting('soundOn', _isSoundOn)),
                  _buildSwitchTile(AppLocale.vibration.getString(context), Icons.vibration_rounded, _isVibrationOn, () => _toggleSetting('vibrationOn', _isVibrationOn)),
                  
                  const SizedBox(height: 30),

                  _buildSectionTitle(AppLocale.information.getString(context)),
                  _buildButtonTile(AppLocale.howToPlay.getString(context), Icons.help_outline_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
                  }),
                  
                  _buildButtonTile(
                    _isRestoring ? AppLocale.searchingPurchases.getString(context) : AppLocale.restorePurchases.getString(context), 
                    _isRestoring ? Icons.hourglass_empty_rounded : Icons.restore_rounded, 
                    () async {
                      if (_isRestoring) return; 
                      
                      setState(() { _isRestoring = true; });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocale.connectingStore.getString(context), style: const TextStyle(fontFamily: 'Impact', letterSpacing: 1.2)), 
                          backgroundColor: Colors.orange
                        )
                      );
                      
                      try {
                        await InAppPurchase.instance.restorePurchases();
                      } catch (e) {
                        setState(() { _isRestoring = false; });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocale.storeUnavailable.getString(context), style: const TextStyle(fontFamily: 'Impact')), 
                            backgroundColor: Colors.redAccent
                          )
                        );
                      }
                    }
                  ),
                  
                  _buildButtonTile(AppLocale.privacyPolicy.getString(context), Icons.privacy_tip_outlined, () {
                    // TODO: Abrir URL con url_launcher
                  }),
                  _buildButtonTile(AppLocale.termsOfService.getString(context), Icons.description_outlined, () {
                    // TODO: Abrir URL con url_launcher
                  }),
                  
                  const SizedBox(height: 40),

                  Center(
                    child: Text(
                      versionText,
                      style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSwitchTile(String title, IconData icon, bool value, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black87, width: 3)),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.black87),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 34,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF9BE15D) : Colors.grey[400],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black87, width: 2),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn,
                    top: 2,
                    left: value ? 26 : 2,
                    right: value ? 2 : 26,
                    child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black87, width: 2))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonTile(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black87, width: 3)),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}