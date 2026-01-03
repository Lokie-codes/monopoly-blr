import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/board_data.dart';
import 'game_provider.dart';

class SimulationResult {
  final bool success;
  final String? error;
  final List<String> logs;
  final List<String> flaws;
  final int totalTurns;
  final GameState finalState;

  SimulationResult({
    required this.success,
    this.error,
    required this.logs,
    required this.flaws,
    required this.totalTurns,
    required this.finalState,
  });
}

class GameSimulator {
  final List<String> _logs = [];
  final List<String> _flaws = [];
  
  void _log(String message) {
    _logs.add(message);
    print(message);
  }

  void _addFlaw(String flaw) {
    final msg = "!!! FLAW DETECTED: $flaw";
    _flaws.add(msg);
    _log(msg);
  }

  Future<SimulationResult> runSimulation({
    int maxTurns = 1000,
    int numberOfPlayers = 4,
    int initialBalance = 1500,
  }) async {
    final container = ProviderContainer();
    final gameNotifier = container.read(gameStateProvider.notifier);
    final networkNotifier = container.read(networkProvider.notifier);

    // 1. Initial Setup
    final players = List.generate(numberOfPlayers, (i) => Player(
      id: 'P$i',
      name: 'Bot $i',
      balance: 1000, // Updated to 1000
      colorHex: '#${Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    ));

    var currentState = GameState(
      players: players,
      currentPlayerId: players[0].id,
      phase: GamePhase.playing,
    );

    gameNotifier.updateState(currentState);
    _log("Simulation started with $numberOfPlayers players.");

    int turnCount = 0;
    while (turnCount < maxTurns && currentState.phase != GamePhase.ended) {
      turnCount++;
      
      final currentPlayerId = currentState.currentPlayerId;
      if (currentPlayerId == null) {
        _addFlaw("Current player ID is null at turn $turnCount");
        break;
      }

      final playerIndex = currentState.players.indexWhere((p) => p.id == currentPlayerId);
      if (playerIndex == -1) {
        _addFlaw("Current player $currentPlayerId not found in players list at turn $turnCount");
        // This is a critical logic error if it happens
        break;
      }

      final player = currentState.players[playerIndex];
      final currentSpace = monopolyBoard.firstWhere((s) => s.index == player.position);
      _log("\n[Turn $turnCount] ${player.name} at ${currentSpace.name} (Bal: ${player.balance})");

      // Check Invariants BEFORE move
      _checkInvariants(currentState, "Pre-Roll");

      // 2. Roll Dice
      networkNotifier.processRollDiceForPlayer(currentPlayerId);
      
      // The processRollDiceForPlayer just sets isAnimatingDice and pendingDiceRoll.
      // We need to call applyDiceResult to actually move.
      networkNotifier.applyDiceResult();
      
      currentState = container.read(gameStateProvider);
      final postMovePlayer = currentState.players.firstWhere((p) => p.id == currentPlayerId, orElse: () => player);
      
      if (currentState.players.length < players.length && !(currentState.notificationMessage?.contains('ELIMINATED') ?? false)) {
         // If player count dropped but notification didn't mention elimination
      }

      final postMoveSpace = monopolyBoard.firstWhere((s) => s.index == postMovePlayer.position);
      _log("Moved to ${postMoveSpace.name}. New Balance: ${postMovePlayer.balance}");

      // 3. Simple AI: Buy if unowned and affordable
      if (currentState.phase != GamePhase.ended && currentState.players.any((p) => p.id == currentPlayerId)) {
        final pos = postMovePlayer.position;
        final property = monopolyBoard.firstWhere((s) => s.index == pos);
        final isBuyable = ['Property', 'Railroad', 'Utility'].contains(property.type);
        final isUnowned = !currentState.propertyOwners.containsKey(pos);
        
        if (isBuyable && isUnowned && postMovePlayer.balance >= (property.price ?? 0)) {
           _log("Bot buying ${property.name} for ${property.price}");
           networkNotifier.processBuyProperty(currentPlayerId, pos);
           currentState = container.read(gameStateProvider);
        }
      }

      // 4. End Turn (Note: applyDiceResult might have already called processEndTurn if it auto-ended)
      if (container.read(gameStateProvider).currentPlayerId == currentPlayerId) {
          networkNotifier.processEndTurn(currentPlayerId);
      }

      currentState = container.read(gameStateProvider);
      
      // Check Invariants AFTER turn
      _checkInvariants(currentState, "Post-Turn");

      if (currentState.players.length <= 1 && currentState.phase != GamePhase.ended) {
         _addFlaw("Only ${currentState.players.length} player(s) left but game phase is not 'ended'");
      }
    }

    _log("\nSimulation finished after $turnCount turns.");
    if (currentState.phase == GamePhase.ended) {
      _log("Game Ended Normally. Winner: ${currentState.players.isNotEmpty ? currentState.players.first.name : 'None'}");
    } else {
      _log("Simulation reached max turns ($maxTurns).");
    }

    return SimulationResult(
      success: _flaws.isEmpty,
      logs: _logs,
      flaws: _flaws,
      totalTurns: turnCount,
      finalState: currentState,
    );
  }

  void _checkInvariants(GameState state, String stage) {
    // 1. Position range
    for (var p in state.players) {
      if (p.position < 0 || p.position >= 28) {
        _addFlaw("$stage: Player ${p.name} at invalid position ${p.position}");
      }
    }

    // 2. Ownership validity
    state.propertyOwners.forEach((index, ownerId) {
      if (!state.players.any((p) => p.id == ownerId)) {
        _addFlaw("$stage: Property at $index owned by non-existent player $ownerId");
      }
    });

    // 3. Positive Balance (mostly)
    for (var p in state.players) {
      if (p.balance < -1000) {
        _addFlaw("$stage: Player ${p.name} has deeply negative balance (${p.balance}) without being eliminated.");
      }
    }

    // 4. Unique IDs
    final ids = state.players.map((p) => p.id).toSet();
    if (ids.length != state.players.length) {
      _addFlaw("$stage: Duplicate player IDs detected.");
    }
  }
}
