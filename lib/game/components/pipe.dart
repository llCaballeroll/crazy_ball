import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../world/crazy_ball_game.dart';

class Pipe extends PositionComponent with HasGameRef<CrazyBallGame> {
  final double obstacleWidth = 70.0; 
  final double pipeBodyWidth = 60.0; 
  final double capHeight = 28.0;     
  
  final bool isLeftWall;
  final bool hasTopCap;    // Si lleva reborde en la parte superior del segmento
  final bool hasBottomCap; // Si lleva reborde en la parte inferior del segmento

  Pipe({
    required double yPosition,
    required double height,
    required this.isLeftWall,
    this.hasTopCap = false,
    this.hasBottomCap = false,
  }) : super(position: Vector2(0, yPosition), size: Vector2(70.0, height)); // X temporal

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 1. ANIMACIÓN DE ENTRADA SUAVE
    final double finalX = isLeftWall ? 0 : gameRef.size.x - obstacleWidth;
    final double startX = isLeftWall ? -obstacleWidth : gameRef.size.x;
    
    position.x = startX; // Coloca la X real de inicio (oculto)

    add(MoveEffect.to(
      Vector2(finalX, position.y),
      EffectController(duration: 0.25, curve: Curves.easeOutCubic),
    ));

    // 2. HITBOX AJUSTADA AL CUERPO
    final double bodyX = isLeftWall ? 0.0 : obstacleWidth - pipeBodyWidth;
    add(RectangleHitbox(
      position: Vector2(bodyX, 0),
      size: Vector2(pipeBodyWidth, size.y),
    ));
  }

  // MÉTODO PARA OCULTARSE DESLIZÁNDOSE
  void slideOut() {
    final double targetX = isLeftWall ? -obstacleWidth : gameRef.size.x;
    add(MoveEffect.to(
      Vector2(targetX, position.y),
      EffectController(duration: 0.2, curve: Curves.easeIn),
      onComplete: () => removeFromParent(), 
    ));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final Gradient pipeGradient = LinearGradient(
      colors: const [Color(0xFF81C748), Color(0xFFC4F088), Color(0xFF5A9B25)],
      stops: const [0.0, 0.3, 1.0],
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF2C4A12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final double bodyX = isLeftWall ? 0 : obstacleWidth - pipeBodyWidth;
    final double capX = 0; 
    
    // Calculamos el tamaño del cuerpo descontando las tapas
    final double bodyStartY = hasTopCap ? capHeight : 0;
    final double bodyEndY = size.y - (hasBottomCap ? capHeight : 0);
    final Rect bodyRect = Rect.fromLTRB(bodyX, bodyStartY, bodyX + pipeBodyWidth, bodyEndY);

    // Dibujamos el cuerpo principal
    final bodyPaint = Paint()..shader = pipeGradient.createShader(bodyRect);
    canvas.drawRect(bodyRect, bodyPaint);
    canvas.drawRect(bodyRect, borderPaint);

    // Dibujamos la tapa superior si aplica
    if (hasTopCap) {
      final Rect topCapRect = Rect.fromLTWH(capX, 0, obstacleWidth, capHeight);
      final RRect roundedCap = RRect.fromRectAndRadius(topCapRect, const Radius.circular(4));
      canvas.drawRRect(roundedCap, Paint()..shader = pipeGradient.createShader(topCapRect));
      canvas.drawRRect(roundedCap, borderPaint);
    }

    // Dibujamos la tapa inferior si aplica
    if (hasBottomCap) {
      final Rect bottomCapRect = Rect.fromLTWH(capX, size.y - capHeight, obstacleWidth, capHeight);
      final RRect roundedCap = RRect.fromRectAndRadius(bottomCapRect, const Radius.circular(4));
      canvas.drawRRect(roundedCap, Paint()..shader = pipeGradient.createShader(bottomCapRect));
      canvas.drawRRect(roundedCap, borderPaint);
    }
  }
}