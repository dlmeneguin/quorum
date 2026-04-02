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

    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    final tailPath = Path()
      ..moveTo(w * 0.23, h * 0.28)
      ..quadraticBezierTo(w * 0.10, h * 0.18, w * 0.17, h * 0.12);
    canvas.drawPath(tailPath, Paint()..color = Colors.black..strokeWidth = w * 0.025..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.80, h * 0.20), width: w * 0.08, height: h * 0.15), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.35), width: w * 0.50, height: h * 0.18), bodyPaint);
    canvas.drawCircle(Offset(w * 0.70, h * 0.28), w * 0.15, bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.32, h * 0.42), width: w * 0.12, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.48, h * 0.42), width: w * 0.12, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.20), width: w * 0.08, height: h * 0.15), blackPaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.18), w * 0.02, blackPaint);
    canvas.drawCircle(Offset(w * 0.83, h * 0.18), w * 0.02, blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.81, h * 0.30), width: w * 0.13, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.29), w * 0.018, blackPaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — sentado (Transações) - ALTURA DA CABEÇA E ORELHA CALIBRADAS
// ────────────────────────────────────────────────────────────
class AlbertoSittingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    // 1. ORELHA DIREITA (Atrás da cabeça - fresta)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.68, h * 0.22), width: w * 0.14, height: h * 0.20),
      blackPaint,
    );

    // 2. Rabo (Atrás do corpo)
    final tailPath = Path()
      ..moveTo(w * 0.62, h * 0.85)
      ..quadraticBezierTo(w * 0.88, h * 0.85, w * 0.82, h * 0.65);
    canvas.drawPath(tailPath, Paint()..color = Colors.black..strokeWidth = w * 0.035..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // 3. Corpo Alongado
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.65), width: w * 0.30, height: h * 0.65),
      bodyPaint,
    );

    // 4. CABEÇA - Desenhada APÓS a orelha direita para sobrepor (Z-Index)
    canvas.drawCircle(Offset(w * 0.50, h * 0.25), w * 0.25, bodyPaint);

    // 5. Patas
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.60), width: w * 0.14, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.60), width: w * 0.14, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.40, h * 0.94), width: w * 0.18, height: h * 0.10), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.94), width: w * 0.18, height: h * 0.10), blackPaint);

    // 6. Detalhes do Rosto e Orelha Esquerda (Frente)
    // CORREÇÃO: Movi o centro X da orelha de w * 0.35 para w * 0.28 (mais para a esquerda)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.28, h * 0.22), width: w * 0.14, height: h * 0.20), blackPaint);
    
    // Olhos acompanham a descida da cabeça
    canvas.drawCircle(Offset(w * 0.42, h * 0.21), w * 0.024, blackPaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.21), w * 0.024, blackPaint);
    
    // Focinho e Nariz
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.30), width: w * 0.16, height: h * 0.09), snoutPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.29), w * 0.022, blackPaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — de barriga para cima (Orçamento) - AJUSTE FINAL ORELHA
// ────────────────────────────────────────────────────────────
class AlbertoRelaxedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    // 1. CAUDA (Atrás do corpo)
    final tailPath = Path()
      ..moveTo(w * 0.15, h * 0.62)
      ..quadraticBezierTo(w * 0.02, h * 0.45, w * 0.10, h * 0.25);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = Colors.black
        ..strokeWidth = w * 0.035
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // 2. CORPO (Base horizontal)
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.60), width: w * 0.60, height: h * 0.28), bodyPaint);

    // 3. CABEÇA (Círculo conectado ao corpo)
    canvas.drawCircle(Offset(w * 0.75, h * 0.50), w * 0.18, bodyPaint);

    // 4. PATAS para cima
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.25, h * 0.46), width: w * 0.12, height: h * 0.08), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.46), width: w * 0.12, height: h * 0.08), blackPaint);

    // 5. DETALHES DO ROSTO (INVERTIDOS)
    // ORELHA: Maior (w*0.13, h*0.15) e mais para baixo (h*0.75)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.66, h * 0.75), width: w * 0.13, height: h * 0.15), 
      blackPaint
    );
    
    // Olhos na metade inferior
    canvas.drawCircle(Offset(w * 0.78, h * 0.58), w * 0.02, blackPaint); 
    canvas.drawCircle(Offset(w * 0.86, h * 0.58), w * 0.02, blackPaint); 

    // Focinho e Nariz
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.88, h * 0.52), width: w * 0.12, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.92, h * 0.51), w * 0.018, blackPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────
// ALBERTO — em pé (Metas)
// ────────────────────────────────────────────────────────────
class AlbertoStandingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final snoutPaint = Paint()..color = const Color(0xFFB07D62);

    final tailPath = Path()
      ..moveTo(w * 0.80, h * 0.69) 
      ..quadraticBezierTo(w * 0.95, h * 0.70, w * 0.88, h * 0.55);
    canvas.drawPath(tailPath, Paint()..color = Colors.black..strokeWidth = w * 0.04..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.50, h * 0.54), width: w * 0.32, height: h * 0.65), bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.46), width: w * 0.16, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.46), width: w * 0.16, height: h * 0.07), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.40, h * 0.78), width: w * 0.18, height: h * 0.10), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.79), width: w * 0.18, height: h * 0.10), blackPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.25), w * 0.20, bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.20), width: w * 0.13, height: h * 0.18), blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.18), width: w * 0.13, height: h * 0.18), blackPaint);
    canvas.drawCircle(Offset(w * 0.46, h * 0.20), w * 0.022, blackPaint);
    canvas.drawCircle(Offset(w * 0.54, h * 0.20), w * 0.022, blackPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.61, h * 0.27), width: w * 0.14, height: h * 0.08), snoutPaint);
    canvas.drawCircle(Offset(w * 0.63, h * 0.25), w * 0.020, blackPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      height: size * 1.3, // Proporção calibrada para garantir que o corpo longo e a cabeça caibam
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
  const AlbertoStandingWidget({super.key, this.size = 100});
  @override Widget build(BuildContext context) => SizedBox(width: size * 0.85, height: size, child: CustomPaint(painter: AlbertoStandingPainter()));
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