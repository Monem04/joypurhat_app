import 'package:flutter/material.dart';

import '../theme.dart';

/// A tappable surface that shrinks a little while pressed, with the usual
/// ripple. The shrink is skipped when the phone asks for less motion.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color = Colors.transparent,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color color;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down && !still ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: widget.color,
          borderRadius: widget.borderRadius,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Pops a child in (fade, rise and grow) after [delay]. Several of these
/// with growing delays give the staggered tile entrance on the home screen.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 420);
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.delay + _run);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _run).inMilliseconds,
      1,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)),
            child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
          ),
        );
      },
    );
  }
}

/// Announcement lines that scroll sideways in a loop. With reduced motion
/// the first two lines stand still, one under the other.
class NewsTicker extends StatefulWidget {
  const NewsTicker({super.key, required this.lines, this.speed = 38});

  /// Text and the colour of its dot.
  final List<(String, Color)> lines;

  /// Pixels per second.
  final double speed;

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker> with SingleTickerProviderStateMixin {
  static const _gap = 34.0;
  static const _style = TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSoft);
  late final AnimationController _c = AnimationController(vsync: this);
  double _width = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _measure(BuildContext context) {
    var w = 0.0;
    for (final (text, _) in widget.lines) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(_style)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      w += 15 + tp.width + _gap;
      tp.dispose();
    }
    return w;
  }

  Widget _strip() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (text, color) in widget.lines)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(text, style: _style, maxLines: 1, softWrap: false),
                ],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      _c.stop();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (text, color) in widget.lines.take(2))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                        width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: _style)),
                ],
              ),
            ),
        ],
      );
    }
    final w = _measure(context);
    if (w != _width && w > 0) {
      _width = w;
      _c.duration = Duration(milliseconds: (w / widget.speed * 1000).round());
      _c.repeat();
    }
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 2,
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.05, 0.95, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(offset: Offset(-_c.value * _width, 0), child: child),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Row(mainAxisSize: MainAxisSize.min, children: [_strip(), _strip()]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A status dot with a soft ring that pulses outwards (the current step of
/// an order). Without motion the ring stays still.
class GlowDot extends StatefulWidget {
  const GlowDot({super.key, required this.color, this.size = 28, this.child});
  final Color color;
  final double size;
  final Widget? child;

  @override
  State<GlowDot> createState() => _GlowDotState();
}

class _GlowDotState extends State<GlowDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: widget.child,
    );
    if (still) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.18), shape: BoxShape.circle),
        child: dot,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      child: dot,
      builder: (context, child) {
        final t = _c.value < 0.7 ? _c.value / 0.7 : 1.0;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                spreadRadius: 10 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
