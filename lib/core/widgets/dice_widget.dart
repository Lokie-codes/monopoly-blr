import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DiceRollOverlay extends StatefulWidget {
  final int result;
  final VoidCallback onComplete;

  const DiceRollOverlay({
    super.key,
    required this.result,
    required this.onComplete,
  });

  @override
  State<DiceRollOverlay> createState() => _DiceRollOverlayState();
}

class _DiceRollOverlayState extends State<DiceRollOverlay>
    with TickerProviderStateMixin {
  late AnimationController _rollController;
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  
  int _displayNumber = 1;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    
    // Roll animation (rapid number changes)
    _rollController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 8 * pi).animate(
      CurvedAnimation(parent: _rollController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _rollController, curve: Curves.easeOut));
    
    // Bounce animation for final result
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
    
    // Fade out animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _startAnimation();
  }

  void _startAnimation() async {
    // Start roll animation
    _rollController.forward();
    
    // Rapidly change numbers during roll
    final random = Random();
    for (int i = 0; i < 15; i++) {
      await Future.delayed(Duration(milliseconds: 50 + (i * 10)));
      if (mounted) {
        setState(() {
          _displayNumber = random.nextInt(6) + 1;
        });
      }
    }
    
    // Show final result
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _displayNumber = widget.result;
        _showResult = true;
      });
      _bounceController.forward();
    }
    
    // Wait and fade out
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      _fadeController.forward().then((_) {
        widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _showResult ? _bounceController : _rollController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _showResult ? 0 : _rotationAnimation.value,
                  child: Transform.scale(
                    scale: _showResult ? _bounceAnimation.value : 1.0,
                    child: child,
                  ),
                );
              },
              child: _buildDice(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDice() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        gradient: _showResult
            ? AppGradients.goldGradient
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFF0F0F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _showResult 
                ? AppColors.accentGold.withOpacity(0.6)
                : Colors.black.withOpacity(0.4),
            blurRadius: _showResult ? 40 : 20,
            spreadRadius: _showResult ? 5 : 0,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: _showResult 
              ? AppColors.accentGold
              : Colors.grey.shade300,
          width: 3,
        ),
      ),
      child: Center(
        child: _buildDiceFace(_displayNumber),
      ),
    );
  }

  Widget _buildDiceFace(int number) {
    final dotColor = _showResult ? Colors.white : Colors.black87;
    final dotSize = 18.0;
    
    switch (number) {
      case 1:
        return _buildDot(dotSize, dotColor);
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(20), child: _buildDot(dotSize, dotColor))),
            Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.all(20), child: _buildDot(dotSize, dotColor))),
          ],
        );
      case 3:
        return Stack(
          children: [
            Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(20), child: _buildDot(dotSize, dotColor))),
            Center(child: _buildDot(dotSize, dotColor)),
            Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.all(20), child: _buildDot(dotSize, dotColor))),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
            ),
          ],
        );
      case 5:
        return Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
                ),
              ],
            ),
            Center(child: _buildDot(dotSize, dotColor)),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildDot(dotSize, dotColor), _buildDot(dotSize, dotColor)],
            ),
          ],
        );
      default:
        return _buildDot(dotSize, dotColor);
    }
  }

  Widget _buildDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

// Simplified dice display for sidebar/results
class DiceResultWidget extends StatelessWidget {
  final int result;
  final double size;

  const DiceResultWidget({
    super.key,
    required this.result,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.goldGradient,
        borderRadius: BorderRadius.circular(size * 0.15),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          result.toString(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(1, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
