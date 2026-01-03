import 'package:flutter/material.dart';

class AnimatedBalanceText extends StatefulWidget {
  final int balance;
  final TextStyle style;
  final String prefix;

  const AnimatedBalanceText({
    super.key,
    required this.balance,
    required this.style,
    this.prefix = '₹',
  });

  @override
  State<AnimatedBalanceText> createState() => _AnimatedBalanceTextState();
}

class _AnimatedBalanceTextState extends State<AnimatedBalanceText> with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<Color?> _colorAnimation;
  int? _lastBalance;

  @override
  void initState() {
    super.initState();
    _lastBalance = widget.balance;
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _colorAnimation = ColorTween(
      begin: null,
      end: null,
    ).animate(_flashController);
  }

  @override
  void didUpdateWidget(AnimatedBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance != oldWidget.balance) {
      final isIncrease = widget.balance > oldWidget.balance;
      _colorAnimation = ColorTween(
        begin: isIncrease ? Colors.greenAccent : Colors.redAccent,
        end: widget.style.color ?? Colors.white,
      ).animate(CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeOut,
      ));
      
      _flashController.forward(from: 0);
      _lastBalance = widget.balance;
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: widget.balance.toDouble(), end: widget.balance.toDouble()),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Text(
              '${widget.prefix}${value.toInt()}',
              style: widget.style.copyWith(
                color: _flashController.isAnimating ? _colorAnimation.value : widget.style.color,
                shadows: _flashController.isAnimating ? [
                   Shadow(
                     color: _colorAnimation.value!.withOpacity(0.5),
                     blurRadius: 8,
                   )
                ] : widget.style.shadows,
              ),
            );
          },
        );
      },
    );
  }
}
