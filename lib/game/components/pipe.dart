import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class Pipe extends PositionComponent with HasGameRef<FlameGame> {
  final double obstacleWidth = 70.0; 
  final double pipeBodyWidth = 60.0; 
  final double capHeight = 32.0; 
  final double spikeHeight = 22.0; // Altura reservada estrictamente para los picos
  
  final bool isLeftWall;
  final bool hasTopCap;    // Si es true, la boca del tubo está ARRIBA (tubo inferior)
  final bool hasBottomCap; // Si es true, la boca del tubo está ABAJO (tubo superior)

  Pipe({
    required double yPosition,
    required double height,
    required this.isLeftWall,
    this.hasTopCap = false,
    this.hasBottomCap = false,
  }) : super(position: Vector2(0, yPosition), size: Vector2(70.0, height));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 1. ANIMACIÓN DE ENTRADA SUAVE
    final double finalX = isLeftWall ? 0 : gameRef.size.x - obstacleWidth;
    final double startX = isLeftWall ? -obstacleWidth : gameRef.size.x;
    
    position.x = startX;

    add(MoveEffect.to(
      Vector2(finalX, position.y),
      EffectController(duration: 0.25, curve: Curves.easeOutCubic),
    ));

    // 2. HITBOX CENTRADA
    // Centramos la colisión (5px de margen a cada lado) para que coincida con el dibujo visual.
    final double bodyX = (obstacleWidth - pipeBodyWidth) / 2;
    add(RectangleHitbox(
      position: Vector2(bodyX, 0),
      size: Vector2(pipeBodyWidth, size.y),
    ));
  }

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
    
    // Gradiente premium estilo 3D
    final Gradient pipeGradient = const LinearGradient(
      colors: [
        Color(0xFF004D00), 
        Color(0xFF4CAF50), 
        Color(0xFFCCFF90), 
        Color(0xFF64DD17), 
        Color(0xFF1B5E20), 
      ],
      stops: [0.0, 0.2, 0.65, 0.85, 1.0],
    );

    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // CENTRAMOS EL CUERPO DE LA TUBERÍA
    // En lugar de alinearlo a la pared, lo centramos (dejando 5px de margen a los lados)
    final double bodyX = (obstacleWidth - pipeBodyWidth) / 2;
    
    // Calculamos cuánto espacio roban los picos y las tapas
    final double topReserved = hasTopCap ? (spikeHeight + capHeight) : 0.0;
    final double bottomReserved = hasBottomCap ? (spikeHeight + capHeight) : 0.0;
    
    // El cuerpo verde solo se dibuja en el espacio sobrante
    final Rect bodyRect = Rect.fromLTRB(bodyX, topReserved, bodyX + pipeBodyWidth, size.y - bottomReserved);

    // Dibujamos el cuerpo principal
    canvas.drawRect(bodyRect, Paint()..shader = pipeGradient.createShader(bodyRect));
    canvas.drawRect(bodyRect, borderPaint);

    // Highlight vertical del cuerpo alineado al nuevo centro
    final Rect shineRect = Rect.fromLTRB(bodyX + pipeBodyWidth * 0.60, topReserved, bodyX + pipeBodyWidth * 0.70, size.y - bottomReserved);
    canvas.drawRect(shineRect, Paint()..color = Colors.white.withOpacity(0.5));

    // Dibujamos las tapas y picos en la orientación correcta
    if (hasTopCap) {
      _drawCap(canvas, pipeGradient, borderPaint, isTopCap: true);
    }
    if (hasBottomCap) {
      _drawCap(canvas, pipeGradient, borderPaint, isTopCap: false);
    }
  }

  // Lógica inteligente para dibujar tapas y picos orientados
  void _drawCap(Canvas canvas, Gradient grad, Paint border, {required bool isTopCap}) {
    // Si es tapa superior (tubo de abajo), los picos ocupan los primeros 22px (de 0 a 22). La tapa va de 22 a 54.
    // Si es tapa inferior (tubo de arriba), la tapa va de (size.y - 54 a size.y - 22). Los picos de (size.y - 22 a size.y).
    final double capY = isTopCap ? spikeHeight : size.y - spikeHeight - capHeight;
    final Rect capRect = Rect.fromLTWH(0, capY, obstacleWidth, capHeight);
    final RRect cap = RRect.fromRectAndRadius(capRect, const Radius.circular(6));
    
    // Fondo de la tapa
    canvas.drawRRect(cap, Paint()..shader = grad.createShader(capRect));
    
    // Brillo de la tapa
    final Rect capShineRect = Rect.fromLTRB(obstacleWidth * 0.60, capY + 2, obstacleWidth * 0.70, capY + capHeight - 2);
    canvas.drawRect(capShineRect, Paint()..color = Colors.white.withOpacity(0.5));
    
    // Borde de la tapa
    canvas.drawRRect(cap, border);

    // La boca (de donde salen los picos)
    final double mouthY = isTopCap ? capY : capY + capHeight;
    
    // Sombra interna para dar profundidad a la boca del tubo
    final double shadowY = isTopCap ? mouthY : mouthY - 6.0;
    canvas.drawRect(
      Rect.fromLTWH(3, shadowY, obstacleWidth - 6, 6),
      Paint()..color = Colors.black.withOpacity(0.25)
    );

    // Dibujando los picos (Spikes)
    int spikeCount = 4;
    double spikeWidth = obstacleWidth / spikeCount;

    final Paint spikePaintL = Paint()..color = const Color(0xFFF5F5F5);
    final Paint spikePaintR = Paint()..color = const Color(0xFF757575);
    final Paint spikeBorder = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 2;

    for (int i = 0; i < spikeCount; i++) {
      // Dejamos margen para separar los picos
      double startX = i * spikeWidth + 2;
      double endX = (i + 1) * spikeWidth - 2;
      double midX = startX + (endX - startX) / 2;

      // Base del pico en la boca del tubo
      double basePosY = mouthY;
      // Punta del pico apuntando al centro de la pantalla
      double tipPosY = isTopCap ? 0.0 : size.y;

      Path leftSpike = Path()
        ..moveTo(startX, basePosY)
        ..lineTo(midX, tipPosY)
        ..lineTo(midX, basePosY)
        ..close();
      canvas.drawPath(leftSpike, spikePaintL);

      Path rightSpike = Path()
        ..moveTo(midX, basePosY)
        ..lineTo(midX, tipPosY)
        ..lineTo(endX, basePosY)
        ..close();
      canvas.drawPath(rightSpike, spikePaintR);

      Path outlineSpike = Path()
        ..moveTo(startX, basePosY)
        ..lineTo(midX, tipPosY)
        ..lineTo(endX, basePosY)
        ..close();
      canvas.drawPath(outlineSpike, spikeBorder);
    }
  }
}