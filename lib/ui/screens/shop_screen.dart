import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/ad_state_manager.dart';

class ShopRealScreen extends StatefulWidget {
  const ShopRealScreen({super.key});

  @override
  State<ShopRealScreen> createState() => _ShopRealScreenState();
}

class _ShopRealScreenState extends State<ShopRealScreen> {
  int _gameCoinsValue = 0; // Monedas recolectadas x 5
  int _boxes = 0;

  @override
  void initState() {
    super.initState();
    _loadEconomy();
  }

  Future<void> _loadEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    // Lógica In-Game: Cada moneda física recolectada vale 5 en la tienda
    int rawCoins = prefs.getInt('collected_coins') ?? 0; // Asegúrate de guardar 'collected_coins' en tu Game
    
    setState(() {
      _gameCoinsValue = rawCoins * 5; 
      _boxes = prefs.getInt('owned_boxes') ?? 0;
    });
  }

  Future<void> _buyBoxWithGameCoins() async {
    if (_gameCoinsValue >= 50) {
      final prefs = await SharedPreferences.getInstance();
      int currentRaw = prefs.getInt('collected_coins') ?? 0;
      
      // Restamos 10 monedas físicas (10 x 5 = 50 de valor)
      await prefs.setInt('collected_coins', currentRaw - 10); 
      await prefs.setInt('owned_boxes', _boxes + 1);
      
      _loadEconomy();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Caja Comprada!", style: TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Monedas insuficientes.", style: TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.red));
    }
  }

  Future<void> _processIAP(int boxAmount) async {
    // TODO: Implementar in_app_purchase real de Google Play / App Store
    // Simulación de éxito por ahora:
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('owned_boxes', _boxes + boxAmount);
    _loadEconomy();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡+$boxAmount Cajas Añadidas!", style: const TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.green));
  }

  Future<void> _removeAdsIAP() async {
    // TODO: Implementar IAP real
    await setAdsRemoved(true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Anuncios Eliminados Permanentemente!", style: TextStyle(fontFamily: 'Impact')), backgroundColor: Colors.purpleAccent));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A252C), // Aún más oscuro para contrastar el dinero
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_rounded, size: 30)),
                  ),
                  const Spacer(),
                  // HUD MONEDAS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD700))),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 20),
                        const SizedBox(width: 5),
                        Text("$_gameCoinsValue", style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 20)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // HUD CAJAS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent)),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 5),
                        Text("$_boxes", style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // CONTENIDO
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Center(child: Text("OFERTAS PREMIUM", style: TextStyle(fontFamily: 'Impact', fontSize: 32, color: Colors.white))),
                  const SizedBox(height: 20),

                  // REMOVE ADS
                  if (!globalAdsRemoved)
                    GestureDetector(
                      onTap: _removeAdsIAP,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent, width: 3)),
                        child: const Row(
                          children: [
                            Icon(Icons.not_interested, color: Colors.white, size: 40),
                            SizedBox(width: 15),
                            Expanded(child: Text("ELIMINAR ANUNCIOS\nPara siempre", style: TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 20))),
                            Text("\$2.99", style: TextStyle(fontFamily: 'Impact', color: Colors.amberAccent, fontSize: 24)),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.02, duration: 1.seconds),
                    ),

                  // BUY WITH COINS
                  GestureDetector(
                    onTap: _buyBoxWithGameCoins,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD700), width: 2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [Icon(Icons.inventory_2, color: Colors.blueAccent, size: 30), SizedBox(width: 10), Text("1 CAJA", style: TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 24))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(10)), child: const Text("50 MONEDAS", style: TextStyle(fontFamily: 'Impact', color: Colors.black))),
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white24, thickness: 2, height: 40),

                  // IAP PACKAGES GRID
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.85,
                    children: [
                      _IapCard(boxes: 5, price: "\$0.99", color: Colors.blue, onTap: () => _processIAP(5)),
                      _IapCard(boxes: 30, price: "\$4.99", color: Colors.green, isPopular: true, onTap: () => _processIAP(30)),
                      _IapCard(boxes: 70, price: "\$9.99", color: Colors.orange, onTap: () => _processIAP(70)),
                      _IapCard(boxes: 160, price: "\$19.99", color: Colors.redAccent, onTap: () => _processIAP(160)),
                      _IapCard(boxes: 500, price: "\$49.99", color: Colors.purpleAccent, onTap: () => _processIAP(500)),
                      _IapCard(boxes: 1000, price: "\$89.99", color: Colors.amber, isBest: true, onTap: () => _processIAP(1000)),
                    ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 3)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, color: color, size: 50),
                const SizedBox(height: 10),
                Text("$boxes CAJAS", style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 24)),
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Text(price, style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 18))),
              ],
            ),
            if (isPopular || isBest)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: isBest ? Colors.amber : Colors.greenAccent, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), topRight: Radius.circular(16))),
                  child: Text(isBest ? "MEJOR" : "POPULAR", style: const TextStyle(fontFamily: 'Impact', color: Colors.black, fontSize: 12)),
                ),
              )
          ],
        ),
      ),
    );
  }
}