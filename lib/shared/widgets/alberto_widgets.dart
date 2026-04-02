import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────
// ALBERTO — deitado em cima da casinha (Dashboard)
// ────────────────────────────────────────────────────────────
class AlbertoOnRoofPainter extends CustomPainter {
  final Color roofColor;
  AlbertoOnRoofPainter({this.roofColor = const Color(0xFF7A5C4A)});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // -- Telhado e Parede --
    final roofPaint = Paint()..color = roofColor;
    final roofPath = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.5, h * 0.25)
      ..lineTo(w, h * 0.55)
      ..close();
    canvas.drawPath(roofPath, roofPaint);

    final wallPaint = Paint()..color = const Color(0xFFF5E6C8);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.55, w * 0.8, h * 0.45), wallPaint);

    final doorPaint = Paint()..color = const Color(0xFF8B6347);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.38, h * 0.68, w * 0.24, h * 0.32),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      ),
      doorPaint,
    );

    // -- Alberto --
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    // 1. Rabo
    final tailPath = Path()
      ..moveTo(w * 0.23, h * 0.28)
      ..quadraticBezierTo(w * 0.10, h * 0.18, w * 0.17, h * 0.12);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = w * 0.025
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
    );

    // 2. Orelha Direita (Atrás da cabeça)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.80, h * 0.20), width: w * 0.08, height: h * 0.15), blackPaint);

    // 3. Corpo (Base branca)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.35), width: w * 0.50, height: h * 0.18), bodyPaint);

    // 4. Cabeça
    canvas.drawCircle(Offset(w * 0.70, h * 0.28), w * 0.15, bodyPaint);

    // 5. PATAS (Desenhadas DEPOIS do corpo)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.32, h * 0.42), width: w * 0.12, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.48, h * 0.42), width: w * 0.12, height: h * 0.07), blackPaint);

    // 6. Detalhes do Rosto e Orelha Esquerda (Frente)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.20), width: w * 0.08, height: h * 0.15), blackPaint);
    
    // Olhos
    canvas.drawCircle(Offset(w * 0.75, h * 0.18), w * 0.02, blackPaint);
    canvas.drawCircle(Offset(w * 0.83, h * 0.18), w * 0.02, blackPaint);

    // Focinho e Nariz
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.81, h * 0.30), width: w * 0.13, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.29), w * 0.018, blackPaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — sentado (Transações) - REFERÊNCIA DE TAMANHO
// ────────────────────────────────────────────────────────────
class AlbertoSittingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.68, h * 0.22), width: w * 0.14, height: h * 0.20), blackPaint);
    final tailPath = Path()
      ..moveTo(w * 0.62, h * 0.85)
      ..quadraticBezierTo(w * 0.88, h * 0.85, w * 0.82, h * 0.65);
    canvas.drawPath(tailPath, Paint()..color = Colors.black..strokeWidth = w * 0.035..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.50, h * 0.65), width: w * 0.30, height: h * 0.65), bodyPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.25), w * 0.25, bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.60), width: w * 0.14, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.60), width: w * 0.14, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.40, h * 0.94), width: w * 0.18, height: h * 0.10), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.94), width: w * 0.18, height: h * 0.10), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.28, h * 0.22), width: w * 0.14, height: h * 0.20), blackPaint);
    canvas.drawCircle(Offset(w * 0.42, h * 0.21), w * 0.024, blackPaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.21), w * 0.024, blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.30), width: w * 0.16, height: h * 0.09), snoutPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.29), w * 0.022, blackPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — de barriga para cima (Orçamento)
// ────────────────────────────────────────────────────────────
class AlbertoRelaxedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    final tailPath = Path()
      ..moveTo(w * 0.15, h * 0.62)
      ..quadraticBezierTo(w * 0.02, h * 0.45, w * 0.10, h * 0.25);
    canvas.drawPath(tailPath, Paint()..color = Colors.black..strokeWidth = w * 0.035..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.60), width: w * 0.60, height: h * 0.28), bodyPaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.50), w * 0.18, bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.25, h * 0.46), width: w * 0.12, height: h * 0.08), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.46), width: w * 0.12, height: h * 0.08), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.66, h * 0.75), width: w * 0.13, height: h * 0.15), blackPaint);
    canvas.drawCircle(Offset(w * 0.78, h * 0.58), w * 0.02, blackPaint); 
    canvas.drawCircle(Offset(w * 0.86, h * 0.58), w * 0.02, blackPaint); 
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.88, h * 0.52), width: w * 0.12, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.92, h * 0.51), w * 0.018, blackPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — Metas (Oi/Acenando - ORELHA DIREITA ALARGADA)
// ────────────────────────────────────────────────────────────
class AlbertoStandingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    // 1. RABO (Lateral Esquerda - Atrás do corpo)
    final tailPath = Path()
      ..moveTo(w * 0.35, h * 0.85)
      ..quadraticBezierTo(w * 0.18, h * 0.85, w * 0.22, h * 0.65);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = w * 0.04
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // 2. ORELHA DIREITA (Atrás/Fresta)
    // CALIBRAÇÃO: Largura aumentada de 0.05 para 0.12 (Alargada)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.74, h * 0.16), width: w * 0.12, height: h * 0.18), 
      blackPaint
    );

    // 3. CORPO (Alongado)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.50, h * 0.65), width: w * 0.32, height: h * 0.72), bodyPaint);

    // 4. CABEÇA
    canvas.drawCircle(Offset(w * 0.50, h * 0.20), w * 0.26, bodyPaint);

    // 5. Pés (Patas Traseiras)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.96), width: w * 0.18, height: h * 0.08), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.96), width: w * 0.18, height: h * 0.08), blackPaint);

    // 6. PATA ESQUERDA (APOIADA)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.60), width: w * 0.14, height: h * 0.07), blackPaint);

    // 6.b PATA DIREITA E TRAÇOS (ZONA DE ROTAÇÃO)
    final rotationCenter = Offset(w * 0.62, h * 0.57); 
    canvas.save(); 
    canvas.translate(rotationCenter.dx, rotationCenter.dy);
    canvas.rotate(-0.4);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.10, -h * 0.02), width: w * 0.17, height: h * 0.06), blackPaint);

    // 7. TRAÇOS DE MOVIMENTO
    final motionPaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..strokeWidth = w * 0.010
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
    final motionPath = Path();
    motionPath.moveTo(w * 0.08, -h * 0.12); motionPath.quadraticBezierTo(w * 0.12, -h * 0.14, w * 0.16, -h * 0.12);
    motionPath.moveTo(w * 0.08, -h * 0.09); motionPath.quadraticBezierTo(w * 0.12, -h * 0.11, w * 0.16, -h * 0.09);
    motionPath.moveTo(w * 0.08, h * 0.05); motionPath.quadraticBezierTo(w * 0.12, h * 0.07, w * 0.16, h * 0.05);
    motionPath.moveTo(w * 0.08, h * 0.08); motionPath.quadraticBezierTo(w * 0.12, h * 0.10, w * 0.16, h * 0.08);
    canvas.drawPath(motionPath, motionPaint);
    canvas.restore(); 

    // 8. DETALHES DO ROSTO
    // Orelha Esquerda (Frente)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.28, h * 0.16), width: w * 0.14, height: h * 0.20), blackPaint);
    
    // Olhos
    canvas.drawCircle(Offset(w * 0.44, h * 0.18), w * 0.024, blackPaint);
    canvas.drawCircle(Offset(w * 0.56, h * 0.18), w * 0.024, blackPaint);
    
    // Focinho e Nariz
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.26), width: w * 0.16, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.25), w * 0.022, blackPaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — Sidebar (Corpo mais curto e levemente mais largo)
// ────────────────────────────────────────────────────────────
class AlbertoSidebarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- DESLOCAMENTO GLOBAL (Escorado na Sidebar) ---
    canvas.translate(w * 0.1351, 0); 

    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    // 1. PATAS TRASEIRAS (Fixas na base)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.66, h * 0.88), width: w * 0.05, height: h * 0.03), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.70, h * 0.89), width: w * 0.05, height: h * 0.03), blackPaint);

    // 2. CORPO (Pivô de inclinação)
    final pivotX = w * 0.70; 
    final pivotY = h * 0.95;

    canvas.save(); // [SAVE 1] - Início da inclinação do corpo
    canvas.translate(pivotX, pivotY);
    canvas.rotate(0.35); 
    canvas.translate(-pivotX, -pivotY);

    // Desenho do Tronco (Afinado)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.68, h * 0.62), width: w * 0.09, height: h * 0.55),
      bodyPaint,
    );

    // 3. PATAS DIANTEIRAS (Mais grossas e conectadas)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.72, h * 0.35), width: w * 0.07, height: h * 0.05), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.75, h * 0.48), width: w * 0.07, height: h * 0.05), blackPaint);

    // 4. CABEÇA (Dentro do contexto de rotação do corpo)
    final headCenter = Offset(w * 0.64, h * 0.28); 
    
    canvas.save(); // [SAVE 2] - Rotação específica da cabeça
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(-1.047); 
    
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.08, -h * 0.04), width: w * 0.03, height: h * 0.14), blackPaint);
    canvas.drawCircle(Offset.zero, w * 0.09, bodyPaint); // Cabeça maior
    canvas.drawOval(Rect.fromCenter(center: Offset(-w * 0.08, -h * 0.02), width: w * 0.05, height: h * 0.15), blackPaint);
    canvas.drawCircle(Offset(-w * 0.035, 0), w * 0.014, blackPaint); 
    canvas.drawCircle(Offset(w * 0.025, -h * 0.025), w * 0.014, blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.05, h * 0.045), width: w * 0.06, height: h * 0.04), snoutPaint);
    canvas.drawCircle(Offset(w * 0.07, h * 0.035), w * 0.012, blackPaint);

    canvas.restore(); // [RESTORE 2] - Fecha cabeça
    canvas.restore(); // [RESTORE 1] - Fecha corpo

    // 5. RABO (AJUSTADO: Conectado ao corpo em 0.68 e isolado para rotação própria)
    final tOX = w * 0.68; // Movido de 0.63 -> 0.68 para a direita
    final tOY = h * 0.75;

    canvas.save(); 
    canvas.translate(tOX, tOY);
    canvas.rotate(-0.174); // Mantendo os 10 graus anti-horário
    canvas.translate(-tOX, -tOY);

    final tailPath = Path()
      ..moveTo(tOX, tOY) 
      ..quadraticBezierTo(
        w * 0.56, h * 0.78, // Ajustado proporcionalmente à nova origem
        w * 0.61, h * 0.68  // Pontinha do rabo
      );
    
    canvas.drawPath(
      tailPath, 
      Paint()
        ..color = Colors.black
        ..strokeWidth = w * 0.015
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// WIDGETS
// ────────────────────────────────────────────────────────────

class AlbertoOnRoofWidget extends StatelessWidget {
  final double width; final double height; final Color roofColor;
  const AlbertoOnRoofWidget({super.key, this.width = 160, this.height = 120, this.roofColor = const Color(0xFF7A5C4A)});
  @override Widget build(BuildContext context) => SizedBox(width: width, height: height, child: CustomPaint(painter: AlbertoOnRoofPainter(roofColor: roofColor)));
}

class AlbertoSittingWidget extends StatelessWidget {
  final double size;
  const AlbertoSittingWidget({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, 
      height: size * 1.3, // Proporção calibrada
      child: CustomPaint(
        painter: AlbertoSittingPainter(),
      ),
    );
  }
}

class AlbertoRelaxedWidget extends StatelessWidget {
  final double size;
  const AlbertoRelaxedWidget({super.key, this.size = 100});
  @override Widget build(BuildContext context) => SizedBox(width: size, height: size * 0.55, child: CustomPaint(painter: AlbertoRelaxedPainter()));
}

class AlbertoStandingWidget extends StatelessWidget {
  final double size;
  const AlbertoStandingWidget({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, 
      height: size * 1.3, // Proporção calibrada para o Alberto robusto/alongado
      child: CustomPaint(
        painter: AlbertoStandingPainter(),
      ),
    );
  }
}

class AlbertoSidebarWidget extends StatelessWidget {
  final double sidebarWidth;
  const AlbertoSidebarWidget({super.key, this.sidebarWidth = 220});
  @override Widget build(BuildContext context) => SizedBox(width: sidebarWidth, height: sidebarWidth * 0.50, child: CustomPaint(painter: AlbertoSidebarPainter()));
}

// ────────────────────────────────────────────────────────────
// BALÃO DE PENSAMENTO
// ────────────────────────────────────────────────────────────

class ThoughtBubbleWidget extends StatelessWidget {
  final String text;
  final Color bubbleColor;
  final Color textColor;

  const ThoughtBubbleWidget({
    super.key,
    required this.text,
    this.bubbleColor = Colors.white,
    this.textColor = const Color(0xFF3D1A24),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: textColor.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: textColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(bubbleColor, textColor, 8),
              const SizedBox(width: 3),
              _dot(bubbleColor, textColor, 5),
              const SizedBox(width: 3),
              _dot(bubbleColor, textColor, 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(Color bg, Color border, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border.withOpacity(0.15)),
        ),
      );
}