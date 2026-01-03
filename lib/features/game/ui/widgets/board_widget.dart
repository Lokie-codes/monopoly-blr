import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/board_data.dart';
import '../../domain/models/player.dart';
import '../../../../core/theme/app_theme.dart';

class MonopolyBoardWidget extends StatefulWidget {
  final List<Player> players;
  final Map<int, String> propertyOwners;

  const MonopolyBoardWidget({
    super.key, 
    required this.players, 
    required this.propertyOwners,
  });

  @override
  State<MonopolyBoardWidget> createState() => _MonopolyBoardWidgetState();
}

class _MonopolyBoardWidgetState extends State<MonopolyBoardWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper function to calculate the center position for a given board index
  static Offset getPositionForIndex(int index, double boardSize, double unit) {
    double centerX = 0;
    double centerY = 0;

    // Bottom Row (Left to Right): indices 0-7
    if (index >= 0 && index <= 7) {
      centerX = (index * unit) + (unit * 0.5);
      centerY = boardSize - (unit * 0.5);
    }
    // Right Column (Bottom to Top): indices 8-13
    else if (index >= 8 && index <= 13) {
      centerX = boardSize - (unit * 0.5);
      centerY = boardSize - ((index - 7) * unit) - (unit * 0.5);
    }
    // Top Row (Right to Left): indices 14-21
    else if (index >= 14 && index <= 21) {
      centerX = boardSize - ((index - 14) * unit) - (unit * 0.5); // Fixed calculation
      centerY = unit * 0.5;
    }
    // Left Column (Top to Bottom): indices 22-27
    else if (index >= 22 && index <= 27) {
      centerX = unit * 0.5;
      centerY = ((index - 21) * unit) + (unit * 0.5);
    }

    return Offset(centerX, centerY);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = constraints.biggest.shortestSide;
        // 8x8 grid means 8 units
        final unit = size / 8.0;

        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A472A), Color(0xFF0D2818)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentGold.withOpacity(0.5),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: AppColors.accentGold.withOpacity(0.1),
                  blurRadius: 60,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  // Background Pattern
                  _buildBackgroundPattern(size),
                  
                  // Center Logo
                  _buildCenterLogo(size),

                  // Bottom Row (Left to Right): indices 0-7
                  for (int i = 0; i <= 7; i++)
                    _buildSpacePositioned(i, size, unit, Side.bottom, i),

                  // Right Column (Bottom to Top): indices 8-13
                  for (int i = 8; i <= 13; i++)
                    _buildSpacePositioned(i, size, unit, Side.right, i - 7),

                  // Top Row (Right to Left): indices 14-21
                  for (int i = 14; i <= 21; i++)
                    _buildSpacePositioned(i, size, unit, Side.top, i - 14),

                  // Left Column (Top to Bottom): indices 22-27
                  for (int i = 22; i <= 27; i++)
                    _buildSpacePositioned(i, size, unit, Side.left, i - 21),

                  // Player Tokens - using animated pawn widgets
                  ...widget.players.map((p) => _AnimatedPawn(
                    key: ValueKey('pawn_${p.id}'),
                    player: p,
                    players: widget.players,
                    boardSize: size,
                    unit: unit,
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundPattern(double size) {
    return Positioned.fill(
      child: CustomPaint(
        painter: BoardPatternPainter(),
      ),
    );
  }

  Widget _buildCenterLogo(double size) {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animationController.value * 0.1 * pi,
            child: child,
          );
        },
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.accentGold.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppGradients.goldGradient.createShader(bounds),
                  child: Text(
                    'MONOPOLY',
                    style: TextStyle(
                      fontSize: size * 0.06,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentGold.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'BANGALORE',
                    style: TextStyle(
                      fontSize: size * 0.03,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGold.withOpacity(0.8),
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacePositioned(int index, double boardSize, double unit, Side side, int positionOnSide) {
    double? bottom, left, top, right;

    switch (side) {
      case Side.bottom:
        bottom = 0;
        left = positionOnSide * unit;
        break;
      case Side.right:
        right = 0;
        bottom = positionOnSide * unit;
        break;
      case Side.top:
        top = 0;
        right = positionOnSide * unit;
        break;
      case Side.left:
        left = 0;
        top = positionOnSide * unit;
        break;
    }

    final data = monopolyBoard.firstWhere(
      (e) => e.index == index,
      orElse: () => BoardSpaceData(index: index, name: "?", type: "Unknown"),
    );

    // Ownership Visuals
    Color? ownerColor;
    bool isOwned = false;

    if (widget.propertyOwners.containsKey(index)) {
      final ownerId = widget.propertyOwners[index];
      final owner = widget.players.firstWhere(
        (p) => p.id == ownerId,
        orElse: () => Player(id: '', name: ''),
      );
      if (owner.id.isNotEmpty) {
        ownerColor = Color(int.parse(owner.colorHex.replaceFirst('#', '0xff')));
        isOwned = true;
      }
    }

    return Positioned(
      bottom: bottom,
      left: left,
      top: top,
      right: right,
      width: unit,
      height: unit,
      child: _buildPropertyTile(data, side, unit, isOwned, ownerColor),
    );
  }

  Widget _buildPropertyTile(
    BoardSpaceData data, 
    Side side, 
    double unit, 
    bool isOwned,
    Color? ownerColor,
  ) {
    final isCorner = data.type == 'Corner';
    final hasColor = data.colorHex != null;
    final propertyColor = hasColor 
        ? Color(int.parse(data.colorHex!.replaceFirst('#', '0xff')))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isCorner 
            ? AppColors.darkSurface.withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        border: Border.all(
          color: isOwned && ownerColor != null
              ? ownerColor
              : Colors.black.withOpacity(0.3),
          width: isOwned ? 3 : 1,
        ),
        boxShadow: isOwned && ownerColor != null
            ? [
                BoxShadow(
                  color: ownerColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: _buildTileContent(data, side, unit, propertyColor, isCorner),
    );
  }

  Widget _buildTileContent(
    BoardSpaceData data, 
    Side side, 
    double unit, 
    Color? propertyColor,
    bool isCorner,
  ) {
    if (isCorner) {
      return _buildCornerContent(data, unit);
    }

    final colorStripSize = unit * 0.18;

    return Column(
      children: [
        if (propertyColor != null && side == Side.bottom) ...[
          Container(
            height: colorStripSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [propertyColor, propertyColor.withOpacity(0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(child: _buildPropertyName(data, unit)),
        ] else if (propertyColor != null && side == Side.top) ...[
          Expanded(child: _buildPropertyName(data, unit)),
          Container(
            height: colorStripSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [propertyColor.withOpacity(0.8), propertyColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ] else if (propertyColor != null && side == Side.left) ...[
          Expanded(
            child: Row(
              children: [
                Container(
                  width: colorStripSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [propertyColor, propertyColor.withOpacity(0.8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Expanded(child: _buildPropertyName(data, unit)),
              ],
            ),
          ),
        ] else if (propertyColor != null && side == Side.right) ...[
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildPropertyName(data, unit)),
                Container(
                  width: colorStripSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [propertyColor.withOpacity(0.8), propertyColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Expanded(child: _buildPropertyName(data, unit)),
        ],
      ],
    );
  }

  Widget _buildCornerContent(BoardSpaceData data, double unit) {
    IconData? icon;
    Color iconColor = Colors.white;
    
    switch (data.name.toLowerCase()) {
      case 'go':
        icon = Icons.arrow_forward;
        iconColor = AppColors.accentGreen;
        break;
      case 'jail':
        icon = Icons.lock;
        iconColor = AppColors.jailOrange;
        break;
      case 'free parking':
        icon = Icons.local_parking;
        iconColor = AppColors.accentBlue;
        break;
      case 'go to jail':
        icon = Icons.gavel;
        iconColor = AppColors.accentRed;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              padding: EdgeInsets.all(unit * 0.06),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(unit * 0.08),
              ),
              child: Icon(icon, color: iconColor, size: unit * 0.22),
            ),
          SizedBox(height: unit * 0.03),
          Text(
            data.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: unit * 0.12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyName(BoardSpaceData data, double unit) {
    return Container(
      padding: EdgeInsets.all(unit * 0.03),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              data.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: unit * 0.11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (data.price != null) ...[
            SizedBox(height: unit * 0.02),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: unit * 0.04,
                vertical: unit * 0.01,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(unit * 0.04),
              ),
              child: Text(
                '₹${data.price}',
                style: TextStyle(
                  fontSize: unit * 0.095,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
          if (data.type == 'Railroad')
            Icon(Icons.train, size: unit * 0.1, color: Colors.black54),
          if (data.type == 'Utility')
            Icon(Icons.lightbulb, size: unit * 0.1, color: Colors.amber),
          if (data.type == 'Chance')
            Icon(Icons.help_outline, size: unit * 0.1, color: Colors.red),
          if (data.type == 'CommunityChest')
            Icon(Icons.inventory_2, size: unit * 0.1, color: Colors.blue),
        ],
      ),
    );
  }
}

/// A stateful widget that animates the pawn moving step-by-step along the board tiles
/// instead of moving diagonally in a straight line
class _AnimatedPawn extends StatefulWidget {
  final Player player;
  final List<Player> players;
  final double boardSize;
  final double unit;

  const _AnimatedPawn({
    super.key,
    required this.player,
    required this.players,
    required this.boardSize,
    required this.unit,
  });

  @override
  State<_AnimatedPawn> createState() => _AnimatedPawnState();
}

class _AnimatedPawnState extends State<_AnimatedPawn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  
  int _currentAnimatedPosition = 0;
  int _targetPosition = 0;
  bool _isAnimating = false;
  List<int> _pathToAnimate = [];
  int _currentPathIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentAnimatedPosition = widget.player.position;
    _targetPosition = widget.player.position;
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStepComplete();
      }
    });
    
    _setStaticPosition(widget.player.position);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPawn oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newPosition = widget.player.position;
    
    // Only start animation if position changed and we're not already animating to this position
    if (newPosition != _targetPosition) {
      _startPathAnimation(_currentAnimatedPosition, newPosition);
    }
  }

  void _startPathAnimation(int from, int to) {
    _targetPosition = to;
    
    // Build the path of tiles to visit
    _pathToAnimate = _buildPath(from, to);
    
    if (_pathToAnimate.isEmpty) {
      // Same position, nothing to animate
      return;
    }
    
    _currentPathIndex = 0;
    _isAnimating = true;
    _animateNextStep();
  }

  List<int> _buildPath(int from, int to) {
    const totalSpaces = 28;
    List<int> path = [];
    
    if (from == to) return path;
    
    // Calculate forward distance (normal movement direction)
    int forwardDistance = (to - from) % totalSpaces;
    if (forwardDistance < 0) forwardDistance += totalSpaces;
    
    // Calculate backward distance
    int backwardDistance = totalSpaces - forwardDistance;
    
    // Choose the shorter path, but prefer forward for typical movement
    // For "Go to Jail" or teleport scenarios, use shorter path
    bool goForward = forwardDistance <= backwardDistance || forwardDistance <= 6;
    
    if (goForward) {
      // Forward path
      int current = from;
      for (int i = 0; i < forwardDistance; i++) {
        current = (current + 1) % totalSpaces;
        path.add(current);
      }
    } else {
      // Backward path (for special cases like going to jail from far away)
      int current = from;
      for (int i = 0; i < backwardDistance; i++) {
        current = (current - 1 + totalSpaces) % totalSpaces;
        path.add(current);
      }
    }
    
    return path;
  }

  void _animateNextStep() {
    if (_currentPathIndex >= _pathToAnimate.length) {
      // Animation complete
      _isAnimating = false;
      _currentAnimatedPosition = _targetPosition;
      return;
    }
    
    final fromPos = _currentPathIndex == 0 
        ? _currentAnimatedPosition 
        : _pathToAnimate[_currentPathIndex - 1];
    final toPos = _pathToAnimate[_currentPathIndex];
    
    final fromOffset = _MonopolyBoardWidgetState.getPositionForIndex(
      fromPos, widget.boardSize, widget.unit
    );
    final toOffset = _MonopolyBoardWidgetState.getPositionForIndex(
      toPos, widget.boardSize, widget.unit
    );
    
    _animation = Tween<Offset>(
      begin: fromOffset,
      end: toOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.reset();
    _controller.forward();
  }

  void _onStepComplete() {
    if (!mounted) return;
    
    _currentPathIndex++;
    
    if (_currentPathIndex < _pathToAnimate.length) {
      // Continue to next step
      setState(() {
        _currentAnimatedPosition = _pathToAnimate[_currentPathIndex - 1];
      });
      _animateNextStep();
    } else {
      // Done animating
      setState(() {
        _isAnimating = false;
        _currentAnimatedPosition = _targetPosition;
      });
    }
  }

  void _setStaticPosition(int position) {
    final offset = _MonopolyBoardWidgetState.getPositionForIndex(
      position, widget.boardSize, widget.unit
    );
    
    _animation = AlwaysStoppedAnimation(offset);
  }

  @override
  Widget build(BuildContext context) {
    // Add small offset based on player index to prevent overlap
    final playerIndex = widget.players.indexOf(widget.player);
    final offsetX = (playerIndex % 2) * (widget.unit * 0.18) - (widget.unit * 0.09);
    final offsetY = (playerIndex ~/ 2) * (widget.unit * 0.18) - (widget.unit * 0.09);
    
    final color = Color(int.parse(widget.player.colorHex.replaceFirst('#', '0xff')));
    final tokenSize = widget.unit * 0.28;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pos = _animation.value;
        final leftPos = pos.dx - (tokenSize / 2) + offsetX;
        final topPos = pos.dy - (tokenSize / 2) + offsetY;
        
        return Positioned(
          left: leftPos,
          top: topPos,
          child: child!,
        );
      },
      child: Container(
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.player.name.isNotEmpty ? widget.player.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: tokenSize * 0.45,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BoardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    
    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum Side { bottom, left, top, right }
