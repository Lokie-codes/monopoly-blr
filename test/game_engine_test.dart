
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_blr/features/game/domain/models/game_state.dart';
import 'package:monopoly_blr/features/game/domain/models/player.dart';
import 'package:monopoly_blr/features/game/logic/game_engine.dart';
import 'package:monopoly_blr/features/game/domain/models/board_data.dart'; // For monopolyBoard

void main() {
  group('GameEngine Tests', () {
    late GameEngine engine;
    late GameState gameState;
    final List<String> chatMessages = [];

    setUp(() {
      gameState = const GameState(
        players: [
          Player(id: 'p1', name: 'Player 1', balance: 1500, position: 0),
          Player(id: 'p2', name: 'Player 2', balance: 1500, position: 0),
        ],
        currentPlayerId: 'p1',
        phase: GamePhase.playing,
      );
      chatMessages.clear();

      engine = GameEngine(
        onStateChanged: (newState) => gameState = newState,
        onChatAction: (msg) => chatMessages.add(msg),
        getState: () => gameState,
      );
    });

    test('Rolling dice updates state pendingDiceRoll', () {
      engine.processRollDiceForPlayer('p1');
      expect(gameState.pendingDiceRoll, isNotEmpty);
      expect(gameState.isAnimatingDice, isTrue);
      expect(chatMessages, contains(startsWith('Player 1 rolled')));
    });

    test('Applying dice result moves player', () {
      // Manually set pending roll to control test
      gameState = gameState.copyWith(
        pendingDiceRoll: [5], // Roll a 5
        isAnimatingDice: true,
      );

      bool timerStarted = false;
      bool timerCancelled = false;

      engine.applyDiceResult(
        onStartTurnTimer: () => timerStarted = true,
        onCancelTurnTimer: () => timerCancelled = true,
      );

      final p1 = gameState.players.first;
      expect(p1.position, 5); // Should be at index 5 (Reading Road / "Indiranagar Metro")
      expect(gameState.pendingDiceRoll, isEmpty);
      expect(gameState.isAnimatingDice, isFalse);
    });

    test('Passing Go adds 200', () {
      // Position at 26 (Park Lane / "UB City"), roll 4 -> lands on 2 (Community Chest / "Koramangala")
      // Board size is 28. 26 + 4 = 30. 30 % 28 = 2.
      // Wait, board size is 28... 0..27.
      
      gameState = gameState.copyWith(
        players: [
           gameState.players[0].copyWith(position: 27), // Last square
           gameState.players[1],
        ]
      );
      
      gameState = gameState.copyWith(pendingDiceRoll: [2]); // Roll 2 -> 29 -> index 1

      engine.applyDiceResult(
        onStartTurnTimer: () {},
        onCancelTurnTimer: () {},
      );

      final p1 = gameState.players.first;
      expect(p1.position, 1);
      expect(p1.balance, 1700); // 1500 + 200
      expect(chatMessages.any((msg) => msg.contains('passed GO')), isTrue);
    });

    test('Buying property deducts balance and updates owner', () {
      // Place p1 on a buyable property (e.g., index 1 "Old Airport Road" prices 60)
      // Prices are from board_data.dart. Let's assume index 1 is valid and unowned.
      
      final propertyIdx = 1;
      gameState = gameState.copyWith(
        players: [gameState.players[0].copyWith(position: propertyIdx)],
      );

      // Verify unowned
      expect(gameState.propertyOwners.containsKey(propertyIdx), isFalse);

      engine.processBuyProperty('p1', propertyIdx);

      expect(gameState.propertyOwners[propertyIdx], 'p1');
      expect(gameState.players[0].balance, lessThan(1500)); // Should have paid
    });

    test('Rent is paid when landing on owned property', () {
      // p1 owns index 1.
      gameState = gameState.copyWith(
        propertyOwners: {1: 'p1'},
      );
      
      // p2 lands on index 1
      gameState = gameState.copyWith(
        currentPlayerId: 'p2',
        players: [
          gameState.players[0],
          gameState.players[1].copyWith(position: 0),
        ],
        pendingDiceRoll: [1], // Roll 1 -> moves to index 1
      );

      engine.applyDiceResult(
        onStartTurnTimer: () {},
        onCancelTurnTimer: () {},
      );

      final p1 = gameState.players.firstWhere((p) => p.id == 'p1');
      final p2 = gameState.players.firstWhere((p) => p.id == 'p2');

      expect(p2.balance, lessThan(1500)); // Paid rent
      expect(p1.balance, greaterThan(1500)); // Received rent
      expect(chatMessages.any((msg) => msg.contains('paid')), isTrue);
    });

    test('Go To Jail moves player to index 7', () {
      // Position at index 20, roll 1 -> 21 (Go To Jail)
      gameState = gameState.copyWith(
        players: [ gameState.players[0].copyWith(position: 20)],
        pendingDiceRoll: [1],
      );

      engine.applyDiceResult(
        onStartTurnTimer: () {},
        onCancelTurnTimer: () {},
      );

      final p1 = gameState.players.first;
      expect(p1.position, 7); // Jail
      expect(p1.isJailed, isTrue);
    });
  });
}
