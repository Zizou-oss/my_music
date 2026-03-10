import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  2Block Design Tokens
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF000000);
  static const v400 = Color(0xFFa78bfa);
  static const v500 = Color(0xFF8b5cf6);
  static const v600 = Color(0xFF7c3aed);
  static const p400 = Color(0xFFc084fc);
  static const p500 = Color(0xFFa855f7);
  static const p600 = Color(0xFF9333ea);
  static const white = Color(0xFFFFFFFF);
  static const gray500 = Color(0xFF737373);

  static const gradMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v400, p400, p500],
  );
  static const gradBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v600, p600],
  );
}

// ─────────────────────────────────────────────
//  SplashScreen
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Orb pulse
  late final AnimationController _orbCtrl;
  late final Animation<double> _orbScale;
  late final Animation<double> _orbGlow;

  // Logo entrance
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Text entrance
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  // Progress bar
  late final AnimationController _progressCtrl;

  // Outer ring rotation
  late final AnimationController _ring1Ctrl;
  late final AnimationController _ring2Ctrl;

  // Particle twinkle
  late final AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();

    // ── Orb pulse ──────────────────────────
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _orbScale = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));
    _orbGlow = Tween<double>(begin: 0.3, end: 0.65)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

    // ── Logo entrance ──────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));

    // ── Text entrance ──────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // ── Progress bar ───────────────────────
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));

    // ── Rings ──────────────────────────────
    _ring1Ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _ring2Ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();

    // ── Particles ──────────────────────────
    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    // ── Sequence ───────────────────────────
    _runSequence();
  }

  Future<void> _runSequence() async {
    // Stagger: logo → text → progress
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _progressCtrl.forward();

    // Navigate after progress completes
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _progressCtrl.dispose();
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _blob(Offset(-100, -80), 360, _C.v600.withOpacity(0.28)),
          _blob(Offset(size.width - 120, size.height * 0.4), 300,
              _C.p500.withOpacity(0.18)),
          _blob(Offset(-80, size.height - 200), 260, _C.v500.withOpacity(0.14)),

          // ── Decorative rings ──
          Center(
            child: RotationTransition(
              turns: _ring1Ctrl,
              child: SizedBox(
                width: 380,
                height: 380,
                child: CustomPaint(
                  painter: _DashedRingPainter(
                    color: _C.v500.withOpacity(0.12),
                    strokeWidth: 1.0,
                    dashCount: 32,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: RotationTransition(
              turns: Tween(begin: 1.0, end: 0.0).animate(_ring2Ctrl),
              child: SizedBox(
                width: 480,
                height: 480,
                child: CustomPaint(
                  painter: _DashedRingPainter(
                    color: _C.p400.withOpacity(0.08),
                    strokeWidth: 0.8,
                    dashCount: 48,
                  ),
                ),
              ),
            ),
          ),

          // ── Floating particles ──
          ...List.generate(12, (i) => _buildParticle(i, size)),

          // ── Main content ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo orb
                _buildLogoOrb(),

                const SizedBox(height: 32),

                // Title + subtitle
                _buildTitle(),

                const SizedBox(height: 52),

                // Progress bar
                _buildProgressBar(),

                const SizedBox(height: 16),

                // Loading label
                FadeTransition(
                  opacity: _textFade,
                  child: const Text(
                    'Chargement…',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.gray500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Version tag ──
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: const Text(
                'v1.2.1',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _C.gray500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Logo Orb
  // ─────────────────────────────────────────
  Widget _buildLogoOrb() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: AnimatedBuilder(
          animation: _orbCtrl,
          builder: (_, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _C.p500.withOpacity(_orbGlow.value * 0.5),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Scale pulse
                Transform.scale(
                  scale: _orbScale.value,
                  child: child,
                ),
              ],
            );
          },
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _C.gradBtn,
              boxShadow: [
                BoxShadow(
                  color: _C.p500.withOpacity(0.55),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gloss
                Positioned(
                  top: 10,
                  left: 14,
                  child: Container(
                    width: 42,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.22),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.library_music_rounded,
                  color: _C.white,
                  size: 48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Title
  // ─────────────────────────────────────────
  Widget _buildTitle() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (b) => _C.gradMain.createShader(b),
              child: const Text(
                '2BLOCK',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.04,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: _C.gradMain,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MUSIC',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.gray500,
                    letterSpacing: 0.22,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 24,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: _C.gradMain,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Progress Bar
  // ─────────────────────────────────────────
  Widget _buildProgressBar() {
    return FadeTransition(
      opacity: _textFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, __) {
                return Stack(
                  children: [
                    // Track
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: _progressCtrl.value,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: _C.gradMain,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: _C.v400.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Glowing head
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) {
                        return FractionallySizedBox(
                          widthFactor: _progressCtrl.value,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.v400.withOpacity(0.9),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Floating Particles
  // ─────────────────────────────────────────
  Widget _buildParticle(int index, Size size) {
    final rng = math.Random(index * 42);
    final x = rng.nextDouble() * size.width;
    final y = rng.nextDouble() * size.height;
    final particleSize = 2.0 + rng.nextDouble() * 3;
    final delay = rng.nextDouble();
    final colors = [_C.v400, _C.p400, _C.v500, _C.p500];
    final color = colors[index % colors.length];

    return Positioned(
      left: x,
      top: y,
      child: AnimatedBuilder(
        animation: _particleCtrl,
        builder: (_, __) {
          final t = ((_particleCtrl.value + delay) % 1.0);
          final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity * 0.5,
            child: Container(
              width: particleSize,
              height: particleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Ambient blob helper
  // ─────────────────────────────────────────
  Widget _blob(Offset offset, double size, Color color) => Positioned(
        left: offset.dx,
        top: offset.dy,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  Dashed Ring Painter
// ─────────────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final dashAngle = (2 * math.pi) / dashCount;
    final fillAngle = dashAngle * 0.55;

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        fillAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.color != color || old.dashCount != dashCount;
}
