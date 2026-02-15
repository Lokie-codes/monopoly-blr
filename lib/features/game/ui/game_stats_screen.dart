import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/board_data.dart';
import '../domain/models/game_state.dart';
import '../logic/game_provider.dart';
import '../../../core/theme/app_theme.dart';

/// #25: Game statistics dashboard — shows live leaderboard, property distribution, and game progress
class GameStatsScreen extends ConsumerWidget {
  const GameStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final sortedPlayers = List.from(gameState.players)..sort((a, b) => b.balance.compareTo(a.balance));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Game Statistics', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game progress
            _sectionTitle('📊 Game Progress'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _statRow('Turn', '${gameState.turnCount} / 100'),
                  _statRow('Phase', gameState.phase.name.toUpperCase()),
                  _statRow('Properties Sold', '${gameState.propertyOwners.length} / ${monopolyBoard.where((s) => s.isBuyable).length}'),
                  _statRow('Houses Built', '${gameState.propertyHouses.values.where((h) => h > 0 && h < 5).fold<int>(0, (s, h) => s + h)}'),
                  _statRow('Hotels Built', '${gameState.propertyHouses.values.where((h) => h == 5).length}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leaderboard
            _sectionTitle('🏆 Leaderboard'),
            ...sortedPlayers.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final player = entry.value;
              final color = Color(int.parse(player.colorHex.replaceFirst('#', '0xff')));
              final propertiesOwned = gameState.propertyOwners.values.where((id) => id == player.id).length;
              final totalAssets = player.balance + monopolyBoard
                  .where((s) => gameState.propertyOwners[s.index] == player.id)
                  .fold<int>(0, (sum, s) => sum + (s.price ?? 0) + (gameState.propertyHouses[s.index] ?? 0) * (s.houseCost ?? 0));

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: _cardDecoration(
                  borderColor: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey.shade400 : rank == 3 ? Colors.brown.shade300 : null,
                ),
                child: Row(
                  children: [
                    // Rank medal
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey.shade600 : rank == 3 ? Colors.brown : color.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 6, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${propertiesOwned} properties · ₹${player.balance} cash', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹$totalAssets', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700, fontSize: 14)),
                        const Text('net worth', style: TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Property distribution by color
            _sectionTitle('🎨 Property Distribution'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                children: _buildPropertyDistribution(gameState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPropertyDistribution(GameState gameState) {
    final colorGroups = <String, List<BoardSpaceData>>{};
    for (final space in monopolyBoard.where((s) => s.colorHex != null)) {
      colorGroups.putIfAbsent(space.colorHex!, () => []).add(space);
    }

    return colorGroups.entries.map((entry) {
      final color = Color(int.parse(entry.key.replaceFirst('#', '0xff')));
      final spaces = entry.value;
      final owners = <String, int>{};
      for (final s in spaces) {
        final ownerId = gameState.propertyOwners[s.index];
        if (ownerId != null) {
          owners[ownerId] = (owners[ownerId] ?? 0) + 1;
        }
      }
      final owned = owners.values.fold<int>(0, (s, v) => s + v);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: spaces.isEmpty ? 0 : owned / spaces.length,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$owned/${spaces.length}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      );
    }).toList();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.darkSurfaceLight,
      borderRadius: BorderRadius.circular(12),
      border: borderColor != null ? Border.all(color: borderColor.withOpacity(0.5)) : null,
    );
  }
}
