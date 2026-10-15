import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// True when the phone asks for fewer animations (Accessibility settings).
bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ---------------------------------------------------------------------------
// Reading-room pattern: rows of desks seen from above. Used behind green headers.
// ---------------------------------------------------------------------------

class SeatPatternPainter extends CustomPainter {
  final Color color;
  final double cell;

  const SeatPatternPainter({this.color = const Color(0x14FFFFFF), this.cell = 18});

  @override
  void paint(Canvas canvas, Size size) {
    final desk = Paint()..color = color;
    final w = cell * 1.25, h = cell * 0.8, gapX = cell * 0.55, gapY = cell * 0.9;
    var row = 0;
    for (double y = cell * 0.6; y < size.height; y += h + gapY, row++) {
      // every 3rd column is an aisle, rows are offset like a real reading hall
      final offset = row.isOdd ? (w + gapX) / 2 : 0.0;
      var col = 0;
      for (double x = -w + offset; x < size.width; x += w + gapX, col++) {
        if (col % 4 == 3) continue;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(h * 0.3)), desk);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SeatPatternPainter old) => old.color != color || old.cell != cell;
}

/// Deep-green panel with the desk pattern behind its child.
class RoomPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;

  const RoomPanel({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.green, AppColors.greenDark],
          ),
        ),
        child: CustomPaint(
          painter: const SeatPatternPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The signature moment: seats of the current shift light up one by one.
// ---------------------------------------------------------------------------

class SeatFillGrid extends StatefulWidget {
  final int total;
  final int occupied;

  const SeatFillGrid({super.key, required this.total, required this.occupied});

  @override
  State<SeatFillGrid> createState() => _SeatFillGridState();
}

class _SeatFillGridState extends State<SeatFillGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(SeatFillGrid old) {
    super.didUpdateWidget(old);
    if (old.occupied != widget.occupied && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show at most 60 seats; bigger libraries are drawn to scale.
    final cells = math.max(1, math.min(widget.total, 60));
    final lit = widget.total <= 0 ? 0 : (widget.occupied / widget.total * cells).round().clamp(0, cells);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(_c.value) * lit;
        return Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 0; i < cells; i++)
              _Seat(fill: (progress - i).clamp(0.0, 1.0)),
          ],
        );
      },
    );
  }
}

class _Seat extends StatelessWidget {
  final double fill;

  const _Seat({required this.fill});

  @override
  Widget build(BuildContext context) {
    final on = Color.lerp(const Color(0x33FFFFFF), AppColors.lamp, fill)!;
    return Container(
      width: 16,
      height: 11,
      decoration: BoxDecoration(
        color: on,
        borderRadius: BorderRadius.circular(3),
        boxShadow: fill > 0.9
            ? [BoxShadow(color: AppColors.lamp.withAlpha(90), blurRadius: 6)]
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable motion pieces
// ---------------------------------------------------------------------------

/// Money that counts up to its value.
class CountUpMoney extends StatelessWidget {
  final num value;
  final TextStyle style;

  const CountUpMoney(this.value, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(money(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(money(v.round()), style: style),
    );
  }
}

/// Shrinks slightly while pressed, so taps feel physical.
class PressScale extends StatefulWidget {
  final Widget child;

  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Green circle with a tick that pops in — shown when money is received.
class SuccessTick extends StatelessWidget {
  final double size;

  const SuccessTick({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6),
    );
    if (reduceMotion(context)) return circle;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: circle,
    );
  }
}

/// Grey blocks that gently pulse while a screen loads.
class SkeletonView extends StatefulWidget {
  const SkeletonView({super.key});

  @override
  State<SkeletonView> createState() => _SkeletonViewState();
}

class _SkeletonViewState extends State<SkeletonView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double h, {double? w, double r = 14}) => Container(
        height: h,
        width: w,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(opacity: 0.45 + 0.55 * (1 - _c.value), child: child),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _box(150, r: 22),
          Row(children: [Expanded(child: _box(96)), const SizedBox(width: 12), Expanded(child: _box(96))]),
          _box(18, w: 140, r: 6),
          _box(64),
          _box(64),
          _box(64),
        ],
      ),
    );
  }
}

/// Slide-and-fade used for every screen change.
class SoftPageTransitions extends PageTransitionsBuilder {
  const SoftPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}
