import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart'; 
import '../../l10n/app_locale.dart';

import '../../services/sound_manager.dart';
import 'shop_screen.dart';
import '../../services/ad_state_manager.dart';

// ==========================================
// MODO DESARROLLADOR (DEBUG)
const bool kDebugUnlockAll = false;
// ==========================================

// --- MODELO DE SKINS ---
class SkinItem {
  final String id;
  // Usamos una función para traducir el nombre en tiempo real sin romper el estado
  final String Function(BuildContext) nameBuilder; 
  final String path;
  final int requiredAmount;
  final bool isLevelReward;
  final Color rarityColor;

  SkinItem({
    required this.id,
    required this.nameBuilder,
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
  String _selectedSkin = 'ball_default';
  Map<String, int> _cardsOwned = {};
  
  bool _canClaimDaily = false;
  int _freeBoxesToday = 0; 

  RewardedAd? _rewardedAd;

  // --- INVENTARIO DE SKINS ---
  late final List<SkinItem> _trophySkins = [
    SkinItem(
      id: 'ball_default',
      nameBuilder: (context) => AppLocale.classicSkin.getString(context),
      path: 'assets/images/ball/ball_default.png',
      requiredAmount: 0,
      rarityColor: Colors.white70,
    ),
    ...List.generate(
      9,
      (i) => SkinItem(
        id: 'ball_level_0${i + 1}',
        nameBuilder: (context) => "${AppLocale.levelSkin.getString(context)} ${i + 1}",
        path: 'assets/images/ball/level/ball_level_0${i + 1}.png',
        requiredAmount: (i + 1) * 50,
        isLevelReward: true,
        rarityColor: Colors.cyanAccent,
      ),
    ),
  ];

  late final List<SkinItem> _commonSkins = List.generate(
    4,
    (i) => SkinItem(
      id: 'ball_common_0${i + 1}',
      nameBuilder: (context) => AppLocale.commonSkin.getString(context),
      path: 'assets/images/ball/pay/common/ball_common_0${i + 1}.png',
      requiredAmount: 49,
      rarityColor: const Color(0xFF9BE15D),
    ),
  );

  late final List<SkinItem> _rareSkins = List.generate(
    3,
    (i) => SkinItem(
      id: 'ball_rare_0${i + 1}',
      nameBuilder: (context) => AppLocale.rareSkin.getString(context),
      path: 'assets/images/ball/pay/rare/ball_rare_0${i + 1}.png',
      requiredAmount: 99,
      rarityColor: Colors.blueAccent,
    ),
  );

  late final List<SkinItem> _epicSkins = List.generate(
    3,
    (i) => SkinItem(
      id: 'ball_epic_0${i + 1}',
      nameBuilder: (context) => AppLocale.epicSkin.getString(context),
      path: 'assets/images/ball/pay/epic/ball_epic_0${i + 1}.png',
      requiredAmount: 149,
      rarityColor: Colors.purpleAccent,
    ),
  );

  late final List<SkinItem> _legendarySkins = List.generate(
    3,
    (i) => SkinItem(
      id: 'ball_legendary_0${i + 1}',
      nameBuilder: (context) => AppLocale.legendarySkin.getString(context),
      path: 'assets/images/ball/pay/legendary/ball_legendary_0${i + 1}.png',
      requiredAmount: 199,
      rarityColor: Colors.orangeAccent,
    ),
  );

  late final List<SkinItem> _championSkins = List.generate(
    3,
    (i) => SkinItem(
      id: 'ball_champion_0${i + 1}',
      nameBuilder: (context) => AppLocale.championSkin.getString(context),
      path: 'assets/images/ball/pay/champion/ball_champion_0${i + 1}.png',
      requiredAmount: 300,
      rarityColor: Colors.redAccent,
    ),
  );

  @override
  void initState() {
    super.initState();
    _playShopMusic();
    _loadData();
    _loadRewardedAd();
  }

  void _playShopMusic() {
    SoundManager.instance.playMusic('shop');
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month}-${now.day}";

    String lastDailyStr = prefs.getString('last_daily_box') ?? '';
    String lastFreeBoxStr = prefs.getString('last_freebox_date') ?? '';
    
    if (lastFreeBoxStr != todayStr) {
      await prefs.setInt('free_boxes_today', 0);
      await prefs.setString('last_freebox_date', todayStr);
      _freeBoxesToday = 0;
    } else {
      _freeBoxesToday = prefs.getInt('free_boxes_today') ?? 0;
    }

    Map<String, int> loadedCards = {};
    for (var list in [_commonSkins, _rareSkins, _epicSkins, _legendarySkins, _championSkins]) {
      for (var skin in list) {
        loadedCards[skin.id] = prefs.getInt('cards_${skin.id}') ?? 0;
      }
    }

    setState(() {
      _boxes = prefs.getInt('owned_boxes') ?? 0;
      _highScore = prefs.getInt('highScore') ?? 0;
      _selectedSkin = prefs.getString('selected_skin') ?? 'ball_default';
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
    _showFeedback(AppLocale.dailyBoxClaimed.getString(context), Colors.green);
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

  Future<void> _grantFreeBoxReward() async {
    _freeBoxesToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('free_boxes_today', _freeBoxesToday);
    await _saveBoxes(_boxes + 1);
    
    String claimMsg = AppLocale.boxClaimedToday.getString(context).replaceAll('%1', _freeBoxesToday.toString());
    _showFeedback(claimMsg, Colors.green);
    setState(() {});
  }

  void _watchAdForBox() {
    if (_freeBoxesToday >= 5) {
      _showFeedback(AppLocale.dailyLimitReached.getString(context), Colors.redAccent);
      return;
    }

    if (globalAdsRemoved) {
      _grantFreeBoxReward();
      return;
    }

    if (_rewardedAd == null) {
      _showFeedback(AppLocale.loadingAd.getString(context), Colors.orange);
      _loadRewardedAd();
      return;
    }
    
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _grantFreeBoxReward();
      },
    );
    _rewardedAd = null;
    _loadRewardedAd();
  }

  Future<void> _openBox() async {
    if (_boxes <= 0) {
      _showFeedback(AppLocale.noBoxes.getString(context), Colors.redAccent);
      return;
    }
    await _saveBoxes(_boxes - 1);
    SoundManager.instance.sfxPoder(); 

    final prefs = await SharedPreferences.getInstance();
    final random = Random();
    List<SkinItem> allPaySkins = [
      ..._commonSkins, ..._rareSkins, ..._epicSkins, ..._legendarySkins, ..._championSkins,
    ];

    List<SkinItem> wonCards = [];

    for (int i = 0; i < 5; i++) {
      SkinItem wonSkin = allPaySkins[random.nextInt(allPaySkins.length)];
      wonCards.add(wonSkin); 

      int currentVal = _cardsOwned[wonSkin.id] ?? 0;
      if (currentVal < wonSkin.requiredAmount) {
        currentVal++;
        await prefs.setInt('cards_${wonSkin.id}', currentVal);
        _cardsOwned[wonSkin.id] = currentVal;
      }
    }
    
    setState(() {});
    if (mounted) _showGachaResultDialog(context, wonCards);
  }

  Future<void> _selectSkin(SkinItem skin) async {
    bool isUnlocked = false;

    if (kDebugUnlockAll || skin.id == 'ball_default') {
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
      SoundManager.instance.sfxBote();
    } else {
      _showFeedback(AppLocale.skinLocked.getString(context), Colors.redAccent);
    }
  }

  void _showFeedback(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Impact', fontSize: 16, color: Colors.white, letterSpacing: 1.2), textAlign: TextAlign.center),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showGachaResultDialog(BuildContext context, List<SkinItem> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A2744), Color(0xFF0F172A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFFFD700), width: 3),
            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 25, bottom: 10),
                child: Text(
                  AppLocale.newCards.getString(context),
                  style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Impact', fontSize: 32, letterSpacing: 2.0, shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 2))]),
                ).animate().scaleXY(begin: 0.5, end: 1.0, duration: 500.ms, curve: Curves.elasticOut),
              ),
              const Divider(color: Colors.white24, thickness: 2, indent: 40, endIndent: 40),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 15,
                    children: items.map((item) => _buildRewardCard(item)).toList(),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9BE15D),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.black87, width: 3)),
                      elevation: 8,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocale.collect.getString(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Impact', letterSpacing: 1.5)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard(SkinItem item) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Container(
        width: 90,
        height: 120,
        decoration: BoxDecoration(
          color: item.rarityColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.rarityColor, width: 2),
          boxShadow: [BoxShadow(color: item.rarityColor.withOpacity(0.2), blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(item.path, fit: BoxFit.contain, errorBuilder: (_,__,___) => Icon(Icons.sports_baseball, color: item.rarityColor)),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)), border: Border(top: BorderSide(color: item.rarityColor, width: 2))),
              child: Column(
                children: [
                  Text(
                    item.nameBuilder(context),
                    style: TextStyle(color: item.rarityColor, fontSize: 10, fontFamily: 'Impact', letterSpacing: 1.0),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const Text("+1", style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Impact')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black87, width: 3)),
                      child: const Icon(Icons.arrow_back_rounded, size: 28, color: Colors.black87),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/principales/chest.png', width: 30, height: 30, errorBuilder: (_,__,___) => const Icon(Icons.inventory_2_rounded, color: Color(0xFFFFD700), size: 28)),
                      const SizedBox(width: 8),
                      _BorderedText(
                        text: "${AppLocale.mysteryBoxes.getString(context)}: $_boxes", 
                        fontSize: 20, fillColor: const Color(0xFFFFD700), strokeColor: Colors.black87, strokeWidth: 4
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.unarchive_rounded,
                          title: AppLocale.open.getString(context),
                          gradientColors: _boxes > 0 ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)] : [Colors.grey[700]!, Colors.grey[500]!],
                          onTap: _openBox,
                          isPulsing: _boxes > 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.storefront_rounded,
                          title: AppLocale.buy.getString(context),
                          gradientColors: const [Color(0xFFE65100), Color(0xFFFFCA28)],
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopRealScreen()));
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_canClaimDaily) ...[
                    _ActionCard(
                      icon: Icons.card_giftcard_rounded,
                      title: AppLocale.claimDailyBox.getString(context),
                      gradientColors: const [Color(0xFF1B5E20), Color(0xFF66BB6A)],
                      onTap: _claimDaily,
                    ).animate().scaleXY(begin: 0.9, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 10),
                  ],

                  _ActionCard(
                    icon: globalAdsRemoved ? Icons.star_rounded : Icons.play_circle_fill_rounded,
                    title: globalAdsRemoved ? AppLocale.claimPremiumBox.getString(context) : AppLocale.watchVideoFreeBox.getString(context),
                    gradientColors: _freeBoxesToday < 5 
                      ? const [Color(0xFF6A1B9A), Color(0xFFCE93D8)] 
                      : [Colors.grey[800]!, Colors.grey[600]!], 
                    onTap: _watchAdForBox,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -4))],
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCategorySection(AppLocale.trophyRoad.getString(context), Colors.cyanAccent, _trophySkins),
                    _buildCategorySection(AppLocale.commons.getString(context), const Color(0xFF9BE15D), _commonSkins),
                    _buildCategorySection(AppLocale.rares.getString(context), Colors.blueAccent, _rareSkins),
                    _buildCategorySection(AppLocale.epics.getString(context), Colors.purpleAccent, _epicSkins),
                    _buildCategorySection(AppLocale.legendaries.getString(context), Colors.orangeAccent, _legendarySkins),
                    _buildCategorySection(AppLocale.champions.getString(context), Colors.redAccent, _championSkins),
                    const SizedBox(height: 40),
                  ],
                ),
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
          padding: const EdgeInsets.only(bottom: 12, left: 5),
          child: _BorderedText(text: title, fontSize: 22, fillColor: color, strokeColor: Colors.black87, strokeWidth: 5),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 12, childAspectRatio: 0.65,
          ),
          itemCount: skins.length,
          itemBuilder: (context, index) {
            final skin = skins[index];
            bool isUnlocked = false;
            int currentProgress = 0;

            if (kDebugUnlockAll || skin.id == 'ball_default') {
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Colors.white : skin.rarityColor, width: isSelected ? 3 : 2),
                  boxShadow: isSelected ? [BoxShadow(color: skin.rarityColor.withOpacity(0.6), blurRadius: 8)] : [const BoxShadow(color: Colors.black54, offset: Offset(0, 3))],
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Opacity(
                              opacity: isUnlocked ? 1.0 : 0.4,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(skin.path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.sports_baseball, size: 30, color: Colors.white24)),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isUnlocked ? (isSelected ? skin.rarityColor : Colors.black87) : Colors.black87,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                            border: Border(top: BorderSide(color: skin.rarityColor, width: 2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUnlocked)
                                Text(
                                  isSelected ? AppLocale.active.getString(context) : AppLocale.use.getString(context),
                                  style: TextStyle(fontFamily: 'Impact', fontSize: 12, color: isSelected ? Colors.black87 : Colors.white),
                                )
                              else if (skin.isLevelReward)
                                Text("${skin.requiredAmount}PTS", style: const TextStyle(fontFamily: 'Impact', fontSize: 12, color: Colors.cyanAccent))
                              else ...[
                                Text("$currentProgress/${skin.requiredAmount}", style: TextStyle(fontFamily: 'Impact', fontSize: 11, color: skin.rarityColor)),
                                const SizedBox(height: 2),
                                Container(
                                  height: 6, margin: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.black, width: 1)),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (currentProgress / skin.requiredAmount).clamp(0.0, 1.0),
                                    child: Container(decoration: BoxDecoration(color: skin.rarityColor, borderRadius: BorderRadius.circular(3))),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isUnlocked)
                      Positioned.fill(
                        child: Align(alignment: const Alignment(0, -0.2), child: Icon(Icons.lock_rounded, size: 35, color: Colors.white.withOpacity(0.9), shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ================= CLASES AUXILIARES =================

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isPulsing;

  const _ActionCard({required this.icon, required this.title, required this.gradientColors, required this.onTap, this.isPulsing = false});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity, height: 55, 
        margin: EdgeInsets.only(top: _isPressed ? 4.0 : 0.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: _isPressed ? [] : [BoxShadow(color: widget.gradientColors.last.withOpacity(0.5), offset: const Offset(0, 4), blurRadius: 6), const BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 3)],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), gradient: LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 22, shadows: const [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)]),
                  const SizedBox(width: 6),
                  Text(widget.title, style: const TextStyle(fontFamily: 'Impact', fontSize: 16, color: Colors.white, letterSpacing: 0.8, shadows: [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)])),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isPulsing) {
      return card.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.03, duration: 800.ms);
    }
    return card;
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