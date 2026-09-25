import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ícone do WhatsApp desenhado com [CustomPaint] a partir do caminho do
/// FontAwesome (viewBox 448x512), já que não há ícone Material correspondente
/// nem pacote de fontes de ícones por marca no projeto.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WhatsAppPainter(
        color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  _WhatsAppPainter(this.color);

  final Color color;

  static const double _iconWidth = 448;

  /// Altura real do glifo do FontAwesome (o viewBox tem 512, com folga).
  static const double _iconHeight = 512;

  static const String _data =
      'M380.9 97.1C339 55.1 283.2 32 223.9 32c-122.4 0-222 99.6-222 222 '
      '0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.4 17.7 68.9 27 106.1 '
      '27h.1c122.3 0 224.1-99.6 224.1-222 0-59.3-25.2-115-67.1-157zm-157 '
      '341.6c-33.2 0-65.7-8.9-94-25.7l-6.7-4-69.8 18.3L72 359.2l-4.4-7c-18.5-29.4-28.2-63.3-28.2-98.2 '
      '0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 '
      '56.2 81.2 56.1 130.5 0 101.8-84.9 184.6-186.6 184.6zm101.2-138.2c-5.5-2.8-32.8-16.2-37.9-18-5.1-1.9-8.8-2.8-12.5 2.8-3.7 5.6-14.3 18-17.6 '
      '21.8-3.2 3.7-6.5 4.2-12 1.4-32.6-16.3-54-29.1-75.5-66-5.7-9.8 5.7-9.1 '
      '16.3-30.3 1.8-3.7.9-6.9-.5-9.7-1.4-2.8-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3 0 27.3 19.9 53.7 22.6 57.4 2.8 3.7 39.1 59.7 94.8 83.8 35.2 15.2 49 16.5 66.6 13.9 10.7-1.6 32.8-13.4 37.4-26.4 4.6-13 4.6-24.1 3.2-26.4-1.3-2.5-5-3.9-10.5-6.6z';

  static final RegExp _token = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)');
  static final RegExp _isCommand = RegExp(r'[A-Za-z]');

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = _buildPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  Path _buildPath(Size size) {
    final scale = math.min(size.width / _iconWidth, size.height / _iconHeight);
    final offsetX = (size.width - _iconWidth * scale) / 2;
    final offsetY = (size.height - _iconHeight * scale) / 2;

    final path = Path();
    final tokens = _token.allMatches(_data).map((m) => m.group(0)!).toList();

    var i = 0;
    var cx = 0.0; // ponto atual
    var cy = 0.0;
    var startX = 0.0; // início da subpath (usado após Z)
    var startY = 0.0;
    var command = '';

    double x(double value) => offsetX + value * scale;
    double y(double value) => offsetY + value * scale;

    while (i < tokens.length) {
      if (_isCommand.hasMatch(tokens[i])) {
        command = tokens[i];
        i++;
      } else if (command.isEmpty) {
        i++;
        continue;
      }

      final upper = command.toUpperCase();
      final relative = command == command.toLowerCase();

      switch (upper) {
        case 'M':
        case 'L':
          var first = true;
          while (i + 1 < tokens.length && !_isCommand.hasMatch(tokens[i])) {
            var px = double.parse(tokens[i++]);
            var py = double.parse(tokens[i++]);
            if (relative) {
              px += cx;
              py += cy;
            }
            if (upper == 'M' && first) {
              path.moveTo(x(px), y(py));
              startX = px;
              startY = py;
            } else {
              path.lineTo(x(px), y(py));
            }
            cx = px;
            cy = py;
            first = false;
          }
          // Após um moveto, pares seguintes são lineto (regra do SVG).
          if (upper == 'M') command = relative ? 'l' : 'L';
        case 'H':
          while (i < tokens.length && !_isCommand.hasMatch(tokens[i])) {
            var px = double.parse(tokens[i++]);
            if (relative) px += cx;
            path.lineTo(x(px), y(cy));
            cx = px;
          }
        case 'V':
          while (i < tokens.length && !_isCommand.hasMatch(tokens[i])) {
            var py = double.parse(tokens[i++]);
            if (relative) py += cy;
            path.lineTo(x(cx), y(py));
            cy = py;
          }
        case 'C':
          while (i + 5 < tokens.length && !_isCommand.hasMatch(tokens[i])) {
            var x1 = double.parse(tokens[i++]);
            var y1 = double.parse(tokens[i++]);
            var x2 = double.parse(tokens[i++]);
            var y2 = double.parse(tokens[i++]);
            var px = double.parse(tokens[i++]);
            var py = double.parse(tokens[i++]);
            if (relative) {
              x1 += cx;
              y1 += cy;
              x2 += cx;
              y2 += cy;
              px += cx;
              py += cy;
            }
            path.cubicTo(
              x(x1),
              y(y1),
              x(x2),
              y(y2),
              x(px),
              y(py),
            );
            cx = px;
            cy = py;
          }
        case 'Z':
          path.close();
          cx = startX;
          cy = startY;
        default:
          i++;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color;
}
