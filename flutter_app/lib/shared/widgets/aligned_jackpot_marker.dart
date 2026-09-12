import 'package:flutter/material.dart';

class AlignedJackpotMarker extends StatelessWidget {
  const AlignedJackpotMarker({
    required this.parentText,
    required this.childText,
    required this.parentStyle,
    required this.arrowStyle,
    required this.childStyle,
    super.key,
  });

  final String parentText;
  final String childText;
  final TextStyle parentStyle;
  final TextStyle arrowStyle;
  final TextStyle childStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 140.0;
        final safeMaxWidth = maxWidth < 1 ? 1.0 : maxWidth;
        final boundaryWidth = _measureText(
          parentText.trimRight(),
          parentStyle,
          context,
        ).clamp(1.0, safeMaxWidth).toDouble();
        final childNumber = _childNumberOnly(childText);
        final endingWidth = _measureText('>', childStyle, context);
        final naturalGapWidth = _measureText(' ', childStyle, context);
        final gapWidth = boundaryWidth > endingWidth + naturalGapWidth * 2
            ? naturalGapWidth
            : 0.0;
        final maxChildNumberWidth =
            (boundaryWidth - endingWidth - gapWidth * 2)
                .clamp(0.0, boundaryWidth)
                .toDouble();
        final childNumberWidth = _measureText(
          childNumber,
          childStyle,
          context,
        ).clamp(0.0, maxChildNumberWidth).toDouble();
        final fixedChildWidth = childNumberWidth + gapWidth + endingWidth;
        final arrowWidth = (boundaryWidth - fixedChildWidth - gapWidth)
            .clamp(0.0, boundaryWidth)
            .toDouble();

        return SizedBox(
          width: boundaryWidth,
          child: Row(
            children: [
              SizedBox(
                width: arrowWidth,
                height: (arrowStyle.fontSize ?? 12) * 1.18,
                child: CustomPaint(
                  painter: _JackpotArrowPainter(
                    color: arrowStyle.color ?? const Color(0xFF111820),
                    strokeWidth: 1.3,
                  ),
                ),
              ),
              SizedBox(width: gapWidth),
              SizedBox(
                width: childNumberWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    childNumber,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: childStyle,
                  ),
                ),
              ),
              SizedBox(width: gapWidth),
              Text(
                '>',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: childStyle,
              ),
            ],
          ),
        );
      },
    );
  }
}

String _childNumberOnly(String value) {
  return value.trim().replaceFirst(RegExp(r'\s*>\s*$'), '').trim();
}

double _measureText(String value, TextStyle style, BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(text: value, style: style),
    maxLines: 1,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  )..layout();
  return painter.width;
}

class _JackpotArrowPainter extends CustomPainter {
  const _JackpotArrowPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    final centerY = size.height / 2;
    final headLength = size.width < 6 ? size.width : 6.0;
    final shaftEnd = size.width - headLength;
    final path = Path()
      ..moveTo(0, centerY)
      ..lineTo(shaftEnd, centerY)
      ..lineTo(size.width, centerY)
      ..moveTo(shaftEnd, centerY - headLength / 2)
      ..lineTo(size.width, centerY)
      ..lineTo(shaftEnd, centerY + headLength / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JackpotArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
