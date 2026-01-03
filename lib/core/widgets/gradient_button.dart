import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double borderRadius;
  final double? width;
  final bool isLoading;
  final IconData? icon;
  final bool small;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient = AppGradients.primaryGradient,
    this.borderRadius = 12,
    this.width,
    this.isLoading = false,
    this.icon,
    this.small = false,
  });

  const GradientButton.success({
    super.key,
    required this.text,
    this.onPressed,
    this.borderRadius = 12,
    this.width,
    this.isLoading = false,
    this.icon,
    this.small = false,
  }) : gradient = AppGradients.successGradient;

  const GradientButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.borderRadius = 12,
    this.width,
    this.isLoading = false,
    this.icon,
    this.small = false,
  }) : gradient = AppGradients.dangerGradient;

  const GradientButton.gold({
    super.key,
    required this.text,
    this.onPressed,
    this.borderRadius = 12,
    this.width,
    this.isLoading = false,
    this.icon,
    this.small = false,
  }) : gradient = AppGradients.goldGradient;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final vPadding = widget.small ? 8.0 : 12.0;
    final hPadding = widget.small ? 12.0 : 16.0;
    final iconSize = widget.small ? 14.0 : 16.0;
    final fontSize = widget.small ? 11.0 : 13.0;
    
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: isDisabled ? null : (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(vertical: vPadding, horizontal: hPadding),
          decoration: BoxDecoration(
            gradient: isDisabled
                ? LinearGradient(
                    colors: [Colors.grey.shade700, Colors.grey.shade800],
                  )
                : widget.gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isDisabled || _isPressed
                ? null
                : [
                    BoxShadow(
                      color: widget.gradient.colors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: iconSize),
                      SizedBox(width: widget.small ? 4 : 6),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class OutlineGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final double borderRadius;
  final double? width;
  final IconData? icon;

  const OutlineGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradientColors = const [
      AppColors.primaryGradientStart,
      AppColors.primaryGradientEnd,
    ],
    this.borderRadius = 12,
    this.width,
    this.icon,
  });

  @override
  State<OutlineGradientButton> createState() => _OutlineGradientButtonState();
}

class _OutlineGradientButtonState extends State<OutlineGradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: _isHovered
                ? LinearGradient(colors: widget.gradientColors)
                : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.gradientColors.first,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: _isHovered ? Colors.white : widget.gradientColors.first,
                  size: 16,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: _isHovered ? Colors.white : widget.gradientColors.first,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
