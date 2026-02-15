import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_blr/features/game/domain/models/board_data.dart';
import 'package:monopoly_blr/features/game/domain/models/game_state.dart';
import 'package:monopoly_blr/features/game/domain/models/player.dart';
import 'package:monopoly_blr/features/game/domain/models/trade_offer.dart';

/// #17: Expanded test coverage for core models and game logic
void main() {
  // --- Board Data tests ---
  group('BoardSpaceData', () {
    test('getRentForHouses returns correct rent multipliers', () {
      // MG Road: baseRent=4, houseCost=50
      final mgRoad = monopolyBoard.firstWhere((s) => s.name == 'MG Road');
      expect(mgRoad.getRentForHouses(0), mgRoad.baseRent); // base rent
      expect(mgRoad.getRentForHouses(1), mgRoad.baseRent! * 5);
      expect(mgRoad.getRentForHouses(2), mgRoad.baseRent! * 15);
      expect(mgRoad.getRentForHouses(3), mgRoad.baseRent! * 30);
      expect(mgRoad.getRentForHouses(4), mgRoad.baseRent! * 40);
      expect(mgRoad.getRentForHouses(5), mgRoad.baseRent! * 60); // hotel
    });

    test('isBuyable returns true only for properties, railroads, utilities', () {
      for (final space in monopolyBoard) {
        if (space.type == BoardSpaceType.property ||
            space.type == BoardSpaceType.railroad ||
            space.type == BoardSpaceType.utility) {
          expect(space.isBuyable, isTrue, reason: '${space.name} should be buyable');
        } else {
          expect(space.isBuyable, isFalse, reason: '${space.name} should NOT be buyable');
        }
      }
    });

    test('all buyable properties have a price', () {
      for (final space in monopolyBoard.where((s) => s.isBuyable)) {
        expect(space.price, isNotNull, reason: '${space.name} should have a price');
        expect(space.price!, greaterThan(0));
      }
    });

    test('all properties have houseCost', () {
      for (final space in monopolyBoard.where((s) => s.type == BoardSpaceType.property)) {
        expect(space.houseCost, isNotNull, reason: '${space.name} should have houseCost');
        expect(space.houseCost!, greaterThan(0));
      }
    });

    test('board has exactly 28 spaces', () {
      expect(monopolyBoard.length, 28);
    });

    test('board indices are 0-27', () {
      for (int i = 0; i < 28; i++) {
        expect(monopolyBoard.any((s) => s.index == i), isTrue, reason: 'Index $i missing');
      }
    });
  });

  // --- GameState tests ---
  group('GameState', () {
    test('copyWith preserves unmodified fields', () {
      const state = GameState(
        players: [],
        currentPlayerId: 'p1',
        phase: GamePhase.playing,
        hasRolled: false,
        turnCount: 5,
      );

      final copied = state.copyWith(hasRolled: true);
      expect(copied.currentPlayerId, 'p1');
      expect(copied.phase, GamePhase.playing);
      expect(copied.hasRolled, isTrue);
      expect(copied.turnCount, 5);
    });

    test('new GameState has no pending trade', () {
      const state = GameState();
      expect(state.pendingTradeOffer, isNull);
      expect(state.turnCount, 0);
    });

    test('toJson/fromJson round-trip', () {
      final state = GameState(
        players: [
          Player(id: 'p1', name: 'Test', balance: 1500, position: 0, colorHex: '#FF0000'),
        ],
        currentPlayerId: 'p1',
        phase: GamePhase.playing,
        turnCount: 10,
        propertyOwners: {1: 'p1', 3: 'p1'},
        propertyHouses: {1: 2},
      );
      final json = state.toJson();
      final restored = GameState.fromJson(json);
      expect(restored.currentPlayerId, 'p1');
      expect(restored.turnCount, 10);
      expect(restored.propertyOwners[1], 'p1');
      expect(restored.propertyHouses[1], 2);
      expect(restored.players.length, 1);
      expect(restored.players[0].name, 'Test');
    });

    test('GamePhase enum includes auction', () {
      expect(GamePhase.values, contains(GamePhase.auction));
      expect(GamePhase.values, contains(GamePhase.ended));
      expect(GamePhase.values, contains(GamePhase.playing));
    });
  });

  // --- Player tests ---
  group('Player', () {
    test('copyWith updates balance correctly', () {
      const player = Player(id: 'p1', name: 'Alice', balance: 1500, position: 0, colorHex: '#FF0000');
      final updated = player.copyWith(balance: 1200);
      expect(updated.balance, 1200);
      expect(updated.name, 'Alice');
      expect(updated.position, 0);
    });

    test('jail state defaults to false', () {
      const player = Player(id: 'p1', name: 'Bob', balance: 1500, position: 0, colorHex: '#00FF00');
      expect(player.isJailed, isFalse);
      expect(player.jailTurns, 0);
    });

    test('toJson/fromJson round-trip', () {
      const player = Player(
        id: 'p1', name: 'Charlie', balance: 800, position: 7,
        colorHex: '#0000FF', isJailed: true, jailTurns: 2,
      );
      final json = player.toJson();
      final restored = Player.fromJson(json);
      expect(restored.name, 'Charlie');
      expect(restored.balance, 800);
      expect(restored.isJailed, isTrue);
      expect(restored.jailTurns, 2);
    });
  });

  // --- TradeOffer tests ---
  group('TradeOffer', () {
    test('toJson/fromJson round-trip', () {
      const offer = TradeOffer(
        fromPlayerId: 'p1',
        toPlayerId: 'p2',
        offeredPropertyIndices: [1, 3],
        requestedPropertyIndices: [5],
        cashOffer: 100,
      );
      final json = offer.toJson();
      final restored = TradeOffer.fromJson(json);
      expect(restored.fromPlayerId, 'p1');
      expect(restored.toPlayerId, 'p2');
      expect(restored.offeredPropertyIndices, [1, 3]);
      expect(restored.requestedPropertyIndices, [5]);
      expect(restored.cashOffer, 100);
    });

    test('equality works', () {
      const offer1 = TradeOffer(fromPlayerId: 'p1', toPlayerId: 'p2', cashOffer: 50);
      const offer2 = TradeOffer(fromPlayerId: 'p1', toPlayerId: 'p2', cashOffer: 50);
      const offer3 = TradeOffer(fromPlayerId: 'p1', toPlayerId: 'p2', cashOffer: 100);
      expect(offer1, equals(offer2));
      expect(offer1, isNot(equals(offer3)));
    });

    test('defaults to empty lists', () {
      const offer = TradeOffer(fromPlayerId: 'p1', toPlayerId: 'p2');
      expect(offer.offeredPropertyIndices, isEmpty);
      expect(offer.requestedPropertyIndices, isEmpty);
      expect(offer.cashOffer, 0);
    });
  });

  // --- Color group logic ---
  group('Color Groups', () {
    test('each color group has 2-3 properties', () {
      final colorGroups = <String, int>{};
      for (final space in monopolyBoard.where((s) => s.colorHex != null)) {
        colorGroups[space.colorHex!] = (colorGroups[space.colorHex!] ?? 0) + 1;
      }
      for (final entry in colorGroups.entries) {
        expect(entry.value, greaterThanOrEqualTo(1), reason: 'Color ${entry.key} has too few properties');
        expect(entry.value, lessThanOrEqualTo(3), reason: 'Color ${entry.key} has too many properties');
      }
    });

    test('railroads exist and are buyable', () {
      final railroads = monopolyBoard.where((s) => s.type == BoardSpaceType.railroad).toList();
      expect(railroads, isNotEmpty);
      for (final rr in railroads) {
        expect(rr.isBuyable, isTrue);
        expect(rr.price, isNotNull);
      }
    });

    test('utility exists and is buyable', () {
      final utilities = monopolyBoard.where((s) => s.type == BoardSpaceType.utility).toList();
      expect(utilities, isNotEmpty);
      for (final u in utilities) {
        expect(u.isBuyable, isTrue);
        expect(u.price, isNotNull);
      }
    });
  });
}
