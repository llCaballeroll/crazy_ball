import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// PAQUETE DE IDIOMAS
import 'package:flutter_localization/flutter_localization.dart'; 
import '../../l10n/app_locale.dart';

import '../../services/ad_state_manager.dart';
import '../../services/sound_manager.dart';

// ============================================================================
// ⚙️ CONFIGURACIÓN DE ENTORNO
// Cambia kDevMode a FALSE antes de compilar para producción (Google Play / App Store)
// ============================================================================
const bool kDevMode = false; 

class ShopRealScreen extends StatefulWidget {
  const ShopRealScreen({super.key});

  @override
  State<ShopRealScreen> createState() => _ShopRealScreenState();
}

class _ShopRealScreenState extends State<ShopRealScreen> {
  static const String _kIdRemoveAds  = 'crazyball_remove_ads';
  static const String _kIdPackTier1  = 'crazyball_box_pack_5'; 
  static const String _kIdPackTier2  = 'crazyball_box_pack_30';
  static const String _kIdPackTier3  = 'crazyball_box_pack_70';
  static const String _kIdPackTier4  = 'crazyball_box_pack_160';
  static const String _kIdPackTier5  = 'crazyball_box_pack_500';
  static const String _kIdPackTier6  = 'crazyball_box_pack_1000';

  final Map<String, dynamic> _visualAssets = {
    _kIdPackTier1: {'amount': 5,    'price': '\$0.99', 'color': Colors.blue},
    _kIdPackTier2: {'amount': 30,   'price': '\$4.99', 'color': Colors.green, 'popular': true},
    _kIdPackTier3: {'amount': 70,   'price': '\$9.99', 'color': Colors.orange},
    _kIdPackTier4: {'amount': 160,  'price': '\$19.99', 'color': Colors.redAccent},
    _kIdPackTier5: {'amount': 500,  'price': '\$49.99', 'color': Colors.purpleAccent},
    _kIdPackTier6: {'amount': 1000, 'price': '\$89.99', 'color': Colors.amber, 'best': true},
  };

  int _rawGameCoins = 0; 
  int _gameCoinsValue = 0; 
  int _boxes = 0;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _available = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEconomy();
    if (kDevMode) {
      _loadMockProducts();
    } else {
      _initializeInAppPurchase();
    }
  }

  @override
  void dispose() {
    if (!kDevMode) _subscription.cancel();
    super.dispose();
  }

  Future<void> _loadEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    int rawCoins = prefs.getInt('coins') ?? 0; 
    
    setState(() {
      _rawGameCoins = rawCoins;
      _gameCoinsValue = rawCoins * 5; 
      _boxes = prefs.getInt('owned_boxes') ?? 0;
    });
  }

  void _loadMockProducts() {
    debugPrint("⚠️ MODO DESARROLLADOR ACTIVADO (Mock IAP)");
    setState(() {
      _products = _visualAssets.entries.map((e) {
        return ProductDetails(
          id: e.key,
          title: "${e.value['amount']} Boxes", // Título falso para pruebas
          description: "Box Pack",
          price: e.value['price'] ?? "0.00",
          rawPrice: 0,
          currencyCode: 'USD',
        );
      }).toList();
      
      _products.add(ProductDetails(
        id: _kIdRemoveAds, title: "Remove Ads", description: "Forever", price: "\$2.99", rawPrice: 0, currencyCode: 'USD'
      ));
      
      _loading = false;
      _available = true;
    });
  }

  Future<void> _debugAddCoins() async {
    if (!kDevMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _rawGameCoins + 10);
    _loadEconomy();
    SoundManager.instance.sfxMoneda();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🐞 DEV: +50 Coins added", style: TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.amber));
  }

  Future<void> _initializeInAppPurchase() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('Error en IAP: $error');
    });

    _available = await _inAppPurchase.isAvailable();
    if (_available) {
      final Set<String> ids = _visualAssets.keys.toSet()..add(_kIdRemoveAds);
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(ids);
      
      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() { _loading = false; _available = false; });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // En progreso
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.purchaseError.getString(context), style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.redAccent));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          _deliverIapReward(purchaseDetails.productID);
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
        }
      }
    }
  }

  void _buyProduct(ProductDetails product) {
    SoundManager.instance.sfxBote();
    if (kDevMode) {
      _deliverIapReward(product.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🐞 COMPRA DEV EXITOSA: ${product.id}", style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.green));
      return;
    }

    HapticFeedback.heavyImpact();
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    if (product.id == _kIdRemoveAds) {
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    }
  }

  Future<void> _deliverIapReward(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (productId == _kIdRemoveAds) {
      await setAdsRemoved(true); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.adsRemovedSuccess.getString(context), style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.purpleAccent));
      setState(() {});
    } else {
      final config = _visualAssets[productId];
      if (config != null) {
        int amount = config['amount'] as int;
        await prefs.setInt('owned_boxes', _boxes + amount);
        _loadEconomy();
        if (mounted) {
          String msg = AppLocale.boxesAdded.getString(context).replaceAll('%1', amount.toString());
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.green));
        }
      }
    }
  }

  Future<void> _buyBoxWithGameCoins() async {
    if (_gameCoinsValue >= 50) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('coins', _rawGameCoins - 10); 
      await prefs.setInt('owned_boxes', _boxes + 1);
      
      SoundManager.instance.sfxMoneda();
      _loadEconomy();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.boxPurchased.getString(context), style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.green));
    } else {
      SoundManager.instance.sfxMorir(); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.insufficientCoins.getString(context), style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    ProductDetails? removeAdsProduct;
    List<ProductDetails> boxProducts = [];

    if (!_loading && _products.isNotEmpty) {
      try {
        removeAdsProduct = _products.firstWhere((p) => p.id == _kIdRemoveAds);
      } catch (_) {}
      boxProducts = _products.where((p) => p.id != _kIdRemoveAds).toList();
    }

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
                  
                  GestureDetector(
                    onTap: _debugAddCoins, 
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFFD700), width: 2)),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 24),
                          const SizedBox(width: 6),
                          _BorderedText(text: "$_gameCoinsValue", fontSize: 20, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent, width: 2)),
                    child: Row(
                      children: [
                        Image.asset('assets/images/principales/chest.png', width: 24, height: 24),
                        const SizedBox(width: 6),
                        _BorderedText(text: "$_boxes", fontSize: 20, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -4))],
                ),
                child: _loading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : (!_available && !kDevMode)
                    ? Center(child: Text(AppLocale.storeUnavailable.getString(context), style: const TextStyle(color: Colors.white, fontFamily: 'Impact', fontSize: 24)))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _BorderedText(text: AppLocale.premiumStore.getString(context), fontSize: 32, fillColor: Colors.white, strokeColor: Colors.black87),
                          const SizedBox(height: 20),

                          if (!globalAdsRemoved && removeAdsProduct != null)
                            GestureDetector(
                              onTap: () => _buyProduct(removeAdsProduct!),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]), 
                                  borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD700), width: 3),
                                  boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.block_rounded, color: Colors.white, size: 45),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _BorderedText(text: AppLocale.removeAdsUpper.getString(context), fontSize: 20, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4),
                                          Text(AppLocale.playWithoutInterruptions.getString(context), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(12)),
                                      child: Text(removeAdsProduct.price, style: const TextStyle(fontFamily: 'Impact', color: Colors.black87, fontSize: 18)),
                                    )
                                  ],
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.02, duration: 1.seconds),
                            ),

                          GestureDetector(
                            onTap: _buyBoxWithGameCoins,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 30),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), 
                                border: Border.all(color: const Color(0xFFFFD700), width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 6)]
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset('assets/images/principales/chest.png', width: 30, height: 30),
                                      const SizedBox(width: 10),
                                      _BorderedText(text: AppLocale.plusOneBox.getString(context), fontSize: 24, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4),
                                    ]
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                                    decoration: BoxDecoration(color: _gameCoinsValue >= 50 ? const Color(0xFF9BE15D) : Colors.grey[700], borderRadius: BorderRadius.circular(12)), 
                                    child: Text(AppLocale.fiftyCoins.getString(context), style: const TextStyle(fontFamily: 'Impact', color: Colors.black87, fontSize: 16))
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(color: Colors.white24, thickness: 2, height: 10),
                          const SizedBox(height: 20),

                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85),
                            itemCount: boxProducts.length,
                            itemBuilder: (context, index) {
                              final product = boxProducts[index];
                              final config = _visualAssets[product.id] ?? {'amount': 0, 'color': Colors.grey};
                              return _IapCard(
                                boxes: config['amount'], 
                                price: product.price, 
                                color: config['color'], 
                                isPopular: config['popular'] ?? false, 
                                isBest: config['best'] ?? false, 
                                onTap: () => _buyProduct(product)
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                          
                          if (!kDevMode)
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  _inAppPurchase.restorePurchases();
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocale.restoringPurchases.getString(context), style: const TextStyle(fontFamily: 'Impact'))));
                                },
                                child: Text(AppLocale.restorePurchases.getString(context), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IapCard extends StatelessWidget {
  final int boxes;
  final String price;
  final Color color;
  final bool isPopular;
  final bool isBest;
  final VoidCallback onTap;

  const _IapCard({required this.boxes, required this.price, required this.color, this.isPopular = false, this.isBest = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String xBoxesText = AppLocale.xBoxes.getString(context).replaceAll('%1', boxes.toString());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: color, width: 3),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/principales/chest.png', width: 50, height: 50),
                const SizedBox(height: 12),
                _BorderedText(text: xBoxesText, fontSize: 22, fillColor: Colors.white, strokeColor: Colors.black87, strokeWidth: 4),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), 
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), 
                  child: Text(price, style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 18))
                ),
              ],
            ),
            if (isPopular || isBest)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBest ? const Color(0xFFFFD700) : const Color(0xFF9BE15D), 
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), topRight: Radius.circular(18))
                  ),
                  child: Text(isBest ? AppLocale.best.getString(context) : AppLocale.popular.getString(context), style: const TextStyle(fontFamily: 'Impact', color: Colors.black87, fontSize: 12)),
                ),
              )
          ],
        ),
      ).animate(target: (isPopular || isBest) ? 1 : 0).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut).then().scaleXY(begin: 1.05, end: 1.0, duration: 800.ms, curve: Curves.easeInOut),
    );
  }
}

class _BorderedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const _BorderedText({
    required this.text, required this.fontSize, required this.fillColor, required this.strokeColor, this.strokeWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = strokeColor)),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize, fontFamily: 'Impact', color: fillColor)),
      ],
    );
  }
}