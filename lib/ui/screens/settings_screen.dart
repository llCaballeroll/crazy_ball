import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'tutorial_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
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
    await prefs.setBool(key, !currentValue);
    setState(() {
      if (key == 'musicOn') _isMusicOn = !_isMusicOn;
      if (key == 'soundOn') _isSoundOn = !_isSoundOn;
      if (key == 'vibrationOn') _isVibrationOn = !_isVibrationOn;
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
    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9), // Mismo fondo del menú principal
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón de regreso
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        "AJUSTES",
                        style: TextStyle(fontSize: 40, fontFamily: 'Impact', color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(2, 2))]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), // Balance visual
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // --- SECCIÓN: CONTROLES ---
                  _buildSectionTitle("AUDIO Y CONTROLES"),
                  _buildSwitchTile("Música", Icons.music_note_rounded, _isMusicOn, () => _toggleSetting('musicOn', _isMusicOn)),
                  _buildSwitchTile("Efectos de Sonido", Icons.volume_up_rounded, _isSoundOn, () => _toggleSetting('soundOn', _isSoundOn)),
                  _buildSwitchTile("Vibración", Icons.vibration_rounded, _isVibrationOn, () => _toggleSetting('vibrationOn', _isVibrationOn)),
                  
                  const SizedBox(height: 30),

                  // --- SECCIÓN: JUEGO Y LEGAL ---
                  _buildSectionTitle("INFORMACIÓN"),
                  _buildButtonTile("¿Cómo jugar?", Icons.help_outline_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TutorialScreen()));
                  }),
                  _buildButtonTile("Restaurar Compras", Icons.restore_rounded, () {
                    // TODO: Lógica de In-App Purchases
                  }),
                  _buildButtonTile("Política de Privacidad", Icons.privacy_tip_outlined, () {
                    // TODO: Abrir URL con url_launcher
                  }),
                  _buildButtonTile("Términos de Servicio", Icons.description_outlined, () {
                    // TODO: Abrir URL con url_launcher
                  }),
                  
                  const SizedBox(height: 40),

                  // Versión de la app
                  Center(
                    child: Text(
                      "Versión $_appVersion",
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