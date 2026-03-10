import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  int _currentScore = 0;
  late ScrollController _scrollController;
  late List<Milestone> _milestones;

  // Alturas fijas para cálculo matemático de scroll
  final double _islandTotalHeight = 260.0; 
  final double _rewardTotalHeight = 120.0; 

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _milestones = [];
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Generamos y luego invertimos para que el nivel más alto esté arriba
    _milestones = _generateMilestones().reversed.toList();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    setState(() {
      // Usamos la misma clave que en home.dart
      _currentScore = prefs.getInt('highScore') ?? 0;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentScore();
    });
  }

  void _scrollToCurrentScore() {
    if (!_scrollController.hasClients || _milestones.isEmpty) return;

    int targetIndex = _milestones.indexWhere((m) => _currentScore >= m.score);
    if (targetIndex == -1) targetIndex = _milestones.length - 1;

    double offsetSum = 0;
    for (int i = 0; i < targetIndex; i++) {
      if (_milestones[i].type == MilestoneType.arena) {
        offsetSum += _islandTotalHeight;
      } else {
        offsetSum += _rewardTotalHeight;
      }
    }

    double currentItemHalfHeight = (_milestones[targetIndex].type == MilestoneType.arena) 
        ? _islandTotalHeight / 2 
        : _rewardTotalHeight / 2;

    double finalScrollPosition = offsetSum + currentItemHalfHeight;
    _scrollController.jumpTo(finalScrollPosition - (_milestones[targetIndex].type == MilestoneType.arena ? 110 : 40)); 
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double verticalPadding = screenHeight / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF4EC0E9), // Fondo clásico de Crazy Ball
      body: Stack(
        children: [
          // --- LISTA DE NIVELES ---
          ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            itemCount: _milestones.length,
            itemBuilder: (context, index) {
              final milestone = _milestones[index];
              final bool isUnlocked = _currentScore >= milestone.score;
              
              bool isPathFilled = isUnlocked;
              if (index > 0) {
                 isPathFilled = _currentScore >= _milestones[index-1].score;
              } else {
                 isPathFilled = isUnlocked;
              }

              return _TimelineItem(
                milestone: milestone,
                isUnlocked: isUnlocked,
                isPathFilled: isUnlocked, 
                index: index, 
              );
            },
          ),

          // --- HEADER FLOTANTE ---
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _GlassHeader(
                  score: _currentScore,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ESTRUCTURA DE PROGRESIÓN DE CRAZY BALL ---
  List<Milestone> _generateMilestones() {
    return [
      // INICIO
      Milestone(0, 'arena_cielo.png', type: MilestoneType.arena, label: "CIELO CLARO"),
      Milestone(20, 'skin_basket.png', type: MilestoneType.reward, label: "Bola de Baloncesto"),
      Milestone(40, 'skin_8ball.png', type: MilestoneType.reward, label: "Bola 8 Mágica"),
      
      // ARENA 2
      Milestone(60, 'arena_noche.png', type: MilestoneType.arena, label: "NOCHE ESTELAR"),
      Milestone(90, 'skin_eye.png', type: MilestoneType.reward, label: "Ojo de Monstruo"),
      Milestone(120, 'skin_ninja.png', type: MilestoneType.reward, label: "Bola Ninja"),
      
      // ARENA 3
      Milestone(150, 'arena_neon.png', type: MilestoneType.arena, label: "MUNDO NEÓN"),
      Milestone(200, 'skin_robot.png', type: MilestoneType.reward, label: "Cyborg Ball"),
      Milestone(250, 'skin_fire.png', type: MilestoneType.reward, label: "Núcleo de Fuego"),
      
      // ARENA 4
      Milestone(300, 'arena_volcan.png', type: MilestoneType.arena, label: "CUEVA DE LAVA"),
      Milestone(400, 'skin_dragon.png', type: MilestoneType.reward, label: "Huevo de Dragón"),
      
      // ARENA 5
      Milestone(500, 'arena_espacio.png', type: MilestoneType.arena, label: "GALAXIA CERO"),
      Milestone(750, 'skin_gold.png', type: MilestoneType.reward, label: "Bola de Oro Puro"),
      
      // ARENA INFINITA
      Milestone(1000, 'arena_hacker.png', type: MilestoneType.arena, label: "EL GLITCH"),
      Milestone(9999, 'skin_diamond.png', type: MilestoneType.reward, label: "Diamante Supremo"),
    ];
  }
}

// --- CLASES Y WIDGETS ---
enum MilestoneType { arena, reward }

class Milestone {
  final int score;
  final String assetName;
  final MilestoneType type;
  final String label;

  Milestone(this.score, this.assetName, {this.type = MilestoneType.reward, this.label = ''});

  String getFullPath() {
    // Aquí puedes ajustar las rutas reales de tus carpetas cuando tengas las imágenes
    if (type == MilestoneType.arena) return 'assets/images/arenas/$assetName';
    return 'assets/images/skins/$assetName';
  }
}

class _TimelineItem extends StatelessWidget {
  final Milestone milestone;
  final bool isUnlocked;
  final bool isPathFilled;
  final int index; 

  const _TimelineItem({
    required this.milestone,
    required this.isUnlocked,
    required this.isPathFilled,
    required this.index, 
  });

  @override
  Widget build(BuildContext context) {
    final double itemHeight = milestone.type == MilestoneType.arena ? 260.0 : 120.0;

    return SizedBox(
      height: itemHeight,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BARRA LATERAL (LÍNEA DE TIEMPO)
            SizedBox(
              width: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 8,
                    color: isPathFilled ? const Color(0xFFFFD700) : Colors.black26, // Amarillo para el camino activo
                  ),
                  Container(
                    width: 45,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isUnlocked ? const Color(0xFFFFD700) : Colors.grey[400],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black87, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 2))]
                    ),
                    child: Center(
                      child: Text(
                        "${milestone.score}",
                        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENIDO
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
                child: milestone.type == MilestoneType.arena
                    ? _ArenaCard(milestone: milestone, isUnlocked: isUnlocked)
                    : _RewardCard(milestone: milestone, isUnlocked: isUnlocked, index: index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaCard extends StatelessWidget {
  final Milestone milestone;
  final bool isUnlocked;
  const _ArenaCard({required this.milestone, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    const ColorFilter greyscaleFilter = ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity, height: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fondo de la tarjeta simulando la arena
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white : Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black87, width: 4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColorFiltered(
                    colorFilter: isUnlocked ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) : greyscaleFilter,
                    child: Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight - 40,
                      color: Colors.blueAccent.withOpacity(0.3), // Placeholder mientras pones tus imágenes
                      child: const Center(child: Icon(Icons.image, size: 50, color: Colors.white54)),
                      // Image.asset(milestone.getFullPath(), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                child: Text(
                  milestone.label,
                  style: const TextStyle(
                    fontFamily: 'Impact', color: Colors.white, fontSize: 24, letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 2))]
                  ),
                ),
              ),
              if (!isUnlocked)
                const Positioned(top: 15, right: 15, child: Icon(Icons.lock_rounded, size: 40, color: Colors.black54)),
            ],
          ),
        );
      }
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Milestone milestone;
  final bool isUnlocked;
  final int index; 

  const _RewardCard({required this.milestone, required this.isUnlocked, required this.index});

  @override
  Widget build(BuildContext context) {
    final bool isImageLeft = index % 2 == 0;

    Widget imageWidget = Container(
      width: 70, 
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.orangeAccent.withOpacity(0.2) : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.horizontal(left: isImageLeft ? const Radius.circular(15) : Radius.zero, right: !isImageLeft ? const Radius.circular(15) : Radius.zero),
      ),
      child: Center(
        child: Opacity(
          opacity: isUnlocked ? 1.0 : 0.4,
          child: const Icon(Icons.sports_basketball_rounded, size: 40, color: Colors.white70), // Placeholder
          // Image.asset(milestone.getFullPath(), fit: BoxFit.contain),
        ),
      ),
    );

    Widget textWidget = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isImageLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              isUnlocked ? "¡DESBLOQUEADO!" : "BLOQUEADO",
              style: TextStyle(fontFamily: 'Impact', color: isUnlocked ? const Color(0xFF9BE15D) : Colors.white54, fontSize: 16, letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              milestone.label,
              style: const TextStyle(fontFamily: 'Impact', color: Colors.white, fontSize: 18),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: isImageLeft ? [imageWidget, textWidget] : [textWidget, imageWidget],
      ),
    );
  }
}

class _GlassHeader extends StatelessWidget {
  final int score;
  final VoidCallback onBack;

  const _GlassHeader({required this.score, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black87, width: 2)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 28),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("CAMINO DE TROFEOS", style: TextStyle(fontFamily: 'Impact', fontSize: 14, color: Colors.white70, letterSpacing: 1.5)),
                    Text("RÉCORD: $score", style: const TextStyle(fontFamily: 'Impact', fontSize: 24, color: Color(0xFFFFD700), letterSpacing: 1.2, shadows: [Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(1, 1))])),
                  ],
                ),
              ),
              const SizedBox(width: 45), // Para equilibrar el botón de retroceso
            ],
          ),
        ),
      ),
    );
  }
}