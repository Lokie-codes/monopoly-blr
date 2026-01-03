import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/game_provider.dart';
import '../domain/models/game_state.dart';
import 'game_board_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/animated_background.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController(text: "");
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    
    _logoController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('username');
    if (name == null || name.isEmpty || name.startsWith("Player ")) {
      name = _generateRandomName();
      await prefs.setString('username', name);
    }
    setState(() {
      _nameController.text = name!;
    });
  }

  String _generateRandomName() {
    final adjectives = ['Happy', 'Lucky', 'Rich', 'Speedy', 'Golden', 'Neon', 'Cosmic', 'Grand', 'Silent', 'Brave'];
    final nouns = ['Tycoon', 'Racer', 'Panda', 'Eagle', 'Banker', 'Wizard', 'Knight', 'Star', 'Wolf', 'Bear'];
    final random = Random();
    return "${adjectives[random.nextInt(adjectives.length)]} ${nouns[random.nextInt(nouns.length)]}";
  }

  Future<void> _saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkProvider);
    final gameState = ref.watch(gameStateProvider);
    final size = MediaQuery.of(context).size;

    // If game started, navigate to Board
    ref.listen(gameStateProvider, (previous, next) {
      if (next.phase == GamePhase.playing) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const GameBoardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  maxWidth: 600,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Logo Section
                      _buildLogo(),
                      const SizedBox(height: 40),
                      
                      if (!networkState.isConnected) ...[
                        // Name Input Section
                        _buildNameInput(),
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        _buildActionButtons(),
                        const SizedBox(height: 32),
                        
                        // Discovered Hosts
                        if (networkState.discoveredHosts.isNotEmpty || _isScanning)
                          _buildDiscoveredHosts(networkState),
                      ] else ...[
                        // Connected Lobby View
                        _buildConnectedLobby(networkState, gameState),
                      ],
                      
                      // Error Display
                      if (networkState.error != null)
                        _buildErrorCard(networkState.error!),
                        
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoAnimation,
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: AppShadows.glowShadow(AppColors.primaryGradientStart),
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => AppGradients.goldGradient.createShader(bounds),
            child: const Text(
              'MONOPOLY',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BANGALORE EDITION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glowShadow(AppColors.accentGreen),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LAN MULTIPLAYER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGreen,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Identity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                suffixIcon: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGradientStart.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: AppColors.primaryGradientStart,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _nameController.text = _generateRandomName();
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GradientButton(
            text: 'HOST GAME',
            icon: Icons.wifi_tethering,
            gradient: AppGradients.primaryGradient,
            onPressed: () async {
              await _saveUsername();
              ref.read(networkProvider.notifier).startHosting(_nameController.text);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GradientButton(
            text: 'JOIN GAME',
            icon: Icons.search,
            gradient: AppGradients.successGradient,
            onPressed: () {
              setState(() => _isScanning = true);
              ref.read(networkProvider.notifier).startScanning();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveredHosts(NetworkState networkState) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isScanning && networkState.discoveredHosts.isEmpty) ...[
                const SizedBox(
                  width: 20, 
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.accentBlue),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Scanning for games...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.successGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.router, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Found ${networkState.discoveredHosts.length} Game(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
          if (networkState.discoveredHosts.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...networkState.discoveredHosts.map((ip) => _buildHostTile(ip)),
          ],
        ],
      ),
    );
  }

  Widget _buildHostTile(String ip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.videogame_asset, color: Colors.white),
        ),
        title: const Text(
          'Monopoly Game',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          ip,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: GradientButton.success(
          text: 'JOIN',
          small: true,
          onPressed: () async {
            await _saveUsername();
            ref.read(networkProvider.notifier).connectToHost(ip, _nameController.text);
          },
        ),
      ),
    );
  }

  Widget _buildConnectedLobby(NetworkState networkState, GameState gameState) {
    return Column(
      children: [
        // Status Card
        GlassCard(
          padding: const EdgeInsets.all(24),
          gradient: networkState.isHost 
              ? LinearGradient(
                  colors: [
                    AppColors.accentGold.withOpacity(0.2),
                    AppColors.accentOrange.withOpacity(0.1),
                  ],
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: networkState.isHost 
                      ? AppGradients.goldGradient 
                      : AppGradients.successGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.glowShadow(
                    networkState.isHost ? AppColors.accentGold : AppColors.accentGreen
                  ),
                ),
                child: Icon(
                  networkState.isHost ? Icons.stars : Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      networkState.isHost ? 'You are the Host' : 'Connected to Host',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for players to join...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Players List
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Players',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGradientStart.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${gameState.players.length}/6',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGradientStart,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...gameState.players.asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final isMe = player.id == networkState.myPlayerId;
                final color = AppColors.playerColors[index % AppColors.playerColors.length];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? AppColors.primaryGradientStart.withOpacity(0.15)
                        : AppColors.darkSurfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMe 
                          ? AppColors.primaryGradientStart.withOpacity(0.3)
                          : AppColors.glassBorder,
                      width: isMe ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppShadows.glowShadow(color),
                        ),
                        child: Center(
                          child: Text(
                            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready to play',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        color: AppColors.accentGreen,
                        size: 24,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Start Game Button (Host Only)
        if (networkState.isHost)
          SizedBox(
            width: double.infinity,
            child: GradientButton.gold(
              text: 'START GAME',
              icon: Icons.play_arrow,
              onPressed: gameState.players.length >= 2
                  ? () => ref.read(networkProvider.notifier).startGame()
                  : null,
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.accentBlue),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Waiting for host to start...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
