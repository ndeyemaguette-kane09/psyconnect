import 'package:flutter/material.dart';

// ── Overlay de touche — à retirer avant la mise en production ────────────────
// Affiche un cercle animé à chaque endroit où l'utilisateur pose le doigt.
// Utile pour les démos et les captures vidéo.
//
// Utilisation dans app.dart :
//   child: kShowTouchIndicators
//       ? TouchIndicatorOverlay(child: MaterialApp(...))
//       : MaterialApp(...)

class TouchIndicatorOverlay extends StatefulWidget {
  const TouchIndicatorOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<TouchIndicatorOverlay> createState() => _TouchIndicatorOverlayState();
}

class _TouchIndicatorOverlayState extends State<TouchIndicatorOverlay> {
  // Map pointer id → position actuelle
  final Map<int, Offset> _pointers = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) =>
          setState(() => _pointers[e.pointer] = e.position),
      onPointerMove: (e) =>
          setState(() => _pointers[e.pointer] = e.position),
      onPointerUp: (e) =>
          setState(() => _pointers.remove(e.pointer)),
      onPointerCancel: (e) =>
          setState(() => _pointers.remove(e.pointer)),
      child: Stack(
        children: [
          widget.child,
          // On dessine un cercle par doigt actif
          ..._pointers.values.map(
            (pos) => Positioned(
              left: pos.dx - 22,
              top: pos.dy - 22,
              child: const _TouchCircle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchCircle extends StatefulWidget {
  const _TouchCircle();

  @override
  State<_TouchCircle> createState() => _TouchCircleState();
}

class _TouchCircleState extends State<_TouchCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.25),
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
