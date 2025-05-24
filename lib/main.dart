import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'Reflectif.AI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
  
class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _speakTicker;
  late Animation<double> _pulse;

  // Manually controlled
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _speakTicker = AnimationController(
      duration: const Duration(seconds: 10000), // long-lived, time-based
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speakTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _speakTicker]),
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3ec0ec), Color(0xFF7f29d2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildTitle(),
                const SizedBox(height: 40),
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        isSpeaking
                            ? _buildSpeakingRing(_speakTicker.value)
                            : _buildPulsingRing(),
                        _buildLogo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3ec0ec), Color(0xFF7f29d2)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 2, offset: const Offset(-2, -2)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
      ),
      child: const Text(
        'ReflectifAI',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 2,
          shadows: [Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(2.0, 2.0))],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 150,
      height: 150,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPulsingRing() {
    final scale = _pulse.value;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFA4D2F4).withOpacity(0.7 * (2 - scale)),
              const Color(0xFFA4D2F4).withOpacity(0.2 * (2 - scale)),
              Colors.transparent,
            ],
            stops: const [0.6, 0.85, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFFA4D2F4).withOpacity(0.5), blurRadius: 60, spreadRadius: 20),
            BoxShadow(color: const Color(0xFF3ec0ec).withOpacity(0.2), blurRadius: 100, spreadRadius: 40),
          ],
          border: Border.all(color: const Color(0xFFA4D2F4).withOpacity(0.9), width: 12),
        ),
      ),
    );
  }

  Widget _buildSpeakingRing(double progress) {
    final time = DateTime.now().millisecondsSinceEpoch / 750.0;
    return CustomPaint(
      size: const Size(220, 220),
      painter: _InfiniteSpeakingRingPainter(time),
    );
  }
}

class _InfiniteSpeakingRingPainter extends CustomPainter {
  final double time;
  final int points = 250;
  final double baseRadius = 110;

  _InfiniteSpeakingRingPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFFA4D2F4).withOpacity(0.3),
          const Color(0xFF3ec0ec).withOpacity(0.5),
          const Color(0xFFA4D2F4).withOpacity(0.2),
        ],
        startAngle: 0,
        endAngle: 2 * math.pi,
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final path = Path();
    for (int i = 0; i <= points; i++) {
      final angle = (2 * math.pi / points) * i;
      final wave = math.sin(angle * 3 + time * 6) * 10 + math.sin(angle * 5 + time * 3) * 6;
      final r = baseRadius + wave;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InfiniteSpeakingRingPainter oldDelegate) => true;
}
