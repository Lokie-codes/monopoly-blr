import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../networking/discovery_service.dart';
import '../../networking/socket_server.dart';
import '../../networking/socket_client.dart';
import '../../networking/protocol.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/board_data.dart';
import '../domain/models/chat_message.dart';
import '../../../core/services/app_logger.dart';

// State to track networking status
class NetworkState {
  final bool isHost;
  final bool isConnected;
  final List<String> discoveredHosts;
  final String? myPlayerId;
  final String? error;

  NetworkState({
    this.isHost = false,
    this.isConnected = false,
    this.discoveredHosts = const [],
    this.myPlayerId,
    this.error,
  });

  NetworkState copyWith({
    bool? isHost,
    bool? isConnected,
    List<String>? discoveredHosts,
    String? myPlayerId,
    String? error,
  }) {
    return NetworkState(
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      discoveredHosts: discoveredHosts ?? this.discoveredHosts,
      myPlayerId: myPlayerId ?? this.myPlayerId,
      error: error ?? this.error,
    );
  }
}

// Chat State for managing chat messages
class ChatState {
  final List<ChatMessage> messages;
  final int unreadCount;

  const ChatState({
    this.messages = const [],
    this.unreadCount = 0,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    int? unreadCount,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return const ChatState();
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void addSystemMessage(String text) {
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'SYSTEM',
      senderName: 'System',
      senderColorHex: '#6B7280',
      message: text,
      timestamp: DateTime.now(),
      type: ChatMessageType.system,
    );
    addMessage(message);
  }

  void addActionMessage(String text) {
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'SYSTEM',
      senderName: 'Game',
      senderColorHex: '#667EEA',
      message: text,
      timestamp: DateTime.now(),
      type: ChatMessageType.action,
    );
    addMessage(message);
  }

  void clearMessages() {
    state = const ChatState();
  }
}

class GameNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return const GameState();
  }

  void updateState(GameState newState) {
    state = newState;
  }
}

class NetworkNotifier extends Notifier<NetworkState> {
  // #10: Shuffled card decks
  late final CardDeck _chanceDeck = CardDeck(chanceCards);
  late final CardDeck _communityDeck = CardDeck(communityChestCards);
  UdpDiscoveryService? _discovery;
  SocketServer? _server;
  SocketClient? _client;
  Timer? _turnTimer; // #6: Server-side turn timeout

  @override
  NetworkState build() {
    return NetworkState();
  }

  void leaveLobby() {
    _discovery?.stop();
    _server?.stop();
    _client?.disconnect();
    
    _discovery = null;
    _server = null;
    _client = null;
    _cancelTurnTimer();
    
    state = NetworkState();
    ref.read(gameStateProvider.notifier).updateState(const GameState());
    ref.read(chatProvider.notifier).clearMessages();
  }

  // Helper to get player info for chat
  Player? _getMyPlayer() {
    final gameState = ref.read(gameStateProvider);
    try {
      return gameState.players.firstWhere((p) => p.id == state.myPlayerId);
    } catch (e) {
      return null;
    }
  }

  // Host Logic
  Future<void> startHosting(String playerName) async {
    try {
      _discovery = UdpDiscoveryService();
      await _discovery!.startBroadcasting("Monopoly Host");

      _server = SocketServer(onMessageReceived: _handleServerMessage);
      await _server!.start();

      // Persist host ID for reconnection support
      final prefs = await SharedPreferences.getInstance();
      String? hostId = prefs.getString('monopoly_host_player_id');
      if (hostId == null) {
        hostId = const Uuid().v4();
        await prefs.setString('monopoly_host_player_id', hostId);
      }
      
      final hostPlayer = Player(
        id: hostId, 
        name: playerName,
        colorHex: '#FF6B6B', // First player color
      );

      // Initialize Game State
      ref.read(gameStateProvider.notifier).updateState(
         GameState(players: [hostPlayer], phase: GamePhase.lobby, currentPlayerId: hostId)
      );

      state = state.copyWith(isHost: true, isConnected: true, myPlayerId: hostId);
      
      // System message
      ref.read(chatProvider.notifier).addSystemMessage('You are now hosting a game');
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _handleServerMessage(NetworkMessage msg, dynamic socket) {
      // Logic to update game state based on client messages
      // For lobby: Handle handshake
      if (msg.type == NetworkEventType.handshake) {
          final newPlayerName = msg.payload?['name'] ?? 'Unknown';
          final newPlayerId = msg.senderId;
          
          final currentState = ref.read(gameStateProvider);
          
          // Check if this player already exists (reconnection)
          final existingPlayerIndex = currentState.players.indexWhere((p) => p.id == newPlayerId);
          
          GameState newState;
          if (existingPlayerIndex != -1) {
            // Player is reconnecting - update their name if needed
            final existingPlayer = currentState.players[existingPlayerIndex];
            final updatedPlayer = existingPlayer.copyWith(name: newPlayerName);
            final updatedPlayers = List<Player>.from(currentState.players);
            updatedPlayers[existingPlayerIndex] = updatedPlayer;
            newState = currentState.copyWith(players: updatedPlayers);
            
            ref.read(chatProvider.notifier).addSystemMessage('$newPlayerName reconnected');
          } else {
            // New player joining
            final playerIndex = currentState.players.length;
            final colorHexes = ['#FF6B6B', '#4ECDC4', '#FFE66D', '#95E1D3', '#F38181', '#AA96DA'];
            
            final newPlayer = Player(
              id: newPlayerId, 
              name: newPlayerName,
              colorHex: colorHexes[playerIndex % colorHexes.length],
            );
            
            newState = currentState.copyWith(players: [...currentState.players, newPlayer]);
            ref.read(chatProvider.notifier).addSystemMessage('$newPlayerName joined the game');
          }
          
          ref.read(gameStateProvider.notifier).updateState(newState);

          // Broadcast new state to all
          _server?.broadcast(NetworkMessage(
              type: NetworkEventType.stateUpdate, 
              senderId: 'HOST',
              payload: newState.toJson(),
          ));
      } else if (msg.type == NetworkEventType.rollDice) {
          processRollDiceForPlayer(msg.senderId);
      } else if (msg.type == NetworkEventType.buyProperty) {
          processBuyProperty(msg.senderId, msg.payload?['propertyIndex']);
      } else if (msg.type == NetworkEventType.endTurn) {
          processEndTurn(msg.senderId);
      } else if (msg.type == NetworkEventType.payBail) {
          processPayBail(msg.senderId);
      } else if (msg.type == NetworkEventType.chatMessage) {
          _handleIncomingChatMessage(msg);
          // Rebroadcast to all clients
          _server?.broadcast(msg);
      }
  }

  void _handleIncomingChatMessage(NetworkMessage msg) {
    if (msg.payload != null) {
      try {
        final chatMessage = ChatMessage.fromJson(msg.payload!);
        ref.read(chatProvider.notifier).addMessage(chatMessage);
      } catch (e) {
        AppLogger.error('parsing chat message: $e');
      }
    }
  }

  // Client Logic
  Future<void> startScanning() async {
    _discovery = UdpDiscoveryService();
    _discovery!.hostFoundStream.listen((ip) {
      if (!state.discoveredHosts.contains(ip)) {
        state = state.copyWith(discoveredHosts: [...state.discoveredHosts, ip]);
      }
    });
    await _discovery!.startScanning();
  }

  Future<void> connectToHost(String ip, String playerName) async {
     try {
       _discovery?.stop(); // Stop scanning
       _client = SocketClient(
         onMessageReceived: _handleClientMessage,
         onDisconnected: () => state = state.copyWith(isConnected: false),
       );
       
       await _client!.connect(ip);
       
       // Try to get existing player ID or create new one
       final prefs = await SharedPreferences.getInstance();
       String? myId = prefs.getString('monopoly_player_id');
       if (myId == null) {
         myId = const Uuid().v4();
         await prefs.setString('monopoly_player_id', myId);
       }
       
       state = state.copyWith(isHost: false, isConnected: true, myPlayerId: myId);
       
       // Send Handshake
       _client!.send(NetworkMessage(
           type: NetworkEventType.handshake,
           senderId: myId,
           payload: {'name': playerName},
       ));
       
       // System message
       ref.read(chatProvider.notifier).addSystemMessage('Connected to host at $ip');

     } catch (e) {
       state = state.copyWith(error: "Failed to connect: $e");
     }
  }

  // Host Game Start
  void startGame() {
    if (!state.isHost || _server == null) return;
    
    final current = ref.read(gameStateProvider);
    final newState = current.copyWith(phase: GamePhase.playing);
    
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  _startTurnTimer(); // #6: Start timeout for first turn
    
    // System message
    ref.read(chatProvider.notifier).addActionMessage('Game has started!');
    
    _server?.broadcast(NetworkMessage(
       type: NetworkEventType.startGame,
       senderId: 'HOST',
    ));
  }

  // Chat Messaging
  void sendChatMessage(String text, {bool isEmoji = false}) {
    final player = _getMyPlayer();
    if (player == null) return;

    final chatMessage = ChatMessage(
      id: const Uuid().v4(),
      senderId: player.id,
      senderName: player.name,
      senderColorHex: player.colorHex,
      message: text,
      timestamp: DateTime.now(),
      type: isEmoji ? ChatMessageType.emoji : ChatMessageType.text,
    );

    // Add to local state
    ref.read(chatProvider.notifier).addMessage(chatMessage);

    // Send over network
    final networkMsg = NetworkMessage(
      type: NetworkEventType.chatMessage,
      senderId: player.id,
      payload: chatMessage.toJson(),
    );

    if (state.isHost) {
      _server?.broadcast(networkMsg);
    } else {
      _client?.send(networkMsg);
    }
  }

  // Host Game Logic
  void rollDice() {
     if (!_isMyTurn()) return;
     // New: Prevent multiple rolls
     final current = ref.read(gameStateProvider);
     if (current.hasRolled) return;
     
     if (state.isHost) {
        processRollDiceForPlayer(state.myPlayerId!);
     } else {
        _client?.send(NetworkMessage(
            type: NetworkEventType.rollDice,
            senderId: state.myPlayerId!,
        ));
     }
  }

  void buyProperty() {
     if (!_isMyTurn()) return;
     final current = ref.read(gameStateProvider);
     final myPlayer = current.players.firstWhere((p) => p.id == state.myPlayerId, orElse: () => current.players.first);
     final propertyIndex = myPlayer.position;

     if (state.isHost) {
        processBuyProperty(state.myPlayerId!, propertyIndex);
     } else {
        _client?.send(NetworkMessage(
            type: NetworkEventType.buyProperty,
            senderId: state.myPlayerId!,
            payload: {'propertyIndex': propertyIndex},
        ));
     }
  }

  void endTurn() {
     if (!_isMyTurn()) return;
     if (state.isHost) {
        processEndTurn(state.myPlayerId!);
     } else {
        _client?.send(NetworkMessage(
            type: NetworkEventType.endTurn,
            senderId: state.myPlayerId!,
        ));
     }
  }

  void payBail() {
     if (!_isMyTurn()) return;
     if (state.isHost) {
        processPayBail(state.myPlayerId!);
     } else {
        _client?.send(NetworkMessage(
            type: NetworkEventType.payBail,
            senderId: state.myPlayerId!,
        ));
     }
  }

  bool _isMyTurn() {
    final current = ref.read(gameStateProvider);
    return current.currentPlayerId == state.myPlayerId;
  }
  
  void _broadcastState(GameState newState) {
     _server?.broadcast(NetworkMessage(
       type: NetworkEventType.stateUpdate,
       senderId: 'HOST',
       payload: newState.toJson(),
    ));
  }

  void _handleClientMessage(NetworkMessage msg) {
      if (msg.type == NetworkEventType.stateUpdate && msg.payload != null) {
          final newState = GameState.fromJson(msg.payload!);
          ref.read(gameStateProvider.notifier).updateState(newState);
      } else if (msg.type == NetworkEventType.rollDice && state.isHost) {
          // Host receives Roll Request from a client
          processRollDiceForPlayer(msg.senderId);
      } else if (msg.type == NetworkEventType.payBail && state.isHost) {
          processPayBail(msg.senderId);
      } else if (msg.type == NetworkEventType.chatMessage) {
          _handleIncomingChatMessage(msg);
      }
  }
  
  void processRollDiceForPlayer(String playerId) {
     final current = ref.read(gameStateProvider);
     if (current.currentPlayerId != playerId) return; // Not their turn

     final die1 = (Random().nextInt(6)) + 1;
     
     final player = current.players.firstWhere((p) => p.id == playerId, orElse: () => current.players.first);
     
     // Action message for roll
     ref.read(chatProvider.notifier).addActionMessage('${player.name} rolled a $die1');
     
     // Phase 1: Start animation with pending dice roll (don't move pawn yet)
     final animationState = current.copyWith(
       pendingDiceRoll: [die1],
       isAnimatingDice: true,
     );
     ref.read(gameStateProvider.notifier).updateState(animationState);
     _broadcastState(animationState);
  }
  
  // Called when dice animation completes
  void applyDiceResult() {
     final current = ref.read(gameStateProvider);
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
             // Use Get Out of Jail Free card
             ref.read(chatProvider.notifier).addActionMessage('${player.name} used Get Out of Jail Free card!');
         } else if (die1 == 6) {
             // Escaped on a 6!
             ref.read(chatProvider.notifier).addActionMessage('${player.name} escaped from jail!');
         } else if (turnsInJail >= 3) {
             // #9: Auto-pay bail after 3 turns in jail
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
             ref.read(chatProvider.notifier).addActionMessage('${player.name} spent 3 turns in jail, auto-paid bail');
             ref.read(gameStateProvider.notifier).updateState(newState);
             _broadcastState(newState);
             processEndTurn(playerId);
             return;
         } else {
             // Failed to escape, increment jail turns
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
             ref.read(gameStateProvider.notifier).updateState(newState);
             _broadcastState(newState);
             processEndTurn(playerId);
             return;
         }
     }
     
     // Resolve any jail status change (escape) for calculations
     final playerForMove = player.isJailed ? player.copyWith(isJailed: false, jailTurns: 0, hasGetOutOfJailFreeCard: false) : player;

     int newPos = (playerForMove.position + total) % 28;
     
     // PASS GO Logic
     int newBalance = playerForMove.balance;
     String? passGoMessage;
     if (newPos < playerForMove.position) {
         newBalance += 200;
         passGoMessage = "${player.name} Passed Go! (+\$200)";
         ref.read(chatProvider.notifier).addActionMessage('${player.name} passed GO! Collected \$200');
     }
     
     // GO TO JAIL Logic (Land on index 21 in 28-space board)
     bool justJailed = false;
      bool hasGetOutOfJailFreeCard = player.hasGetOutOfJailFreeCard;
     if (newPos == 21) {
         newPos = 7; // Jail is at index 7
         justJailed = true;
         passGoMessage = "${player.name} sent to Jail!";
         ref.read(chatProvider.notifier).addActionMessage('${player.name} was sent to jail!');
     }

     // CARD SYSTEM LOGIC
     // Check if we are on a card space (and not just sent to jail)
     String? cardMessage;
     if (!justJailed) {
      final spaceData = monopolyBoard.firstWhere(
          (e) => e.index == newPos,
          orElse: () => BoardSpaceData(index: newPos, name: "Unknown", type: BoardSpaceType.corner)
      );
      final spaceType = spaceData.type;
      
      if (spaceType == BoardSpaceType.chance || spaceType == BoardSpaceType.communityChest) {
          final isChance = spaceType == BoardSpaceType.chance;
          final cards = isChance ? chanceCards : communityChestCards;
          if (cards.isNotEmpty) {
              final randomCard = isChance ? _chanceDeck.draw() : _communityDeck.draw();
             
             cardMessage = "Drew ${isChance ? 'Chance' : 'Community Chest'}: ${randomCard.text}";
             ref.read(chatProvider.notifier).addActionMessage(cardMessage);
             
             // Apply Effect
             if (randomCard.actionId == 'money') {
                 newBalance += (randomCard.value ?? 0);
             } else if (randomCard.actionId == 'go_to_jail') {
                 newPos = 7; // Jail is at index 7
                 justJailed = true;
             } else if (randomCard.actionId == 'get_out_of_jail_free') {
                  // #7c: Player receives Get Out of Jail Free card
                  hasGetOutOfJailFreeCard = true;
              } else if (randomCard.actionId == 'advance_to') {
                 int target = randomCard.value!;
                 if (target < newPos) {
                     // Wrapped around (Advance to Go or similar)
                     newBalance += 200; // Implicit pass go logic for simple 'advance'
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
         hasGetOutOfJailFreeCard: hasGetOutOfJailFreeCard
     );
     final updatedPlayers = current.players.map((p) => p.id == playerId ? updatedPlayer : p).toList();
     
     final landedPropertyId = newPos;
     final ownerId = current.propertyOwners[landedPropertyId];
     
     // Copy players for mutation
     List<Player> tempPlayers = List.from(updatedPlayers);
     
     String? systemMessage;

     // Skip Rent/Property checks if sent to jail this turn
     if (!justJailed && ownerId != null && ownerId != playerId) {
        // PAY RENT
        final propertyData = monopolyBoard.firstWhere(
            (e) => e.index == landedPropertyId,
            orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner)
        );
        
        int rentAmount;
         // #7a: Railroad rent scaling (25 per railroad owned)
         if (propertyData.type == BoardSpaceType.railroad) {
             final railroadsOwned = monopolyBoard.where((s) => s.type == BoardSpaceType.railroad && current.propertyOwners[s.index] == ownerId).length;
             rentAmount = 25 * railroadsOwned;
         // #7a: Utility rent scaling (4x or 10x dice roll)
         } else if (propertyData.type == BoardSpaceType.utility) {
             final utilitiesOwned = monopolyBoard.where((s) => s.type == BoardSpaceType.utility && current.propertyOwners[s.index] == ownerId).length;
             rentAmount = total * (utilitiesOwned >= 2 ? 10 : 4);
         } else {
             rentAmount = propertyData.baseRent ?? ((propertyData.price != null) ? (propertyData.price! * 0.1).ceil() : 10);
         }
         // #8: Double rent if owner has all properties of same color group
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
                
                // Allow negative balance temporarily, check for elimination
                final newBalance = payer.balance - rentAmount;
                tempPlayers[payerIndex] = payer.copyWith(balance: newBalance);
                tempPlayers[ownerIndex] = owner.copyWith(balance: owner.balance + rentAmount);
                
                systemMessage = "${payer.name} paid ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¹$rentAmount rent to ${owner.name}";
                ref.read(chatProvider.notifier).addActionMessage(systemMessage);
                
                // ELIMINATION CHECK
                if (newBalance < 0) {
                   // Simple Implementation: Remove them from players list
                   tempPlayers.removeAt(payerIndex);
                   
                   // Clear properties owned by eliminated player
                   final updatedOwners = Map<int, String>.from(current.propertyOwners);
                   updatedOwners.removeWhere((k, v) => v == playerId);

                   // Win Check
                   GamePhase newPhase = current.phase;
                   if (tempPlayers.length == 1) {
                       newPhase = GamePhase.ended;
                       systemMessage = "GAME OVER! ${tempPlayers[0].name} WINS!";
                       ref.read(chatProvider.notifier).addActionMessage(systemMessage);
                   } else {
                       systemMessage = "${payer.name} is ELIMINATED!";
                       ref.read(chatProvider.notifier).addActionMessage(systemMessage);
                   }
                   
                   // Update Owners map in state
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
                   ref.read(gameStateProvider.notifier).updateState(newState);
                   _broadcastState(newState);
                   return; // Exit early
                }
            }
        }
     }

     // Do NOT pass turn automatically. Just update state and set hasRolled = true
     // The current player remains current, but cannot roll again.
     
     final currentSpace = monopolyBoard.firstWhere((s) => s.index == newPos);
     final newState = current.copyWith(
         players: tempPlayers,
         lastDiceRoll: [die1],
         pendingDiceRoll: const [],
         isAnimatingDice: false,
         hasRolled: true,
         notificationMessage: systemMessage ?? cardMessage ?? passGoMessage ?? "${player.name} moved to ${currentSpace.name}",
     );
     
     ref.read(gameStateProvider.notifier).updateState(newState);
     _broadcastState(newState);

     // #7b: Tax space handling
      if (!justJailed) {
          final taxSpace = monopolyBoard.firstWhere((s) => s.index == newPos, orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner));
          if (taxSpace.type == BoardSpaceType.tax) {
              final taxAmount = taxSpace.price ?? 0;
              final payerIdx = tempPlayers.indexWhere((p) => p.id == playerId);
              if (payerIdx != -1 && taxAmount > 0) {
                  final payer = tempPlayers[payerIdx];
                  tempPlayers[payerIdx] = payer.copyWith(balance: payer.balance - taxAmount);
                  systemMessage = "${payer.name} paid ?$taxAmount ${taxSpace.name}";
                  ref.read(chatProvider.notifier).addActionMessage(systemMessage);

                  // Elimination check after tax
                  if (payer.balance - taxAmount < 0) {
                      tempPlayers.removeAt(payerIdx);
                      final updatedOwners = Map<int, String>.from(current.propertyOwners);
                      updatedOwners.removeWhere((k, v) => v == playerId);

                      if (tempPlayers.length <= 1) {
                          final winnerName = tempPlayers.isNotEmpty ? tempPlayers.first.name : "Nobody";
                          final newState = current.copyWith(
                              players: tempPlayers,
                              propertyOwners: updatedOwners,
                              phase: GamePhase.ended,
                              notificationMessage: " $winnerName wins!",
                          );
                          ref.read(gameStateProvider.notifier).updateState(newState);
                          _broadcastState(newState);
                          _cancelTurnTimer();
                          return;
                      }
                  }
              }
          }
      }

      // AUTO-END TURN CHECK: If nothing to buy, end turn
     final checkPlayer = newState.players.firstWhere((p) => p.id == playerId, orElse: () => updatedPlayer);
     final currentPos = checkPlayer.position;
     final propertyData = monopolyBoard.firstWhere(
       (e) => e.index == currentPos, 
       orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner)
     );
     
     final isBuyable = propertyData.isBuyable;
     final isUnowned = !newState.propertyOwners.containsKey(currentPos);
     final canAfford = checkPlayer.balance >= (propertyData.price ?? 0);
     
     bool canBuy = !justJailed && isBuyable && isUnowned && canAfford;
     
     // Check for roll again conditions: 6 or land on Chance
     bool shouldRollAgain = (die1 == 6) || (propertyData.type == BoardSpaceType.chance);
     
     final finalState = newState.copyWith(
       canRollAgain: shouldRollAgain && !justJailed,
     );
     
     ref.read(gameStateProvider.notifier).updateState(finalState);
     _broadcastState(finalState);

     if (!canBuy) {
       processEndTurn(playerId);
     }
  }

  void processBuyProperty(String playerId, int? propertyIndex) {
      if (propertyIndex == null) return;
      
      final current = ref.read(gameStateProvider);
      
      // Validation: Is unowned?
      if (current.propertyOwners.containsKey(propertyIndex)) return;
      
      // Get Real Property Data
      final propertyData = monopolyBoard.firstWhere(
          (e) => e.index == propertyIndex, 
          orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner)
      );
      
      // Check if buyable
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
          
          ref.read(chatProvider.notifier).addActionMessage("${player.name} bought ${propertyData.name} for ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¹${price}");
          
          ref.read(gameStateProvider.notifier).updateState(newState);
          _broadcastState(newState);
      }
  }

  void processEndTurn(String playerId) {
      final current = ref.read(gameStateProvider);
      
      // Validation
      if (current.currentPlayerId != playerId) return;

      // New: Handle Extra Turn (Roll Again)
      if (current.canRollAgain) {
          final newState = current.copyWith(
              hasRolled: false,
              canRollAgain: false, // Reset the flag
              notificationMessage: "ROLL AGAIN!",
          );
          ref.read(gameStateProvider.notifier).updateState(newState);
          _broadcastState(newState);
    _startTurnTimer(); // #6: Start timeout for next player's turn
          ref.read(chatProvider.notifier).addActionMessage('Roll again!');
          return;
      }
      
      final currentIndex = current.players.indexWhere((p) => p.id == playerId);
      final nextIndex = (currentIndex + 1) % current.players.length;
      final nextPlayerId = current.players[nextIndex].id;
      
      final nextPlayer = current.players[nextIndex];
      final turnMessage = (current.notificationMessage != null && !current.notificationMessage!.contains("bought")) 
          ? "${current.notificationMessage} | Next: ${nextPlayer.name}"
          : "Turn: ${nextPlayer.name}";

      final newState = current.copyWith(
          currentPlayerId: nextPlayerId,
          hasRolled: false, // Reset for next player
          notificationMessage: turnMessage,
      );
      
      ref.read(gameStateProvider.notifier).updateState(newState);
      _broadcastState(newState);
  }

  void processPayBail(String playerId) {
      final current = ref.read(gameStateProvider);
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
              notificationMessage: "${player.name} paid ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¹150 to leave Jail",
          );

          ref.read(chatProvider.notifier).addActionMessage("${player.name} paid ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¹150 to get out of jail");

          ref.read(gameStateProvider.notifier).updateState(newState);
          _broadcastState(newState);
      }
  }

  // #7c: Build a house on a property
  void processBuildHouse(String playerId, int propertyIndex) {
    final current = ref.read(gameStateProvider);
    if (current.currentPlayerId != playerId && !state.isHost) return;

    final propertyData = monopolyBoard.firstWhere(
      (s) => s.index == propertyIndex,
      orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner),
    );

    // Validation
    if (propertyData.type != BoardSpaceType.property) return;
    if (current.propertyOwners[propertyIndex] != playerId) return;
    if (propertyData.houseCost == null) return;

    final currentHouses = current.propertyHouses[propertyIndex] ?? 0;
    if (currentHouses >= 5) return; // Max is hotel (5)
    
    // Must own all properties of the color group
    final sameColor = monopolyBoard.where((s) => s.colorHex == propertyData.colorHex).toList();
    final ownsAll = sameColor.every((s) => current.propertyOwners[s.index] == playerId);
    if (!ownsAll) return;

    // Even-build rule: can't build on this property if it already has more houses than any other in the group
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
    ref.read(chatProvider.notifier).addActionMessage("${player.name} built $label on ${propertyData.name} (₹${propertyData.houseCost})");
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  // #7c: Sell a house from a property (get half cost back)
  void processSellHouse(String playerId, int propertyIndex) {
    final current = ref.read(gameStateProvider);
    if (current.propertyOwners[propertyIndex] != playerId) return;

    final propertyData = monopolyBoard.firstWhere((s) => s.index == propertyIndex, orElse: () => BoardSpaceData(index: -1, name: "", type: BoardSpaceType.corner));
    if (propertyData.houseCost == null) return;

    final currentHouses = current.propertyHouses[propertyIndex] ?? 0;
    if (currentHouses <= 0) return;

    // Even-sell rule: can't sell from this property if it already has fewer houses than any other in the group
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
    ref.read(chatProvider.notifier).addActionMessage("${player.name} sold a house on ${propertyData.name} (+₹$refund)");
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  // #7d: Start an auction when a player declines to buy
  void startAuction(int propertyIndex) {
    final current = ref.read(gameStateProvider);
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
    ref.read(chatProvider.notifier).addActionMessage("Auction started for ${propertyData.name}!");
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  // #7d: Place a bid in the auction
  void processAuctionBid(String playerId, int bidAmount) {
    final current = ref.read(gameStateProvider);
    if (current.phase != GamePhase.auction) return;
    if (current.auctionCurrentBidderId != playerId) return;

    final playerIndex = current.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return;
    final player = current.players[playerIndex];
    if (bidAmount > player.balance) return;
    
    // Bid must be higher than current highest
    final currentHighest = current.auctionBids.values.isEmpty ? 0 : current.auctionBids.values.reduce((a, b) => a > b ? a : b);
    if (bidAmount <= currentHighest) return;

    final updatedBids = Map<String, int>.from(current.auctionBids);
    updatedBids[playerId] = bidAmount;

    // Move to next bidder
    final nextBidderId = _getNextAuctionBidder(current, playerId);
    
    final newState = current.copyWith(
      auctionBids: updatedBids,
      auctionCurrentBidderId: nextBidderId,
      notificationMessage: " ${player.name} bids ₹$bidAmount",
    );
    ref.read(chatProvider.notifier).addActionMessage("${player.name} bids ₹$bidAmount");
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  // #7d: Pass on auction (decline to bid)
  void processAuctionPass(String playerId) {
    final current = ref.read(gameStateProvider);
    if (current.phase != GamePhase.auction) return;
    if (current.auctionCurrentBidderId != playerId) return;

    final player = current.players.firstWhere((p) => p.id == playerId);
    ref.read(chatProvider.notifier).addActionMessage("${player.name} passes");

    // Remove from bidding by not adding a bid
    final nextBidderId = _getNextAuctionBidder(current, playerId);
    
    // Check if auction should end (only one bidder left or everyone passed)
    final activeBidders = current.players.where((p) => current.auctionBids.containsKey(p.id) || p.id == nextBidderId).toList();
    
    if (nextBidderId == null || activeBidders.length <= 1) {
      _resolveAuction(current);
      return;
    }

    final newState = current.copyWith(
      auctionCurrentBidderId: nextBidderId,
      notificationMessage: " ${player.name} passes - ${current.players.firstWhere((p) => p.id == nextBidderId).name}'s turn",
    );
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  String? _getNextAuctionBidder(GameState current, String currentBidderId) {
    final playerIds = current.players.map((p) => p.id).toList();
    final currentIdx = playerIds.indexOf(currentBidderId);
    
    // Find next player who hasn't been outbid or passed
    for (int i = 1; i < playerIds.length; i++) {
      final nextIdx = (currentIdx + i) % playerIds.length;
      final nextId = playerIds[nextIdx];
      // Skip if they already passed (not in bids and not current)
      if (nextId != currentBidderId) return nextId;
    }
    return null;
  }

  void _resolveAuction(GameState current) {
    final propertyIndex = current.auctionPropertyIndex;
    if (propertyIndex == null) return;

    final propertyData = monopolyBoard.firstWhere((s) => s.index == propertyIndex);

    if (current.auctionBids.isEmpty) {
      // No one bid — property stays unowned
      final newState = current.copyWith(
        phase: GamePhase.playing,
        notificationMessage: "No bids for ${propertyData.name} — stays unowned",
      );
      ref.read(gameStateProvider.notifier).updateState(newState);
      _broadcastState(newState);
      processEndTurn(current.currentPlayerId!);
      return;
    }

    // Find highest bidder
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
    ref.read(chatProvider.notifier).addActionMessage("${winner.name} won auction for ${propertyData.name} at ₹$winAmount");
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
    processEndTurn(current.currentPlayerId!);
  }

  // #6: Server-side turn timeout
  void _startTurnTimer() {
    _cancelTurnTimer();
    if (!state.isHost) return; // Only host enforces timeouts
    _turnTimer = Timer(const Duration(seconds: 30), () {
      final current = ref.read(gameStateProvider);
      if (current.phase != GamePhase.playing) return;
      final playerId = current.currentPlayerId;
      if (playerId == null) return;
      
      if (!current.hasRolled) {
        // Auto-roll for AFK player
        ref.read(chatProvider.notifier).addActionMessage('Turn timer expired ÃƒÂ¯Ã‚Â¿Ã‚Â½ auto-rolling');
        processRollDiceForPlayer(playerId);
      } else {
        // Already rolled, auto-end turn
        ref.read(chatProvider.notifier).addActionMessage('Turn timer expired ÃƒÂ¯Ã‚Â¿Ã‚Â½ auto-ending turn');
        processEndTurn(playerId);
      }
    });
  }

  void _cancelTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }
}

final gameStateProvider = NotifierProvider<GameNotifier, GameState>(() => GameNotifier());
final networkProvider = NotifierProvider<NetworkNotifier, NetworkState>(() => NetworkNotifier());
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() => ChatNotifier());
