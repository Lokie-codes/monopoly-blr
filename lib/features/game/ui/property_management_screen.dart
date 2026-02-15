import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/board_data.dart';
import '../domain/models/game_state.dart';
import '../logic/game_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

/// #21: Property management screen — view owned properties, build houses, sell houses
class PropertyManagementScreen extends ConsumerWidget {
  const PropertyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final networkState = ref.watch(networkProvider);
    final myId = networkState.myPlayerId;

    if (myId == null) return const Scaffold(body: Center(child: Text('No player ID')));

    final myProperties = monopolyBoard.where((s) =>
        gameState.propertyOwners[s.index] == myId && s.isBuyable).toList()
      ..sort((a, b) => (a.colorHex ?? '').compareTo(b.colorHex ?? ''));

    final totalPropertyValue = myProperties.fold<int>(0, (sum, p) => sum + (p.price ?? 0));
    final totalHouseValue = myProperties.fold<int>(0, (sum, p) {
      final houses = gameState.propertyHouses[p.index] ?? 0;
      return sum + houses * (p.houseCost ?? 0);
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Properties', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppGradients.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('Properties', '${myProperties.length}'),
                _statCol('Value', '₹$totalPropertyValue'),
                _statCol('Houses', '₹$totalHouseValue'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Property list
          Expanded(
            child: myProperties.isEmpty
                ? const Center(child: Text('You don\'t own any properties yet.', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: myProperties.length,
                    itemBuilder: (context, index) {
                      final prop = myProperties[index];
                      final houses = gameState.propertyHouses[prop.index] ?? 0;
                      final currentRent = prop.getRentForHouses(houses);
                      final color = prop.colorHex != null
                          ? Color(int.parse(prop.colorHex!.replaceFirst('#', '0xff')))
                          : Colors.grey;

                      // Check if player can build on this property
                      final sameColor = monopolyBoard.where((s) => s.colorHex == prop.colorHex);
                      final ownsAll = sameColor.every((s) => gameState.propertyOwners[s.index] == myId);
                      final minH = ownsAll ? sameColor.map((s) => gameState.propertyHouses[s.index] ?? 0).reduce((a, b) => a < b ? a : b) : 0;
                      final canBuild = ownsAll && houses < 5 && houses <= minH && prop.houseCost != null;
                      final maxH = ownsAll ? sameColor.map((s) => gameState.propertyHouses[s.index] ?? 0).reduce((a, b) => a > b ? a : b) : 0;
                      final canSell = houses > 0 && houses >= maxH;

                      final myPlayer = gameState.players.firstWhere((p) => p.id == myId);

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(prop.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                                Text('₹${prop.price}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // House indicators
                                if (houses > 0 && houses < 5)
                                  Row(
                                    children: List.generate(houses, (_) => const Padding(
                                      padding: EdgeInsets.only(right: 2),
                                      child: Icon(Icons.house, color: Colors.green, size: 16),
                                    )),
                                  ),
                                if (houses == 5)
                                  const Row(children: [
                                    Icon(Icons.apartment, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 4),
                                    Text('HOTEL', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ]),
                                const Spacer(),
                                Text('Rent: ₹$currentRent', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (ownsAll && prop.houseCost != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (canBuild)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 6),
                                        ),
                                        onPressed: myPlayer.balance >= prop.houseCost!
                                            ? () => ref.read(networkProvider.notifier).processBuildHouse(myId, prop.index)
                                            : null,
                                        icon: Icon(houses < 4 ? Icons.house : Icons.apartment, size: 14),
                                        label: Text(
                                          houses < 4 ? 'Build (₹${prop.houseCost})' : 'Hotel (₹${prop.houseCost})',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  if (canBuild && canSell) const SizedBox(width: 8),
                                  if (canSell)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 6),
                                        ),
                                        onPressed: () => ref.read(networkProvider.notifier).processSellHouse(myId, prop.index),
                                        icon: const Icon(Icons.sell, size: 14),
                                        label: Text('Sell (+₹${prop.houseCost! ~/ 2})', style: const TextStyle(fontSize: 11)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
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

  Widget _statCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
