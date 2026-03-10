import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../world/crazy_ball_game.dart';

class Coin extends CircleComponent with HasGameRef<CrazyBallGame> {
  final double coinRadius = 12.0;

  Coin({required Vector2 position}) : super(radius: 12.0, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Hitbox para que la bola la recoja
    add(CircleHitbox(radius: coinRadius, isSolid: true));

    // Animación de flotación "Idle" (sube y baja)
    add(MoveEffect.by(
      Vector2(0, -8),
      EffectController(duration: 0.6, alternate: true, infinite: true, curve: Curves.easeInOut),
    ));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final center = Offset(coinRadius, coinRadius);
    
    // Brillo exterior (Glow)
    canvas.drawCircle(center, coinRadius + 2, Paint()..color = const Color(0x66FFD700)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    
    // Moneda base amarilla
    canvas.drawCircle(center, coinRadius, Paint()..color = const Color(0xFFFFD700));
    
    // Borde interno naranja
    canvas.drawCircle(center, coinRadius - 2, Paint()..color = const Color(0xFFF57F17)..style = PaintingStyle.stroke..strokeWidth = 2);
    
    // Símbolo o reflejo blanco
    canvas.drawRect(Rect.fromCenter(center: center, width: 4, height: 10), Paint()..color = Colors.white70);
  }

  void collect() {
    // Animación rápida de recolección (se achica y desaparece)
    add(ScaleEffect.to(
      Vector2.zero(),
      EffectController(duration: 0.15),
      onComplete: () => removeFromParent(),
    ));
  }
}