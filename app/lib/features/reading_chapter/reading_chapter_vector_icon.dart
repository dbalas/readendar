import 'package:flutter/material.dart';

/// Stroke chevrons. Lucide font glyphs can render as iOS tofu (□?).
class ReadingChapterChevron extends StatelessWidget {
  const ReadingChapterChevron({
    super.key,
    this.size = 18,
    this.color,
    this.direction = AxisDirection.right,
  });

  final double size;
  final Color? color;
  final AxisDirection direction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        key: const Key('readingChapterChevron'),
        size: Size.square(size),
        painter: _ChevronPainter(
          color: color ?? IconTheme.of(context).color ?? Colors.black,
          direction: direction,
          doubleHead: false,
        ),
      ),
    );
  }
}

class ReadingChapterChevronsUpDown extends StatelessWidget {
  const ReadingChapterChevronsUpDown({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        key: const Key('readingChapterChevronsUpDown'),
        size: Size.square(size),
        painter: _ChevronPainter(
          color: color ?? IconTheme.of(context).color ?? Colors.black,
          direction: AxisDirection.up,
          doubleHead: true,
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({
    required this.color,
    required this.direction,
    required this.doubleHead,
  });

  final Color color;
  final AxisDirection direction;
  final bool doubleHead;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (doubleHead) {
      _draw(canvas, size, stroke, AxisDirection.up, dy: -size.height * 0.12);
      _draw(canvas, size, stroke, AxisDirection.down, dy: size.height * 0.12);
      return;
    }
    _draw(canvas, size, stroke, direction);
  }

  void _draw(
    Canvas canvas,
    Size size,
    Paint stroke,
    AxisDirection dir, {
    double dy = 0,
  }) {
    canvas.save();
    canvas.translate(0, dy);
    final cx = size.width / 2;
    final cy = size.height / 2;
    const inset = 0.32;
    late Offset a;
    late Offset b;
    late Offset c;
    switch (dir) {
      case AxisDirection.right:
        a = Offset(size.width * inset, size.height * 0.28);
        b = Offset(size.width * (1 - inset), cy);
        c = Offset(size.width * inset, size.height * 0.72);
      case AxisDirection.left:
        a = Offset(size.width * (1 - inset), size.height * 0.28);
        b = Offset(size.width * inset, cy);
        c = Offset(size.width * (1 - inset), size.height * 0.72);
      case AxisDirection.up:
        a = Offset(size.width * 0.28, size.height * (1 - inset));
        b = Offset(cx, size.height * inset);
        c = Offset(size.width * 0.72, size.height * (1 - inset));
      case AxisDirection.down:
        a = Offset(size.width * 0.28, size.height * inset);
        b = Offset(cx, size.height * (1 - inset));
        c = Offset(size.width * 0.72, size.height * inset);
    }
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.direction != direction ||
      oldDelegate.doubleHead != doubleHead;
}
