import 'dart:math';
import '../domain/models/board_data.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/trade_offer.dart';

/// #12: Extracted game logic engine — pure state-in, state-out processing.
/// All side effects (broadcast, persistence, chat) are handled via callbacks.
class GameEngine {
  /// Called when game state changes (broadcast + persist + update UI)
  final void Function(GameState newState) onStateChanged;

  /// Called when a chat action message should be added
  final void Function(String message) onChatAction;

  /// Returns the current game state
  final GameState Function() getState;

  // #10: Shuffled card decks
  late final CardDeck _chanceDeck = CardDeck(chanceCards);
  late final CardDeck _communityDeck = CardDeck(communityChestCards);

  GameEngine({
    required this.onStateChanged,
    required this.onChatAction,
    required this.getState,
  });

  // ---------------------------------------------------------------------------
  // Dice
  // ---------------------------------------------------------------------------

  void processRollDiceForPlayer(String playerId) {
    final current = getState();
    if (current.currentPlayerId != playerId) return;

    final die1 = (Random().nextInt(6)) + 1;
    final player = current.players.firstWhere((p) => p.id == playerId, orElse: () => current.players.first);

    onChatAction('${player.name} rolled a $die1');

    // Phase 1: Start animation with pending dice roll (don't move pawn yet)
    final animationState = current.copyWith(
      pendingDiceRoll: [die1],
      isAnimatingDice: true,
    );
    onStateChanged(animationState);
  }

  // Called when dice animation completes
  void applyDiceResult({required void Function() onStartTurnTimer, required void Function() onCancelTurnTimer}) {
    final current = getState();
    if (current.pendingDiceRoll.isEmpty) return;

    final die1 = current.pendingDiceRoll.first;
    final total = die1;
    final playerId = current.currentPlayerId;
    if (playerId == null) return;

    final player = current.players.firstWhere((p) => p.id == playerId, orElse: () => current.players.first);

    // JAIL LOGIC: Pre-move (#9: 3-turn jail limit)
    if (player.isJailed) {
      final turnsInJail = player.jailTurns + 1;

      if (player.hasGetOutOfJailFreeCard) {
        onChatAction('${player.name} used Get Out of Jail Free card!');
      } else if (die1 == 6) {
        onChatAction('${player.name} escaped from jail!');
      } else if (turnsInJail >= 3) {
        final updatedPlayers = current.players.map((p) => p.id == playerId
            ? p.copyWith(balance: p.balance - 150, isJailed: false, jailTurns: 0)
            : p).toList();
        final newState = current.copyWith(
          players: updatedPlayers,
          lastDiceRoll: [die1],
          pendingDiceRoll: const [],
          isAnimatingDice: false,
          hasRolled: true,
          notificationMessage: "${player.name} forced to pay bail after 3 turns",
        );
        onChatAction('${player.name} spent 3 turns in jail, auto-paid bail');
        onStateChanged(newState);
        processEndTurn(playerId, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
        return;
      } else {
        final updatedPlayers = current.players.map((p) => p.id == playerId
            ? p.copyWith(jailTurns: turnsInJail)
            : p).toList();
        final newState = current.copyWith(
          players: updatedPlayers,
          lastDiceRoll: [die1],
          pendingDiceRoll: const [],
          isAnimatingDice: false,
          hasRolled: true,
          notificationMessage: "${player.name} stayed in Jail (Turn $turnsInJail/3)",
        );
        onStateChanged(newState);
        processEndTurn(playerId, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
        return;
      }
    }

    // Resolve any jail status change
    final playerForMove = player.isJailed ? player.copyWith(isJailed: false, jailTurns: 0, hasGetOutOfJailFreeCard: false) : player;

    int newPos = (playerForMove.position + total) % 28;

    // PASS GO Logic
    int newBalance = playerForMove.balance;
    String? passGoMessage;
    if (newPos < playerForMove.position) {
      newBalance += 200;
      passGoMessage = "${player.name} Passed Go! (+\$200)";
      onChatAction('${player.name} passed GO! Collected \$200');
    }

    // GO TO JAIL Logic
    bool justJailed = false;
    bool hasGetOutOfJailFreeCard = player.hasGetOutOfJailFreeCard;
    if (newPos == 21) {
      newPos = 7;
      justJailed = true;
      passGoMessage = "${player.name} sent to Jail!";
      onChatAction('${player.name} was sent to jail!');
    }

    // CARD SYSTEM LOGIC
    String? cardMessage;
    if (!justJailed) {
      final spaceData = monopolyBoard.firstWhere(
        (e) => e.index == newPos,
        orElse: () => BoardSpaceData(index: newPos, name: "Unknown", type: BoardSpaceType.corner),
      );
      final spaceType = spaceData.type;

      if (spaceType == BoardSpaceType.chance || spaceType == BoardSpaceType.communityChest) {
        final isChance = spaceType == BoardSpaceType.chance;
        final cards = isChance ? chanceCards : communityChestCards;
        if (cards.isNotEmpty) {
          final randomCard = isChance ? _chanceDeck.draw() : _communityDeck.draw();
          cardMessage = "Drew ${isChance ? 'Chance' : 'Community Chest'}: ${randomCard.text}";
          onChatAction(cardMessage);

          if (randomCard.actionId == 'money') {
            newBalance += (randomCard.value ?? 0);
          } else if (randomCard.actionId == 'go_to_jail') {
            newPos = 7;
            justJailed = true;
          } else if (randomCard.actionId == 'get_out_of_jail_free') {
            hasGetOutOfJailFreeCard = true;
          } else if (randomCard.actionId == 'advance_to') {
            int target = randomCard.value!;
            if (target < newPos) {
              newBalance += 200;
            }
            newPos = target;
          }
        }
      }
    }

    final updatedPlayer = playerForMove.copyWith(
      position: newPos,
      balance: newBalance,
      isJailed: justJailed,
      hasGetOutOfJailFreeCard: hasGetOutOfJailFreeCard,
    );
    final updatedPlayers = current.players.map((p) => p.id == playerId ? updatedPlayer : p).toList();

    final landedPropertyId = newPos;
    final ownerId = current.propertyOwners[landedPropertyId];

    List<Player> tempPlayers = List.from(updatedPlayers);
    String? systemMessage;

    // Rent/Property checks
    if (!justJailed && ownerId != null && ownerId != playerId) {
      final propertyData = monopolyBoard.firstWhere(
        (e) => e.index == landedPropertyId,
        orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
      );

      int rentAmount;
      if (propertyData.type == BoardSpaceType.railroad) {
        final railroadsOwned = monopolyBoard.where((s) => s.type == BoardSpaceType.railroad && current.propertyOwners[s.index] == ownerId).length;
        rentAmount = 25 * railroadsOwned;
      } else if (propertyData.type == BoardSpaceType.utility) {
        final utilitiesOwned = monopolyBoard.where((s) => s.type == BoardSpaceType.utility && current.propertyOwners[s.index] == ownerId).length;
        rentAmount = total * (utilitiesOwned >= 2 ? 10 : 4);
      } else {
        rentAmount = propertyData.baseRent ?? ((propertyData.price != null) ? (propertyData.price! * 0.1).ceil() : 10);
      }

      if (propertyData.colorHex != null) {
        final sameColorSpaces = monopolyBoard.where((s) => s.colorHex == propertyData.colorHex).toList();
        final ownsAll = sameColorSpaces.every((s) => current.propertyOwners[s.index] == ownerId);
        if (ownsAll) { rentAmount *= 2; }
      }

      if (rentAmount > 0) {
        final payerIndex = tempPlayers.indexWhere((p) => p.id == playerId);
        final ownerIndex = tempPlayers.indexWhere((p) => p.id == ownerId);

        if (payerIndex != -1 && ownerIndex != -1) {
          final payer = tempPlayers[payerIndex];
          final owner = tempPlayers[ownerIndex];

          final payerNewBalance = payer.balance - rentAmount;
          tempPlayers[payerIndex] = payer.copyWith(balance: payerNewBalance);
          tempPlayers[ownerIndex] = owner.copyWith(balance: owner.balance + rentAmount);

          systemMessage = "${payer.name} paid ₹$rentAmount rent to ${owner.name}";
          onChatAction(systemMessage);

          // ELIMINATION CHECK
          if (payerNewBalance < 0) {
            tempPlayers.removeAt(payerIndex);
            final updatedOwners = Map<int, String>.from(current.propertyOwners);
            updatedOwners.removeWhere((k, v) => v == playerId);

            GamePhase newPhase = current.phase;
            if (tempPlayers.length == 1) {
              newPhase = GamePhase.ended;
              systemMessage = "GAME OVER! ${tempPlayers[0].name} WINS!";
              onChatAction(systemMessage);
            } else {
              systemMessage = "${payer.name} is ELIMINATED!";
              onChatAction(systemMessage);
            }

            String? nextPlayerId = current.currentPlayerId;
            if (tempPlayers.isNotEmpty) {
              int nextIdx = payerIndex % tempPlayers.length;
              nextPlayerId = tempPlayers[nextIdx].id;
            }

            final newState = current.copyWith(
              players: tempPlayers,
              propertyOwners: updatedOwners,
              phase: newPhase,
              currentPlayerId: nextPlayerId,
              lastDiceRoll: [die1],
              pendingDiceRoll: const [],
              isAnimatingDice: false,
              hasRolled: false,
              notificationMessage: systemMessage,
            );
            onStateChanged(newState);
            return;
          }
        }
      }
    }

    final currentSpace = monopolyBoard.firstWhere((s) => s.index == newPos);
    final newState = current.copyWith(
      players: tempPlayers,
      lastDiceRoll: [die1],
      pendingDiceRoll: const [],
      isAnimatingDice: false,
      hasRolled: true,
      notificationMessage: systemMessage ?? cardMessage ?? passGoMessage ?? "${player.name} moved to ${currentSpace.name}",
    );

    onStateChanged(newState);

    // Tax space handling
    if (!justJailed) {
      final taxSpace = monopolyBoard.firstWhere((s) => s.index == newPos, orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner));
      if (taxSpace.type == BoardSpaceType.tax) {
        final taxAmount = taxSpace.price ?? 0;
        final payerIdx = tempPlayers.indexWhere((p) => p.id == playerId);
        if (payerIdx != -1 && taxAmount > 0) {
          final payer = tempPlayers[payerIdx];
          tempPlayers[payerIdx] = payer.copyWith(balance: payer.balance - taxAmount);
          systemMessage = "${payer.name} paid ₹$taxAmount ${taxSpace.name}";
          onChatAction(systemMessage);

          if (payer.balance - taxAmount < 0) {
            tempPlayers.removeAt(payerIdx);
            final updatedOwners = Map<int, String>.from(current.propertyOwners);
            updatedOwners.removeWhere((k, v) => v == playerId);

            if (tempPlayers.length <= 1) {
              final winnerName = tempPlayers.isNotEmpty ? tempPlayers.first.name : "Nobody";
              final endState = current.copyWith(
                players: tempPlayers,
                propertyOwners: updatedOwners,
                phase: GamePhase.ended,
                notificationMessage: " $winnerName wins!",
              );
              onStateChanged(endState);
              onCancelTurnTimer();
              return;
            }
          }
        }
      }
    }

    // AUTO-END TURN CHECK
    final checkPlayer = newState.players.firstWhere((p) => p.id == playerId, orElse: () => updatedPlayer);
    final currentPos = checkPlayer.position;
    final propertyData = monopolyBoard.firstWhere(
      (e) => e.index == currentPos,
      orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
    );

    final isBuyable = propertyData.isBuyable;
    final isUnowned = !newState.propertyOwners.containsKey(currentPos);
    final canAfford = checkPlayer.balance >= (propertyData.price ?? 0);

    bool canBuy = !justJailed && isBuyable && isUnowned && canAfford;

    bool shouldRollAgain = (die1 == 6) || (propertyData.type == BoardSpaceType.chance);

    final finalState = newState.copyWith(
      canRollAgain: shouldRollAgain && !justJailed,
    );

    onStateChanged(finalState);

    if (!canBuy) {
      processEndTurn(playerId, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
    }
  }

  // ---------------------------------------------------------------------------
  // Buy Property
  // ---------------------------------------------------------------------------

  void processBuyProperty(String playerId, int? propertyIndex) {
    if (propertyIndex == null) return;

    final current = getState();
    if (current.propertyOwners.containsKey(propertyIndex)) return;

    final propertyData = monopolyBoard.firstWhere(
      (e) => e.index == propertyIndex,
      orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
    );

    if (!propertyData.isBuyable) return;
    if (propertyData.price == null) return;

    final int price = propertyData.price!;
    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;

    final player = current.players[playerIndex];
    if (player.balance >= price) {
      final updatedPlayer = player.copyWith(balance: player.balance - price);
      final updatedPlayers = List<Player>.from(current.players);
      updatedPlayers[playerIndex] = updatedPlayer;

      final updatedOwners = Map<int, String>.from(current.propertyOwners);
      updatedOwners[propertyIndex] = playerId;

      final newState = current.copyWith(
        players: updatedPlayers,
        propertyOwners: updatedOwners,
        notificationMessage: "${player.name} bought ${propertyData.name}",
      );

      onChatAction("${player.name} bought ${propertyData.name} for ₹$price");
      onStateChanged(newState);
    }
  }

  // ---------------------------------------------------------------------------
  // Trading (#7e)
  // ---------------------------------------------------------------------------

  void processTradeOffer(TradeOffer offer) {
    final current = getState();
    for (final idx in offer.offeredPropertyIndices) {
      if (current.propertyOwners[idx] != offer.fromPlayerId) return;
    }
    for (final idx in offer.requestedPropertyIndices) {
      if (current.propertyOwners[idx] != offer.toPlayerId) return;
    }
    if (offer.cashOffer > 0) {
      final from = current.players.firstWhere((p) => p.id == offer.fromPlayerId);
      if (from.balance < offer.cashOffer) return;
    } else if (offer.cashOffer < 0) {
      final to = current.players.firstWhere((p) => p.id == offer.toPlayerId);
      if (to.balance < -offer.cashOffer) return;
    }

    final fromName = current.players.firstWhere((p) => p.id == offer.fromPlayerId).name;
    final toName = current.players.firstWhere((p) => p.id == offer.toPlayerId).name;
    final newState = current.copyWith(
      pendingTradeOffer: offer,
      notificationMessage: "📦 $fromName proposed a trade to $toName",
    );
    onChatAction("$fromName proposed a trade to $toName");
    onStateChanged(newState);
  }

  void processAcceptTrade(String acceptingPlayerId) {
    final current = getState();
    final offer = current.pendingTradeOffer;
    if (offer == null || offer.toPlayerId != acceptingPlayerId) return;

    final fromIdx = current.players.indexWhere((p) => p.id == offer.fromPlayerId);
    final toIdx = current.players.indexWhere((p) => p.id == offer.toPlayerId);
    if (fromIdx == -1 || toIdx == -1) return;

    final updatedPlayers = List<Player>.from(current.players);
    final updatedOwners = Map<int, String>.from(current.propertyOwners);

    for (final idx in offer.offeredPropertyIndices) {
      updatedOwners[idx] = offer.toPlayerId;
    }
    for (final idx in offer.requestedPropertyIndices) {
      updatedOwners[idx] = offer.fromPlayerId;
    }

    if (offer.cashOffer != 0) {
      updatedPlayers[fromIdx] = updatedPlayers[fromIdx].copyWith(
        balance: updatedPlayers[fromIdx].balance - offer.cashOffer,
      );
      updatedPlayers[toIdx] = updatedPlayers[toIdx].copyWith(
        balance: updatedPlayers[toIdx].balance + offer.cashOffer,
      );
    }

    final fromName = current.players[fromIdx].name;
    final toName = current.players[toIdx].name;
    final newState = current.copyWith(
      players: updatedPlayers,
      propertyOwners: updatedOwners,
      notificationMessage: "✅ Trade completed: $fromName ↔ $toName",
    );
    onChatAction("Trade completed between $fromName and $toName!");
    onStateChanged(newState);
  }

  void processRejectTrade(String rejectingPlayerId) {
    final current = getState();
    final offer = current.pendingTradeOffer;
    if (offer == null || offer.toPlayerId != rejectingPlayerId) return;

    final rejecterName = current.players.firstWhere((p) => p.id == rejectingPlayerId).name;
    final newState = current.copyWith(
      notificationMessage: "❌ $rejecterName rejected the trade",
    );
    onChatAction("$rejecterName rejected the trade");
    onStateChanged(newState);
  }

  // ---------------------------------------------------------------------------
  // End Turn
  // ---------------------------------------------------------------------------

  void processEndTurn(String playerId, {required void Function() onStartTurnTimer, required void Function() onCancelTurnTimer}) {
    final current = getState();
    if (current.currentPlayerId != playerId) return;

    if (current.canRollAgain) {
      final newState = current.copyWith(
        hasRolled: false,
        canRollAgain: false,
        notificationMessage: "ROLL AGAIN!",
      );
      onStateChanged(newState);
      onStartTurnTimer();
      onChatAction('Roll again!');
      return;
    }

    final currentIndex = current.players.indexWhere((p) => p.id == playerId);
    final nextIndex = (currentIndex + 1) % current.players.length;
    final nextPlayerId = current.players[nextIndex].id;

    final nextPlayer = current.players[nextIndex];
    final turnMessage = (current.notificationMessage != null && !current.notificationMessage!.contains("bought"))
        ? "${current.notificationMessage} | Next: ${nextPlayer.name}"
        : "Turn: ${nextPlayer.name}";

    final newTurnCount = current.turnCount + 1;

    // #9: Timed win — after 100 turns, richest player wins
    if (newTurnCount >= 100) {
      final richest = List<Player>.from(current.players)..sort((a, b) => b.balance.compareTo(a.balance));
      final winner = richest.first;
      final endState = current.copyWith(
        phase: GamePhase.ended,
        turnCount: newTurnCount,
        notificationMessage: "🏆 Game Over! ${winner.name} wins with ₹${winner.balance}!",
      );
      onChatAction("Game Over after $newTurnCount turns! ${winner.name} wins with ₹${winner.balance}!");
      onStateChanged(endState);
      onCancelTurnTimer();
      return;
    }

    final newState = current.copyWith(
      currentPlayerId: nextPlayerId,
      hasRolled: false,
      notificationMessage: turnMessage,
      turnCount: newTurnCount,
    );

    onStateChanged(newState);
  }

  // ---------------------------------------------------------------------------
  // Bail
  // ---------------------------------------------------------------------------

  void processPayBail(String playerId) {
    final current = getState();
    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;

    final player = current.players[playerIndex];
    if (!player.isJailed) return;

    const bailAmount = 150;
    if (player.balance >= bailAmount) {
      final updatedPlayer = player.copyWith(
        balance: player.balance - bailAmount,
        isJailed: false,
      );
      final updatedPlayers = List<Player>.from(current.players);
      updatedPlayers[playerIndex] = updatedPlayer;

      final newState = current.copyWith(
        players: updatedPlayers,
        notificationMessage: "${player.name} paid ₹150 to leave Jail",
      );

      onChatAction("${player.name} paid ₹150 to get out of jail");
      onStateChanged(newState);
    }
  }

  // ---------------------------------------------------------------------------
  // Houses & Hotels (#7c)
  // ---------------------------------------------------------------------------

  void processBuildHouse(String playerId, int propertyIndex, {bool isHost = false}) {
    final current = getState();
    if (current.currentPlayerId != playerId && !isHost) return;

    final propertyData = monopolyBoard.firstWhere(
      (s) => s.index == propertyIndex,
      orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
    );

    if (propertyData.type != BoardSpaceType.property) return;
    if (current.propertyOwners[propertyIndex] != playerId) return;
    if (propertyData.houseCost == null) return;

    final currentHouses = current.propertyHouses[propertyIndex] ?? 0;
    if (currentHouses >= 5) return;

    final sameColor = monopolyBoard.where((s) => s.colorHex == propertyData.colorHex).toList();
    final ownsAll = sameColor.every((s) => current.propertyOwners[s.index] == playerId);
    if (!ownsAll) return;

    final minHouses = sameColor.map((s) => current.propertyHouses[s.index] ?? 0).reduce((a, b) => a < b ? a : b);
    if (currentHouses > minHouses) return;

    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;
    final player = current.players[playerIndex];
    if (player.balance < propertyData.houseCost!) return;

    final updatedPlayers = List<Player>.from(current.players);
    updatedPlayers[playerIndex] = player.copyWith(balance: player.balance - propertyData.houseCost!);

    final updatedHouses = Map<int, int>.from(current.propertyHouses);
    updatedHouses[propertyIndex] = currentHouses + 1;

    final label = (currentHouses + 1) == 5 ? "hotel" : "house #${currentHouses + 1}";
    final newState = current.copyWith(
      players: updatedPlayers,
      propertyHouses: updatedHouses,
      notificationMessage: "${player.name} built $label on ${propertyData.name}",
    );
    onChatAction("${player.name} built $label on ${propertyData.name} (₹${propertyData.houseCost})");
    onStateChanged(newState);
  }

  void processSellHouse(String playerId, int propertyIndex) {
    final current = getState();
    if (current.propertyOwners[propertyIndex] != playerId) return;

    final propertyData = monopolyBoard.firstWhere((s) => s.index == propertyIndex, orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner));
    if (propertyData.houseCost == null) return;

    final currentHouses = current.propertyHouses[propertyIndex] ?? 0;
    if (currentHouses <= 0) return;

    final sameColor = monopolyBoard.where((s) => s.colorHex == propertyData.colorHex).toList();
    final maxHouses = sameColor.map((s) => current.propertyHouses[s.index] ?? 0).reduce((a, b) => a > b ? a : b);
    if (currentHouses < maxHouses) return;

    final refund = propertyData.houseCost! ~/ 2;
    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;
    final player = current.players[playerIndex];

    final updatedPlayers = List<Player>.from(current.players);
    updatedPlayers[playerIndex] = player.copyWith(balance: player.balance + refund);
    final updatedHouses = Map<int, int>.from(current.propertyHouses);
    updatedHouses[propertyIndex] = currentHouses - 1;
    if (updatedHouses[propertyIndex] == 0) updatedHouses.remove(propertyIndex);

    final newState = current.copyWith(
      players: updatedPlayers,
      propertyHouses: updatedHouses,
      notificationMessage: "${player.name} sold a house on ${propertyData.name} (+₹$refund)",
    );
    onChatAction("${player.name} sold a house on ${propertyData.name} (+₹$refund)");
    onStateChanged(newState);
  }

  // ---------------------------------------------------------------------------
  // Auctions (#7d)
  // ---------------------------------------------------------------------------

  void startAuction(int propertyIndex) {
    final current = getState();
    if (current.propertyOwners.containsKey(propertyIndex)) return;

    final firstBidderId = current.players.first.id;
    final propertyData = monopolyBoard.firstWhere((s) => s.index == propertyIndex);

    final newState = current.copyWith(
      phase: GamePhase.auction,
      auctionPropertyIndex: propertyIndex,
      auctionBids: {},
      auctionCurrentBidderId: firstBidderId,
      notificationMessage: " Auction: ${propertyData.name} - ${current.players.first.name}'s turn to bid",
    );
    onChatAction("Auction started for ${propertyData.name}!");
    onStateChanged(newState);
  }

  void processAuctionBid(String playerId, int bidAmount) {
    final current = getState();
    if (current.phase != GamePhase.auction) return;
    if (current.auctionCurrentBidderId != playerId) return;

    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;
    final player = current.players[playerIndex];
    if (bidAmount > player.balance) return;

    final currentHighest = current.auctionBids.values.isEmpty ? 0 : current.auctionBids.values.reduce((a, b) => a > b ? a : b);
    if (bidAmount <= currentHighest) return;

    final updatedBids = Map<String, int>.from(current.auctionBids);
    updatedBids[playerId] = bidAmount;

    final nextBidderId = _getNextAuctionBidder(current, playerId);

    final newState = current.copyWith(
      auctionBids: updatedBids,
      auctionCurrentBidderId: nextBidderId,
      notificationMessage: " ${player.name} bids ₹$bidAmount",
    );
    onChatAction("${player.name} bids ₹$bidAmount");
    onStateChanged(newState);
  }

  void processAuctionPass(String playerId, {required void Function() onStartTurnTimer, required void Function() onCancelTurnTimer}) {
    final current = getState();
    if (current.phase != GamePhase.auction) return;
    if (current.auctionCurrentBidderId != playerId) return;

    final player = current.players.firstWhere((p) => p.id == playerId);
    onChatAction("${player.name} passes");

    final nextBidderId = _getNextAuctionBidder(current, playerId);

    final activeBidders = current.players.where((p) => current.auctionBids.containsKey(p.id) || p.id == nextBidderId).toList();

    if (nextBidderId == null || activeBidders.length <= 1) {
      _resolveAuction(current, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
      return;
    }

    final newState = current.copyWith(
      auctionCurrentBidderId: nextBidderId,
      notificationMessage: " ${player.name} passes - ${current.players.firstWhere((p) => p.id == nextBidderId).name}'s turn",
    );
    onStateChanged(newState);
  }

  String? _getNextAuctionBidder(GameState current, String currentBidderId) {
    final playerIds = current.players.map((p) => p.id).toList();
    final currentIdx = playerIds.indexOf(currentBidderId);

    for (int i = 1; i < playerIds.length; i++) {
      final nextIdx = (currentIdx + i) % playerIds.length;
      final nextId = playerIds[nextIdx];
      if (nextId != currentBidderId) return nextId;
    }
    return null;
  }

  void _resolveAuction(GameState current, {required void Function() onStartTurnTimer, required void Function() onCancelTurnTimer}) {
    final propertyIndex = current.auctionPropertyIndex;
    if (propertyIndex == null) return;

    final propertyData = monopolyBoard.firstWhere((s) => s.index == propertyIndex);

    if (current.auctionBids.isEmpty) {
      final newState = current.copyWith(
        phase: GamePhase.playing,
        notificationMessage: "No bids for ${propertyData.name} — stays unowned",
      );
      onStateChanged(newState);
      processEndTurn(current.currentPlayerId!, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
      return;
    }

    String winnerId = current.auctionBids.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    int winAmount = current.auctionBids[winnerId]!;

    final winnerIndex = current.players.indexWhere((p) => p.id == winnerId);
    if (winnerIndex == -1) return;
    final winner = current.players[winnerIndex];

    final updatedPlayers = List<Player>.from(current.players);
    updatedPlayers[winnerIndex] = winner.copyWith(balance: winner.balance - winAmount);

    final updatedOwners = Map<int, String>.from(current.propertyOwners);
    updatedOwners[propertyIndex] = winnerId;

    final newState = current.copyWith(
      players: updatedPlayers,
      propertyOwners: updatedOwners,
      phase: GamePhase.playing,
      notificationMessage: " ${winner.name} wins ${propertyData.name} for ₹$winAmount!",
    );
    onChatAction("${winner.name} won auction for ${propertyData.name} at ₹$winAmount");
    onStateChanged(newState);
    processEndTurn(current.currentPlayerId!, onStartTurnTimer: onStartTurnTimer, onCancelTurnTimer: onCancelTurnTimer);
  }
}
