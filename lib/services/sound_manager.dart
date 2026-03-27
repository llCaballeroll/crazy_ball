import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Gestor centralizado de audio para Crazy Ball.
///
/// Diseño:
/// - BGM: un único AudioPlayer gestionado directamente (sin Bgm wrapper)
///   para evitar el `release()` overhead que causa gaps al cambiar música.
/// - SFX: AudioPool por cada efecto (reutiliza instancias pre-creadas),
///   eliminando la latencia de crear un nuevo AudioPlayer en cada sonido.
/// - Inicialización única en main() antes de runApp() para que el engine
///   de Android ya tenga todo preparado cuando empiece el juego.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  static const double _musicVolume = 0.5;

  // ── ESTADOS DE CONFIGURACIÓN ─────────────────────────────────────────────
  bool isMusicOn = true;
  bool isSoundOn = true;
  bool isVibrationOn = true;

  // ── BGM ─────────────────────────────────────────────────────────────────
  late AudioPlayer _bgmPlayer;
  String? _currentMusic;
  bool _bgmChanging = false;
  String? _pendingMusic;

  // ── SFX pools ────────────────────────────────────────────────────────────
  AudioPool? _bouncePool;    // boteEnPared — muy frecuente
  AudioPool? _coinPool;      // moneda
  AudioPool? _choquePool;    // choque
  AudioPool? _destrucPool;   // destruccion
  AudioPool? _poderPool;     // poder
  AudioPool? _morirPool;     // morir

  // ── Inicialización ───────────────────────────────────────────────────────

  Future<void> init() async {
    // 0. Cargar configuraciones guardadas
    final prefs = await SharedPreferences.getInstance();
    isMusicOn = prefs.getBool('musicOn') ?? true;
    isSoundOn = prefs.getBool('soundOn') ?? true;
    isVibrationOn = prefs.getBool('vibrationOn') ?? true;

    // 1. Preparar el BGM player
    _bgmPlayer = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);

    // 2. Precargar todos los archivos de audio en el AudioCache.
    await FlameAudio.audioCache.loadAll([
      'musics/home.mp3',
      'musics/aventura.mp3',
      'musics/vs.mp3',
      'musics/shop.mp3',
      'sounds/boteEnPared.mp3',
      'sounds/moneda.mp3',
      'sounds/choque.mp3',
      'sounds/destruccion.mp3',
      'sounds/poder.mp3',
      'sounds/morir.mp3',
    ]);

    // 3. Crear pools SFX en paralelo.
    await Future.wait([
      FlameAudio.createPool(
        'sounds/boteEnPared.mp3',
        minPlayers: 4, maxPlayers: 4, // hasta 4 rebotes simultáneos
      ).then((p) => _bouncePool = p),
      FlameAudio.createPool(
        'sounds/moneda.mp3',
        minPlayers: 3, maxPlayers: 3,
      ).then((p) => _coinPool = p),
      FlameAudio.createPool(
        'sounds/choque.mp3',
        minPlayers: 2, maxPlayers: 2,
      ).then((p) => _choquePool = p),
      FlameAudio.createPool(
        'sounds/destruccion.mp3',
        minPlayers: 2, maxPlayers: 2,
      ).then((p) => _destrucPool = p),
      FlameAudio.createPool(
        'sounds/poder.mp3',
        minPlayers: 2, maxPlayers: 2,
      ).then((p) => _poderPool = p),
      FlameAudio.createPool(
        'sounds/morir.mp3',
        minPlayers: 2, maxPlayers: 2,
      ).then((p) => _morirPool = p),
    ]);
  }

  // ── ACTUALIZACIÓN EN TIEMPO REAL DESDE SETTINGS ──────────────────────────

  void toggleMusic(bool isOn) async {
    isMusicOn = isOn;
    if (isOn) {
      // Si se enciende y hay una canción registrada, la reanuda
      if (_currentMusic != null) {
        try {
          await _bgmPlayer.play(
            AssetSource('musics/$_currentMusic.mp3'),
            volume: _musicVolume,
          );
        } catch (_) {}
      }
    } else {
      // Si se apaga, detiene la música al instante, pero recuerda cuál era
      try { await _bgmPlayer.stop(); } catch (_) {}
    }
  }

  void toggleSound(bool isOn) {
    isSoundOn = isOn;
  }

  void toggleVibration(bool isOn) {
    isVibrationOn = isOn;
  }

  // ── BGM ──────────────────────────────────────────────────────────────────

  /// Cambia la música de fondo de forma segura.
  Future<void> playMusic(String name) async {
    if (_currentMusic == name) return;
    if (_bgmChanging) {
      _pendingMusic = name;
      return;
    }
    await _doPlayMusic(name);
  }

  Future<void> _doPlayMusic(String name) async {
    _bgmChanging = true;
    _currentMusic = name;
    _pendingMusic = null;

    try {
      await _bgmPlayer.stop();
      // Solo reproduce si la configuración de música está encendida
      if (isMusicOn) {
        await _bgmPlayer.play(
          AssetSource('musics/$name.mp3'),
          volume: _musicVolume,
        );
      }
    } catch (_) {
    } finally {
      _bgmChanging = false;
    }

    if (_pendingMusic != null && _pendingMusic != _currentMusic) {
      final next = _pendingMusic!;
      _pendingMusic = null;
      await _doPlayMusic(next);
    }
  }

  Future<void> stopMusic() async {
    _currentMusic = null;
    _pendingMusic = null;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  // ── SFX ──────────────────────────────────────────────────────────────────

  void _sfx(AudioPool? pool, double volume) {
    // Si los efectos están apagados, salimos sin reproducir
    if (!isSoundOn) return;
    pool?.start(volume: volume).catchError((_) {});
  }

  void sfxBote()        => _sfx(_bouncePool,  0.85);
  void sfxChoque()      => _sfx(_choquePool,  1.00);
  void sfxDestruccion() => _sfx(_destrucPool, 1.00);
  void sfxMoneda()      => _sfx(_coinPool,    0.80);
  void sfxMorir()       => _sfx(_morirPool,   1.00);
  void sfxPoder()       => _sfx(_poderPool,   1.00);


// ── VIBRACIÓN ────────────────────────────────────────────────────────────
  
  /// Llama a esta función cuando el jugador pierda o haya un impacto fuerte.
  void vibrate() async {
    if (!isVibrationOn) return;
    
    try {
      // Intentamos vibrar directamente con el método más básico y seguro
      Vibration.vibrate(duration: 400); 
    } catch (e) {
      // Si el paquete falla, no hace nada y no crashea el juego
      print("Error al vibrar: $e");
    }
  }

  // ── Limpieza ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    try { await _bgmPlayer.dispose(); } catch (_) {}
  }
}