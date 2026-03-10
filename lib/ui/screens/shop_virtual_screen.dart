import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'shop_screen.dart';
import '../../services/ad_state_manager.dart';

// ==========================================
// MODO DESARROLLADOR (DEBUG)
// Cambia a true para desbloquear todas las skins instantáneamente
const bool kDebugUnlockAll = false; 
// ==========================================

// --- MODELO DE SKINS ---
class SkinItem {
  final String id;
  final String path;
  final int requiredAmount;
  final bool isLevelReward;
  final Color rarityColor;

  SkinItem({
    required this.id, 
    required this.path, 
    required this.requiredAmount, 
    this.isLevelReward = false,
    required this.rarityColor,
  });
}

class ShopVirtualScreen extends StatefulWidget {
  const ShopVirtualScreen({super.key});

  @override
  State<ShopVirtualScreen> createState() => _ShopVirtualScreenState();
}

class _ShopVirtualScreenState extends State<ShopVirtualScreen> {
  int _boxes = 0;
  int _highScore = 0;
  String _selectedSkin = 'ball_standar';
  Map<String, int> _cardsOwned = {};
  bool _canClaimDaily = false;
  
  RewardedAd? _rewardedAd;

  // --- INVENTARIO DE SKINS REORGANIZADO ---
  final List<SkinItem> _trophySkins = [
    SkinItem(id: 'ball_standar', path: 'assets/images/balls/ball_standar.png', requiredAmount: 0, rarityColor: Colors.white70),
    ...List.generate(9, (i) => SkinItem(id: 'ball_nivel_0${i+1}', path: 'assets/images/balls/level/ball_nivel_0${i+1}.png', requiredAmount: (i+1)*50, isLevelReward: true, rarityColor: Colors.cyanAccent))
  ];
  
  final List<SkinItem> _commonSkins = List.generate(3, (i) => SkinItem(id: 'ball_common_0${i+1}', path: 'assets/images/balls/pay/common/ball_common_0${i+1}.png', requiredAmount: 49, rarityColor: const Color(0xFF9BE15D)));
  final List<SkinItem> _rareSkins = List.generate(3, (i) => SkinItem(id: 'ball_rare_0${i+1}', path: 'assets/images/balls/pay/rare/ball_rare_0${i+1}.png', requiredAmount: 99, rarityColor: Colors.blueAccent));
  final List<SkinItem> _epicSkins = List.generate(3, (i) => SkinItem(id: 'ball_epic_0${i+1}', path: 'assets/images/balls/pay/epic/ball_epic_0${i+1}.png', requiredAmount: 149, rarityColor: Colors.purpleAccent));
  final List<SkinItem> _legendarySkins = List.generate(3, (i) => SkinItem(id: 'ball_legendary_0${i+1}', path: 'assets/images/balls/pay/legendary/ball_legendary_0${i+1}.png', requiredAmount: 199, rarityColor: Colors.orangeAccent));
  final List<SkinItem> _championSkins = List.generate(3, (i) => SkinItem(id: 'ball_champion_0${i+1}', path: 'assets/images/balls/pay/champion/ball_champion_0${i+1}.png', requiredAmount: 300, rarityColor: Colors.redAccent));

  @override
  void initState() {
    super.initState();
    _playShopMusic();
    _loadData();
    _loadRewardedAd();
  }

  void _playShopMusic() async {
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('shop.mp3', volume: 0.6);
  }

  @override
  void dispose() {
    FlameAudio.bgm.stop();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String lastDailyStr = prefs.getString('last_daily_box') ?? '';
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month}-${now.day}";
    
    Map<String, int> loadedCards = {};
    for (var list in [_commonSkins, _rareSkins, _epicSkins, _legendarySkins, _championSkins]) {
      for (var skin in list) { loadedCards[skin.id] = prefs.getInt('cards_${skin.id}') ?? 0; }
    }

    setState(() {
      _boxes = prefs.getInt('owned_boxes') ?? 0;
      _highScore = prefs.getInt('highScore') ?? 0;
      _selectedSkin = prefs.getString('selected_skin') ?? 'ball_standar';
      _canClaimDaily = (lastDailyStr != todayStr);
      _cardsOwned = loadedCards;
    });
  }

  Future<void> _saveBoxes(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('owned_boxes', amount);
    setState(() => _boxes = amount);
  }

  Future<void> _claimDaily() async {
    if (!_canClaimDaily) return;
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    await prefs.setString('last_daily_box', "${now.year}-${now.month}-${now.day}");
    await _saveBoxes(_boxes + 1);
    setState(() => _canClaimDaily = false);
    _showFeedback("¡CAJA DIARIA OBTENIDA!", Colors.green);
  }

  void _loadRewardedAd() {
    if (globalAdsRemoved) return;
    RewardedAd.load(
      adUnitId: getStoreBoxRewardId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  void _watchAdForBox() {
    if (globalAdsRemoved) {
      _saveBoxes(_boxes + 1);
      _showFeedback("¡CAJA GRATIS (PREMIUM)!", Colors.purpleAccent);
      return;
    }
    if (_rewardedAd == null) {
      _showFeedback("Cargando anuncio...", Colors.orange);
      return;
    }
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      _saveBoxes(_boxes + 1);
      _showFeedback("¡CAJA OBTENIDA!", Colors.green);
    });
    _rewardedAd = null;
    _loadRewardedAd();
  }

  Future<void> _openBox() async {
    if (_boxes <= 0) {
      _showFeedback("NO TIENES CAJAS", Colors.redAccent);
      return;
    }
    await _saveBoxes(_boxes - 1);
    
    final prefs = await SharedPreferences.getInstance();
    final random = Random();
    List<SkinItem> allPaySkins = [..._commonSkins, ..._rareSkins, ..._epicSkins, ..._legendarySkins, ..._championSkins];
    
    for (int i = 0; i < 5; i++) {
      SkinItem wonSkin = allPaySkins[random.nextInt(allPaySkins.length)];
      int currentVal = _cardsOwned[wonSkin.id] ?? 0;
      if (currentVal < wonSkin.requiredAmount) {
        currentVal++;
        await prefs.setInt('cards_${wonSkin.id}', currentVal);
        _cardsOwned[wonSkin.id] = currentVal;
      }
    }
    setState(() {});
    _showFeedback("¡+5 CARTAS! OBTENER MÁS CAJAS", Colors.blueAccent);
  }

  Future<void> _selectSkin(SkinItem skin) async {
    bool isUnlocked = false;
    
    // LÓGICA DEBUG + PRODUCCIÓN
    if (kDebugUnlockAll || skin.id == 'ball_standar') {
      isUnlocked = true;
    } else if (skin.isLevelReward) {
      isUnlocked = _highScore >= skin.requiredAmount;
    } else {
      isUnlocked = (_cardsOwned[skin.id] ?? 0) >= skin.requiredAmount;
    }

    if (isUnlocked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_skin', skin.id);
      setState(() => _selectedSkin = skin.id);
    } else {
      _showFeedback("SKIN BLOQUEADA", Colors.redAccent);
    }
  }

  void _showFeedback(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Impact', fontSize: 18, color: Colors.white, letterSpacing: 1.2), textAlign: TextAlign.center), 
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), 
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black87, width: 3)), 
                      child: const Icon(Icons.arrow_back_rounded, size: 28, color: Colors.black87)
                    ),
                  ),
                  const Expanded(child: Center(child: _BorderedText(text: "INVENTARIO", fontSize: 36, fillColor: Colors.white, strokeColor: Colors.black87))),
                  const SizedBox(width: 48), 
                ],
              ),
            ),

            // --- SECCIÓN GACHA ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black87, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_rounded, color: Colors.blueAccent, size: 36),
                      const SizedBox(width: 10),
                      _BorderedText(text: "CAJAS: $_boxes", fontSize: 32, fillColor: const Color(0xFFFFD700), strokeColor: Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  if (_canClaimDaily) ...[
                    _PremiumButton(text: "CAJA DIARIA GRATIS", icon: Icons.card_giftcard_rounded, gradient: const [Colors.green, Colors.lightGreen], onTap: _claimDaily)
                      .animate().scaleXY(begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 12),
                  ],
                  
                  _PremiumButton(text: "ABRIR CAJA (-1)", icon: Icons.unarchive_rounded, gradient: _boxes > 0 ? const [Colors.blue, Colors.lightBlueAccent] : const [Colors.grey, Colors.blueGrey], isPulsing: _boxes > 0, onTap: _openBox),
                  const SizedBox(height: 12),
                  
                  _PremiumButton(text: "VER VIDEO PARA CAJA GRATIS", icon: Icons.play_circle_fill_rounded, gradient: const [Colors.purple, Colors.purpleAccent], onTap: _watchAdForBox),
                  const SizedBox(height: 12),
                  
                  _PremiumButton(text: "CONSIGUE MÁS CAJAS", icon: Icons.store_rounded, gradient: const [Colors.orange, Colors.amber], onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopRealScreen()));
                    _loadData(); 
                  }),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // --- LISTA DE SKINS ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildCategorySection("CAMINO DE TROFEOS", Colors.cyanAccent, _trophySkins),
                  _buildCategorySection("COMUNES", const Color(0xFF9BE15D), _commonSkins),
                  _buildCategorySection("RARAS", Colors.blueAccent, _rareSkins),
                  _buildCategorySection("ÉPICAS", Colors.purpleAccent, _epicSkins),
                  _buildCategorySection("LEGENDARIAS", Colors.orangeAccent, _legendarySkins),
                  _buildCategorySection("CHAMPIONS", Colors.redAccent, _championSkins),
                  const SizedBox(height: 40), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, Color color, List<SkinItem> skins) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12, left: 5),
          child: _BorderedText(text: title, fontSize: 24, fillColor: color, strokeColor: Colors.black87, strokeWidth: 5),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 15, childAspectRatio: 0.68),
          itemCount: skins.length,
          itemBuilder: (context, index) {
            final skin = skins[index];
            bool isUnlocked = false;
            int currentProgress = 0;

            // LÓGICA DEBUG + PRODUCCIÓN (VISUAL)
            if (kDebugUnlockAll || skin.id == 'ball_standar') {
              isUnlocked = true;
            } else if (skin.isLevelReward) {
              isUnlocked = _highScore >= skin.requiredAmount;
            } else {
              currentProgress = _cardsOwned[skin.id] ?? 0;
              isUnlocked = currentProgress >= skin.requiredAmount;
            }

            bool isSelected = _selectedSkin == skin.id;

            return GestureDetector(
              onTap: () => _selectSkin(skin),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? skin.rarityColor.withOpacity(0.2) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isSelected ? Colors.white : skin.rarityColor, width: isSelected ? 4 : 2),
                  boxShadow: isSelected ? [BoxShadow(color: skin.rarityColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)] : [const BoxShadow(color: Colors.black54, offset: Offset(0, 4))],
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Opacity(
                              opacity: isUnlocked ? 1.0 : 0.6,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Image.asset(skin.path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.sports_baseball, size: 40, color: Colors.white24)),
                              ),
                            ),
                          ),
                        ),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isUnlocked ? (isSelected ? skin.rarityColor : Colors.black87) : Colors.black87,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            border: Border(top: BorderSide(color: skin.rarityColor, width: 2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUnlocked)
                                Text(isSelected ? "EQUIPADA" : "USAR", style: TextStyle(fontFamily: 'Impact', fontSize: 14, color: isSelected ? Colors.black87 : Colors.white))
                              else if (skin.isLevelReward)
                                Text("${skin.requiredAmount} PTS", style: const TextStyle(fontFamily: 'Impact', fontSize: 14, color: Colors.cyanAccent))
                              else ...[
                                Text("$currentProgress / ${skin.requiredAmount}", style: TextStyle(fontFamily: 'Impact', fontSize: 12, color: skin.rarityColor)),
                                const SizedBox(height: 3),
                                Container(
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black, width: 1)),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (currentProgress / skin.requiredAmount).clamp(0.0, 1.0),
                                    child: Container(decoration: BoxDecoration(color: skin.rarityColor, borderRadius: BorderRadius.circular(3))),
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isUnlocked)
                      Positioned.fill(
                        child: Align(
                          alignment: const Alignment(0, -0.2), 
                          child: Icon(Icons.lock_rounded, size: 45, color: Colors.white.withOpacity(0.9), shadows: const [Shadow(color: Colors.black, blurRadius: 10)]),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ================= CLASES AUXILIARES =================

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

class _PremiumButton extends StatefulWidget {
  final String text;
  final List<Color> gradient;
  final VoidCallback onTap;
  final IconData icon;
  final bool isPulsing;

  const _PremiumButton({required this.text, required this.gradient, required this.onTap, required this.icon, this.isPulsing = false});

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 60,
        margin: EdgeInsets.only(top: _isPressed ? 4.0 : 0.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black87, width: 3),
          boxShadow: _isPressed ? [] : [const BoxShadow(color: Colors.black87, offset: Offset(0, 5))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 28, shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1))]),
              const SizedBox(width: 10),
              Flexible(child: _BorderedText(text: widget.text, fontSize: 22, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 5)),
            ],
          ),
        ),
      ),
    );

    if (widget.isPulsing) {
      return buttonContent.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.02, duration: 800.ms);
    }
    return buttonContent;
  }
}