import 'package:monopoly_blr/features/game/logic/game_simulator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monopoly_blr/features/game/domain/models/player.dart';
import 'package:monopoly_blr/features/game/domain/models/game_state.dart';
import 'package:monopoly_blr/features/game/logic/game_provider.dart';
import 'package:test/test.dart';

void main() {
  test('Run Stress Test Simulation', () async {
      final simulator = GameSimulator();
      final result = await simulator.runSimulation(maxTurns: 5000, numberOfPlayers: 6);
      
      print("\n--- SIMULATION SUMMARY ---");
      print("Total Turns: ${result.totalTurns}");
      print("Flaws Found: ${result.flaws.length}");
      
      if (result.flaws.isNotEmpty) {
          print("\nFLAWS:");
          for (var flaw in result.flaws) {
              print(flaw);
          }
      }
      
      expect(result.flaws, isEmpty, reason: "Game logic flaws were detected during simulation.");
  });

  test('Test Player Elimination Flaw', () async {
      final simulator = GameSimulator();
      // Setup a scenario where P1 is about to land on P0's expensive property with no money
      final container = ProviderContainer();
      final gameNotifier = container.read(gameStateProvider.notifier);
      final networkNotifier = container.read(networkProvider.notifier);

      final p0 = Player(id: 'P0', name: 'Rich Bot', balance: 5000, position: 0);
      final p1 = Player(id: 'P1', name: 'Poor Bot', balance: -480, position: 26); // UB City is at 27

      gameNotifier.updateState(GameState(
          players: [p0, p1],
          currentPlayerId: 'P1',
          propertyOwners: {27: 'P0'},
          phase: GamePhase.playing
      ));

      print("Starting Elimination Test...");
      // P1 rolls a 1 to land on UB City (index 27)
      // We can't easily force dice roll in the current API without mocking Random, 
      // but we can manually set the pendingDiceRoll.
      
      gameNotifier.updateState(container.read(gameStateProvider).copyWith(
          pendingDiceRoll: [1],
          isAnimatingDice: true
      ));

      networkNotifier.applyDiceResult();

      final state = container.read(gameStateProvider);
      print("State after landing on UB City: Phase=${state.phase}, Players=${state.players.length}");
      print("Current Player ID: ${state.currentPlayerId}");

      if (state.players.length == 1) {
          print("P1 was eliminated. Remaining player: ${state.players.first.name}");
          if (state.currentPlayerId == 'P1') {
              print("!!! FLAW: Current player is still P1 even though they were eliminated!");
          }
      }

      expect(state.players.length, 1, reason: "P1 should have been eliminated");
      expect(state.currentPlayerId, isNot('P1'), reason: "Current player should have changed after elimination");
  });

  test('Test Go To Jail Scenario', () async {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameStateProvider.notifier);
      final networkNotifier = container.read(networkProvider.notifier);

      final p0 = Player(id: 'P0', name: 'Bot 0', balance: 1500, position: 15); // Landing on 21 (Go To Jail) from 15 with roll of 6

      gameNotifier.updateState(GameState(
          players: [p0],
          currentPlayerId: 'P0',
          phase: GamePhase.playing
      ));

      gameNotifier.updateState(container.read(gameStateProvider).copyWith(
          pendingDiceRoll: [6], // 15 + 6 = 21 (Go To Jail)
          isAnimatingDice: true
      ));

      networkNotifier.applyDiceResult();

      final state = container.read(gameStateProvider);
      final player = state.players.firstWhere((p) => p.id == 'P0');
      
      print("Go To Jail Test: Position=${player.position}, IsJailed=${player.isJailed}");
      
      expect(player.position, 7, reason: "Player should be at Jail position (7)");
      expect(player.isJailed, isTrue, reason: "Player should be marked as jailed");
  });

  test('Test Card Advance To Scenario', () async {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameStateProvider.notifier);
      final networkNotifier = container.read(networkProvider.notifier);

      // Community Chest at index 12
      final p0 = Player(id: 'P0', name: 'Bot 0', balance: 1500, position: 10);

      gameNotifier.updateState(GameState(
          players: [p0],
          currentPlayerId: 'P0',
          phase: GamePhase.playing
      ));

      // We need to 'rig' the random to pick a specific card.
      // Since it uses Random().nextInt(cards.length), we can't easily rig it without mocking.
      // But we can check if it at least stays valid.
      
      gameNotifier.updateState(container.read(gameStateProvider).copyWith(
          pendingDiceRoll: [2], // 10 + 2 = 12 (Community Chest)
          isAnimatingDice: true
      ));

      networkNotifier.applyDiceResult();

      final state = container.read(gameStateProvider);
      final player = state.players.firstWhere((p) => p.id == 'P0');
      
      print("Card Test: Position=${player.position}, Balance=${player.balance}");
      // The output will vary based on random card, but it should not crash.
  });

  test('Test Jail Escape Scenario', () async {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameStateProvider.notifier);
      final networkNotifier = container.read(networkProvider.notifier);

      final p0 = Player(id: 'P0', name: 'Bot 0', balance: 1500, position: 7, isJailed: true);

      gameNotifier.updateState(GameState(
          players: [p0],
          currentPlayerId: 'P0',
          phase: GamePhase.playing
      ));

      // 1. Roll NOT 6
      gameNotifier.updateState(container.read(gameStateProvider).copyWith(
          pendingDiceRoll: [3],
          isAnimatingDice: true
      ));
      networkNotifier.applyDiceResult();

      var state = container.read(gameStateProvider);
      var player = state.players.firstWhere((p) => p.id == 'P0');
      print("Jail Escape (Rolled 3): Position=${player.position}, IsJailed=${player.isJailed}");
      expect(player.isJailed, isTrue, reason: "Player should still be jailed after rolling 3");

      // 2. Roll 6
      gameNotifier.updateState(container.read(gameStateProvider).copyWith(
          pendingDiceRoll: [6],
          isAnimatingDice: true,
          hasRolled: false // Reset hasRolled for this mock turn
      ));
      networkNotifier.applyDiceResult();

      state = container.read(gameStateProvider);
      player = state.players.firstWhere((p) => p.id == 'P0');
      print("Jail Escape (Rolled 6): Position=${player.position}, IsJailed=${player.isJailed}");
      // Note: In current logic, rolling 6 in jail escapes AND moves? 
      // Let's check: 7 + 6 = 13
      expect(player.isJailed, isFalse, reason: "Player should be free after rolling 6");
      expect(player.position, 13, reason: "Player should have moved to 13");
  });
}
