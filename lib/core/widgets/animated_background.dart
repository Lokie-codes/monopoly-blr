import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<FloatingOrb> _orbs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    final random = Random();
    _orbs = List.generate(6, (index) => FloatingOrb(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 100 + random.nextDouble() * 200,
      color: [
        AppColors.primaryGradientStart,
        AppColors.primaryGradientEnd,
        AppColors.accentPurple,
        AppColors.accentBlue,
      ][index % 4],
      speed: 0.5 + random.nextDouble() * 1.5,
      angle: random.nextDouble() * 2 * pi,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.darkGradient,
          ),
        ),
        
        // Animated orbs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: OrbPainter(_orbs, _controller.value),
              size: Size.infinite,
            );
          },
        ),
        
        // Noise overlay for texture
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                Colors.white.withOpacity(0.03),
                Colors.transparent,
              ],
            ),
          ),
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class FloatingOrb {
  double x;
  double y;
  final double size;
  final Color color;
  final double speed;
  final double angle;

  FloatingOrb({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speed,
    required this.angle,
  });
}

class OrbPainter extends CustomPainter {
  final List<FloatingOrb> orbs;
  final double animationValue;

  OrbPainter(this.orbs, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var orb in orbs) {
      final dx = cos(orb.angle + animationValue * orb.speed * 2 * pi) * 50;
      final dy = sin(orb.angle + animationValue * orb.speed * 2 * pi) * 50;
      
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(0.3),
            orb.color.withOpacity(0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(
              orb.x * size.width + dx,
              orb.y * size.height + dy,
            ),
            radius: orb.size,
          ),
        );

      canvas.drawCircle(
        Offset(orb.x * size.width + dx, orb.y * size.height + dy),
        orb.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrbPainter oldDelegate) => true;
}

class ParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  
  const ParticleBackground({
    super.key, 
    required this.child,
    this.particleCount = 30,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    final random = Random();
    _particles = List.generate(widget.particleCount, (index) => Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 2 + random.nextDouble() * 4,
      opacity: 0.1 + random.nextDouble() * 0.3,
      speed: 0.2 + random.nextDouble() * 0.8,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.darkGradient,
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: ParticlePainter(_particles, _controller.value),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class Particle {
  double x;
  double y;
  final double size;
  final double opacity;
  final double speed;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final y = (particle.y + animationValue * particle.speed) % 1.0;
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
