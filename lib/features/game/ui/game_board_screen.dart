import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/game_provider.dart';
import 'package:monopoly_blr/features/game/domain/models/game_state.dart';
import 'package:monopoly_blr/features/game/domain/models/board_data.dart';
import 'package:monopoly_blr/features/game/domain/models/trade_offer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/dice_widget.dart';
import 'widgets/board_widget.dart';
import 'widgets/chat_widget.dart';
import 'widgets/animated_balance_text.dart';
import 'property_management_screen.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> 
    with TickerProviderStateMixin {
  bool _showChat = false;
  bool _showDiceAnimation = false;
  int _diceResult = 1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showDiceRoll(int result) {
    setState(() {
      _diceResult = result;
      _showDiceAnimation = true;
    });
  }

  void _hideDiceRoll() {
    setState(() {
      _showDiceAnimation = false;
    });
    // Apply the dice result now that animation is done
    ref.read(networkProvider.notifier).applyDiceResult();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final networkState = ref.watch(networkProvider);
    final chatState = ref.watch(chatProvider);

    // Listen for pending dice rolls (animation trigger)
    ref.listen(gameStateProvider.select((s) => s.pendingDiceRoll), (previous, next) {
      if (next.isNotEmpty && (previous == null || previous.isEmpty || previous != next)) {
        _showDiceRoll(next.first);
      }
    });

    // Listen for Game Over
    ref.listen(gameStateProvider.select((s) => s.phase), (previous, next) {
      if (next == GamePhase.ended) {
        _showGameOverDialog(context, ref);
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.darkGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;
                  
                  if (isMobile) {
                    return _buildMobileLayout(gameState, networkState, chatState);
                  } else {
                    return _buildDesktopLayout(gameState, networkState, chatState);
                  }
                },
              ),
              
              // Dice Animation Overlay
              if (_showDiceAnimation)
                DiceRollOverlay(
                  result: _diceResult,
                  onComplete: _hideDiceRoll,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(GameState gameState, NetworkState networkState, ChatState chatState) {
    return Row(
      children: [
        // Left Sidebar - Players & Actions
        Container(
          width: 280,
          margin: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildNotificationBanner(gameState),
              const SizedBox(height: 12),
              Expanded(child: _buildPlayersList(gameState, networkState)),
              const SizedBox(height: 12),
              _buildDiceDisplay(gameState),
              const SizedBox(height: 12),
              if (networkState.myPlayerId == gameState.currentPlayerId)
                TurnActionPanel(pulseAnimation: _pulseAnimation)
              else
                _buildWaitingCard(gameState),
            ],
          ),
        ),
        
        // Center - Game Board
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: MonopolyBoardWidget(
              players: gameState.players, 
              propertyOwners: gameState.propertyOwners,
            ),
          ),
        ),
        
        // Right Sidebar - Chat
        Container(
          width: 300,
          margin: const EdgeInsets.all(12),
          child: ChatWidget(
            messages: chatState.messages,
            currentPlayerId: networkState.myPlayerId ?? '',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(GameState gameState, NetworkState networkState, ChatState chatState) {
    return Stack(
      children: [
        Column(
          children: [
            // Players Bar - Show all players
            _buildMobilePlayersBar(gameState, networkState),
            
            // Notification
            if (gameState.notificationMessage != null && gameState.notificationMessage!.isNotEmpty)
              _buildMobileNotification(gameState.notificationMessage!),
            
            // #7e: Pending trade accept/reject banner
            if (gameState.pendingTradeOffer != null && gameState.pendingTradeOffer!.toPlayerId == networkState.myPlayerId)
              Consumer(builder: (context, ref, _) {
                final offer = gameState.pendingTradeOffer!;
                final offeredNames = offer.offeredPropertyIndices.map((i) => monopolyBoard.firstWhere((s) => s.index == i).name).join(', ');
                final requestedNames = offer.requestedPropertyIndices.map((i) => monopolyBoard.firstWhere((s) => s.index == i).name).join(', ');
                final fromName = gameState.players.firstWhere((p) => p.id == offer.fromPlayerId).name;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📦 Trade from $fromName', style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                      if (offeredNames.isNotEmpty) Text('Offers: $offeredNames', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      if (requestedNames.isNotEmpty) Text('Wants: $requestedNames', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      if (offer.cashOffer != 0) Text('Cash: ${offer.cashOffer > 0 ? "+₹${offer.cashOffer}" : "-₹${-offer.cashOffer}"}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 6)),
                            onPressed: () => ref.read(networkProvider.notifier).processAcceptTrade(networkState.myPlayerId!),
                            icon: const Icon(Icons.check, size: 16), label: const Text('Accept', style: TextStyle(fontSize: 12)),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 6)),
                            onPressed: () => ref.read(networkProvider.notifier).processRejectTrade(networkState.myPlayerId!),
                            icon: const Icon(Icons.close, size: 16), label: const Text('Reject', style: TextStyle(fontSize: 12)),
                          )),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            
            // Game Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: MonopolyBoardWidget(
                  players: gameState.players, 
                  propertyOwners: gameState.propertyOwners,
                ),
              ),
            ),
            
            // Bottom Actions
            if (networkState.myPlayerId == gameState.currentPlayerId)
              Container(
                margin: const EdgeInsets.all(8),
                child: TurnActionPanel(pulseAnimation: _pulseAnimation, compact: true),
              ),
          ],
        ),
        
        // #21: Property Management Button - Floating
        Positioned(
          right: 12,
          bottom: networkState.myPlayerId == gameState.currentPlayerId ? 140 : 52,
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PropertyManagementScreen())),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.teal, Colors.tealAccent.shade700]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.glowShadow(Colors.teal),
              ),
              child: const Icon(Icons.home_work, color: Colors.white, size: 20),
            ),
          ),
        ),
        
        // Chat Button - Floating
        Positioned(
          right: 12,
          bottom: networkState.myPlayerId == gameState.currentPlayerId ? 100 : 12,
          child: GestureDetector(
            onTap: () => setState(() => _showChat = !_showChat),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.glowShadow(AppColors.primaryGradientStart),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
            ),
          ),
        ),
        
        // Chat Overlay
        if (_showChat)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showChat = false),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    margin: const EdgeInsets.all(12),
                    child: ChatWidget(
                      messages: chatState.messages,
                      currentPlayerId: networkState.myPlayerId ?? '',
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobilePlayersBar(GameState gameState, NetworkState networkState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: gameState.players.map((player) {
            final isCurrentTurn = player.id == gameState.currentPlayerId;
            final isMe = player.id == networkState.myPlayerId;
            final color = Color(int.parse(player.colorHex.replaceFirst('#', '0xff')));
            
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: isCurrentTurn 
                    ? LinearGradient(
                        colors: [
                          AppColors.accentGreen.withOpacity(0.3),
                          AppColors.accentGreen.withOpacity(0.1),
                        ],
                      )
                    : null,
                color: isCurrentTurn ? null : AppColors.darkSurfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrentTurn 
                      ? AppColors.accentGreen 
                      : isMe 
                          ? AppColors.primaryGradientStart.withOpacity(0.5) 
                          : AppColors.glassBorder,
                  width: isCurrentTurn ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Player Avatar
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            player.name.length > 8 ? '${player.name.substring(0, 8)}...' : player.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isCurrentTurn ? AppColors.accentGreen : AppColors.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGradientStart.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'ME',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGradientStart,
                                ),
                              ),
                            ),
                          ],
                          if (player.isJailed) ...[
                            const SizedBox(width: 3),
                            Icon(Icons.lock, size: 10, color: AppColors.jailOrange),
                          ],
                        ],
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => AppGradients.goldGradient.createShader(bounds),
                        child: AnimatedBalanceText(
                          balance: player.balance,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isCurrentTurn) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.play_arrow, color: AppColors.accentGreen, size: 14),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(
                badge,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayerAvatar(GameState gameState) {
    final currentPlayer = gameState.players.firstWhere(
      (p) => p.id == gameState.currentPlayerId,
      orElse: () => gameState.players.first,
    );
    final color = Color(int.parse(currentPlayer.colorHex.replaceFirst('#', '0xff')));
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.glowShadow(color),
      ),
      child: Center(
        child: Text(
          currentPlayer.name.isNotEmpty ? currentPlayer.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getCurrentPlayerName(GameState gameState) {
    final currentPlayer = gameState.players.firstWhere(
      (p) => p.id == gameState.currentPlayerId,
      orElse: () => gameState.players.first,
    );
    return "${currentPlayer.name}'s Turn";
  }

  Widget _buildMobileNotification(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(
        gradient: AppGradients.primaryGradient,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildNotificationBanner(GameState gameState) {
    if (gameState.notificationMessage == null || gameState.notificationMessage!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.glowShadow(AppColors.primaryGradientStart),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              gameState.notificationMessage!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(GameState gameState, NetworkState networkState) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Players',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${gameState.players.length} online',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: gameState.players.length,
              itemBuilder: (ctx, i) {
                final player = gameState.players[i];
                final isTurn = player.id == gameState.currentPlayerId;
                final isMe = player.id == networkState.myPlayerId;
                final color = Color(int.parse(player.colorHex.replaceFirst('#', '0xff')));
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isTurn 
                        ? LinearGradient(
                            colors: [
                              AppColors.accentGreen.withOpacity(0.2),
                              AppColors.accentGreen.withOpacity(0.05),
                            ],
                          )
                        : null,
                    color: isTurn ? null : AppColors.darkSurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTurn 
                          ? AppColors.accentGreen.withOpacity(0.5) 
                          : AppColors.glassBorder,
                      width: isTurn ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isTurn ? AppShadows.glowShadow(color) : null,
                        ),
                        child: Center(
                          child: Text(
                            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGradientStart.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryGradientStart,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => AppGradients.goldGradient.createShader(bounds),
                                  child: AnimatedBalanceText(
                                    balance: player.balance,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (player.isJailed) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.lock, size: 10, color: AppColors.jailOrange),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isTurn)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceDisplay(GameState gameState) {
    if (gameState.lastDiceRoll.isEmpty) return const SizedBox.shrink();
    
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DiceResultWidget(result: gameState.lastDiceRoll.first, size: 36),
          const SizedBox(width: 12),
          Text(
            'Rolled ${gameState.lastDiceRoll.first}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard(GameState gameState) {
    final currentPlayer = gameState.players.firstWhere(
      (p) => p.id == gameState.currentPlayerId,
      orElse: () => gameState.players.first,
    );
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primaryGradientStart),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Waiting for ${currentPlayer.name}...",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPlayersBottomSheet(GameState gameState, NetworkState networkState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Players',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...gameState.players.map((player) {
              final isMe = player.id == networkState.myPlayerId;
              final isTurn = player.id == gameState.currentPlayerId;
              final color = Color(int.parse(player.colorHex.replaceFirst('#', '0xff')));
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: isTurn 
                      ? Border.all(color: AppColors.accentGreen, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          player.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          AnimatedBalanceText(
                            balance: player.balance,
                            style: const TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (player.isJailed)
                      Icon(Icons.lock, color: AppColors.jailOrange, size: 18),
                    if (!isMe && gameState.phase == GamePhase.playing)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showTradeDialog(context, ref, gameState, networkState, player.id, player.name);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz, color: Colors.amber, size: 14),
                                SizedBox(width: 3),
                                Text('Trade', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isTurn)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TURN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // #7e: Show trade proposal dialog
  void _showTradeDialog(BuildContext dialogContext, WidgetRef ref, GameState gameState, NetworkState networkState, String targetPlayerId, String targetName) {
    final myId = networkState.myPlayerId!;
    final myProperties = monopolyBoard.where((s) => gameState.propertyOwners[s.index] == myId && s.isBuyable).toList();
    final theirProperties = monopolyBoard.where((s) => gameState.propertyOwners[s.index] == targetPlayerId && s.isBuyable).toList();

    int? selectedOffer;
    int? selectedRequest;

    showDialog(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Trade with $targetName', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('You offer:', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (myProperties.isEmpty)
                  const Text('No properties to offer', style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: myProperties.map((p) => ChoiceChip(
                      label: Text(p.name, style: TextStyle(fontSize: 11, color: selectedOffer == p.index ? Colors.white : Colors.white70)),
                      selected: selectedOffer == p.index,
                      selectedColor: Colors.amber.shade700,
                      backgroundColor: const Color(0xFF2A2A4A),
                      onSelected: (v) => setDialogState(() => selectedOffer = v ? p.index : null),
                    )).toList(),
                  ),
                const SizedBox(height: 14),
                const Text('You request:', style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (theirProperties.isEmpty)
                  const Text('No properties to request', style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: theirProperties.map((p) => ChoiceChip(
                      label: Text(p.name, style: TextStyle(fontSize: 11, color: selectedRequest == p.index ? Colors.white : Colors.white70)),
                      selected: selectedRequest == p.index,
                      selectedColor: Colors.green.shade700,
                      backgroundColor: const Color(0xFF2A2A4A),
                      onSelected: (v) => setDialogState(() => selectedRequest = v ? p.index : null),
                    )).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
              onPressed: (selectedOffer != null || selectedRequest != null) ? () {
                final offer = TradeOffer(
                  fromPlayerId: myId,
                  toPlayerId: targetPlayerId,
                  offeredPropertyIndices: selectedOffer != null ? [selectedOffer!] : [],
                  requestedPropertyIndices: selectedRequest != null ? [selectedRequest!] : [],
                );
                ref.read(networkProvider.notifier).processTradeOffer(offer);
                Navigator.pop(ctx);
              } : null,
              child: const Text('Propose Trade'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppGradients.darkGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppGradients.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glowShadow(AppColors.accentGold),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                gameState.notificationMessage ?? 'We have a winner!',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GradientButton.gold(
                text: 'RETURN TO LOBBY',
                icon: Icons.home,
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TurnActionPanel extends ConsumerStatefulWidget {
  final Animation<double>? pulseAnimation;
  final bool compact;
  
  const TurnActionPanel({
    super.key, 
    this.pulseAnimation,
    this.compact = false,
  });

  @override
  ConsumerState<TurnActionPanel> createState() => _TurnActionPanelState();
}

class _TurnActionPanelState extends ConsumerState<TurnActionPanel> {
  int _secondsRemaining = 15;
  Timer? _timer;
  String? _lastTurnPlayerId;
  bool _lastHasRolled = false;

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 15;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _onTimerEnd();
          }
        });
      }
    });
  }

  void _onTimerEnd() {
    final gameState = ref.read(gameStateProvider);
    final networkState = ref.read(networkProvider);
    if (gameState.currentPlayerId != networkState.myPlayerId) return;

    if (!gameState.hasRolled) {
      ref.read(networkProvider.notifier).rollDice();
    } else {
      ref.read(networkProvider.notifier).endTurn();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final networkState = ref.watch(networkProvider);

    final myPlayerIndex = gameState.players.indexWhere((p) => p.id == networkState.myPlayerId);
    if (myPlayerIndex == -1) return const SizedBox.shrink();
    final myPlayer = gameState.players[myPlayerIndex];

    // Reset timer when turn changes or after roll
    if (_lastTurnPlayerId != gameState.currentPlayerId || _lastHasRolled != gameState.hasRolled) {
      _lastTurnPlayerId = gameState.currentPlayerId;
      _lastHasRolled = gameState.hasRolled;
      if (gameState.currentPlayerId == networkState.myPlayerId && gameState.phase == GamePhase.playing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
      } else {
        _timer?.cancel();
      }
    }

    return GlassCard(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 5,
                      width: constraints.maxWidth * (_secondsRemaining / 15),
                      decoration: BoxDecoration(
                        gradient: _secondsRemaining > 5 
                            ? AppGradients.successGradient 
                            : AppGradients.dangerGradient,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: _secondsRemaining > 5 ? AppColors.accentGreen : AppColors.accentRed,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_secondsRemaining}s',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _secondsRemaining > 5 ? AppColors.textSecondary : AppColors.accentRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!gameState.hasRolled) ...[
            if (myPlayer.isJailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GradientButton(
                  text: 'PAY BAIL (₹150)',
                  icon: Icons.lock_open,
                  small: true,
                  gradient: LinearGradient(
                    colors: [AppColors.jailOrange, AppColors.accentOrange],
                  ),
                  onPressed: myPlayer.balance >= 150
                      ? () => ref.read(networkProvider.notifier).payBail()
                      : null,
                ),
              ),
            ScaleTransition(
              scale: widget.pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
              child: GradientButton(
                text: 'ROLL DICE',
                icon: Icons.casino,
                gradient: AppGradients.primaryGradient,
                onPressed: () => ref.read(networkProvider.notifier).rollDice(),
              ),
            ),
          ] else if (gameState.phase == GamePhase.auction) ...[
            // #7d: Auction phase UI
            Builder(builder: (context) {
              final auctionIdx = gameState.auctionPropertyIndex;
              if (auctionIdx == null) return const SizedBox.shrink();
              
              final propData = monopolyBoard.firstWhere((s) => s.index == auctionIdx);
              final currentHighest = gameState.auctionBids.values.isEmpty 
                  ? 0 
                  : gameState.auctionBids.values.reduce((a, b) => a > b ? a : b);
              final isMyBidTurn = gameState.auctionCurrentBidderId == networkState.myPlayerId;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('🔨 AUCTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.amber)),
                        const SizedBox(height: 4),
                        Text(propData.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Current bid: ₹$currentHighest', style: TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (isMyBidTurn) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            text: 'BID ₹${currentHighest + 10}',
                            icon: Icons.gavel,
                            gradient: AppGradients.successGradient,
                            small: true,
                            onPressed: myPlayer.balance >= currentHighest + 10
                                ? () => ref.read(networkProvider.notifier).processAuctionBid(
                                    networkState.myPlayerId!, currentHighest + 10)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GradientButton(
                            text: 'PASS',
                            icon: Icons.close,
                            gradient: AppGradients.dangerGradient,
                            small: true,
                            onPressed: () => ref.read(networkProvider.notifier).processAuctionPass(
                                networkState.myPlayerId!),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Center(child: Text('Waiting for bid...', style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic, fontSize: 12))),
                  ],
                ],
              );
            }),
          ] else ...[
            Builder(builder: (context) {
              final currentPos = myPlayer.position;
              final propertyData = monopolyBoard.firstWhere(
                (e) => e.index == currentPos,
                orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
              );

              final isBuyable = propertyData.isBuyable;
              final isUnowned = !gameState.propertyOwners.containsKey(currentPos);
              final canAfford = myPlayer.balance >= (propertyData.price ?? 0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isBuyable && isUnowned) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton.success(
                            text: 'BUY (₹${propertyData.price})',
                            icon: Icons.add_home,
                            small: true,
                            onPressed: canAfford
                                ? () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1A1A2E),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Text('Buy ${propertyData.name}?', style: const TextStyle(color: Colors.white)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Price: ₹${propertyData.price}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text('Balance after: ₹${myPlayer.balance - (propertyData.price ?? 0)}', style: TextStyle(color: (myPlayer.balance - (propertyData.price ?? 0)) > 100 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Buy'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      ref.read(networkProvider.notifier).buyProperty();
                                      ref.read(networkProvider.notifier).endTurn();
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // #7d: Decline → triggers auction
                        Expanded(
                          child: GradientButton(
                            text: 'AUCTION',
                            icon: Icons.gavel,
                            gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange]),
                            small: true,
                            onPressed: () => ref.read(networkProvider.notifier).startAuction(currentPos),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // #7c: Build house button if player owns a complete color group
                    Builder(builder: (_) {
                      // Find properties where player can build
                      final myId = networkState.myPlayerId;
                      final buildableProps = monopolyBoard.where((space) {
                        if (space.type != BoardSpaceType.property) return false;
                        if (gameState.propertyOwners[space.index] != myId) return false;
                        if (space.houseCost == null) return false;
                        final houses = gameState.propertyHouses[space.index] ?? 0;
                        if (houses >= 5) return false;
                        // Must own all in color group
                        final sameColor = monopolyBoard.where((s) => s.colorHex == space.colorHex);
                        final ownsAll = sameColor.every((s) => gameState.propertyOwners[s.index] == myId);
                        if (!ownsAll) return false;
                        // Even-build check
                        final minH = sameColor.map((s) => gameState.propertyHouses[s.index] ?? 0).reduce((a, b) => a < b ? a : b);
                        return houses <= minH;
                      }).toList();

                      if (buildableProps.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GradientButton(
                            text: 'BUILD HOUSE (${buildableProps.length} available)',
                            icon: Icons.house,
                            gradient: LinearGradient(colors: [Colors.teal, Colors.tealAccent.shade700]),
                            small: true,
                            onPressed: () {
                              // Build on the first available (cheapest)
                              final target = buildableProps.first;
                              ref.read(networkProvider.notifier).processBuildHouse(myId!, target.index);
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    GradientButton(
                      text: gameState.canRollAgain ? 'ROLL AGAIN' : 'END TURN',
                      icon: gameState.canRollAgain ? Icons.casino : Icons.skip_next,
                      gradient: gameState.canRollAgain ? AppGradients.primaryGradient : LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700]),
                      small: true,
                      onPressed: () => ref.read(networkProvider.notifier).endTurn(),
                    ),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
