import 'dart:async';
import 'dart:convert';  // #19
import 'game_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../networking/discovery_service.dart';
import '../../networking/socket_server.dart';
import '../../networking/socket_client.dart';
import '../../networking/protocol.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';

import '../domain/models/chat_message.dart';
import '../domain/models/trade_offer.dart';
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
  UdpDiscoveryService? _discovery;
  SocketServer? _server;
  SocketClient? _client;
  Timer? _turnTimer; // #6: Server-side turn timeout
  late final GameEngine _engine;

  @override
  NetworkState build() {
    _engine = GameEngine(
      onStateChanged: _onEngineStateChanged,
      onChatAction: (msg) => ref.read(chatProvider.notifier).addActionMessage(msg),
      getState: () => ref.read(gameStateProvider),
    );
    return NetworkState();
  }

  /// Callback from GameEngine when state changes â€” update provider + broadcast + persist
  void _onEngineStateChanged(GameState newState) {
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
  }

  // ---------------------------------------------------------------------------
  // Networking â€” Host / Client / Discovery
  // ---------------------------------------------------------------------------

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

  Player? _getMyPlayer() {
    final gameState = ref.read(gameStateProvider);
    try {
      return gameState.players.firstWhere((p) => p.id == state.myPlayerId);
    } catch (e) {
      return null;
    }
  }

  Future<void> startHosting(String playerName) async {
    try {
      _discovery = UdpDiscoveryService();
      await _discovery!.startBroadcasting("Monopoly Host");

      _server = SocketServer(onMessageReceived: _handleServerMessage);
      await _server!.start();

      final prefs = await SharedPreferences.getInstance();
      String? hostId = prefs.getString('monopoly_host_player_id');
      if (hostId == null) {
        hostId = const Uuid().v4();
        await prefs.setString('monopoly_host_player_id', hostId);
      }
      
      final hostPlayer = Player(
        id: hostId, 
        name: playerName,
        colorHex: '#FF6B6B',
      );

      ref.read(gameStateProvider.notifier).updateState(
         GameState(players: [hostPlayer], phase: GamePhase.lobby, currentPlayerId: hostId)
      );

      state = state.copyWith(isHost: true, isConnected: true, myPlayerId: hostId);
      ref.read(chatProvider.notifier).addSystemMessage('You are now hosting a game');
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _handleServerMessage(NetworkMessage msg, dynamic socket) {
    final gameState = ref.read(gameStateProvider);
    
    if (msg.type == NetworkEventType.playerJoined) {
      final requestedName = msg.payload?['playerName'] ?? 'Player';
      final requestedId = msg.senderId;

      // Check for reconnection
      final existingPlayer = gameState.players.where((p) => p.id == requestedId).toList();
      if (existingPlayer.isNotEmpty) {
        AppLogger.info('Reconnection from ${existingPlayer.first.name}');
        _server?.broadcast(NetworkMessage(
          type: NetworkEventType.stateUpdate,
          senderId: 'HOST',
          payload: gameState.toJson(),
        ));
        ref.read(chatProvider.notifier).addSystemMessage('${existingPlayer.first.name} reconnected');
        return;
      }

      if (gameState.phase != GamePhase.lobby) return;

      final colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD'];
      final color = colors[gameState.players.length % colors.length];
      
      final newPlayer = Player(
        id: requestedId,
        name: requestedName,
        colorHex: color,
      );
      
      final updatedPlayers = [...gameState.players, newPlayer];
      final newState = gameState.copyWith(players: updatedPlayers);
      
      ref.read(gameStateProvider.notifier).updateState(newState);
      _broadcastState(newState);
      ref.read(chatProvider.notifier).addSystemMessage('$requestedName joined the game');
    } else if (msg.type == NetworkEventType.rollDice) {
      _engine.processRollDiceForPlayer(msg.senderId);
    } else if (msg.type == NetworkEventType.payBail) {
      _engine.processPayBail(msg.senderId);
    } else if (msg.type == NetworkEventType.chatMessage) {
      _handleIncomingChatMessage(msg);
    }
  }

  void _handleIncomingChatMessage(NetworkMessage msg) {
    final chatMessage = ChatMessage.fromJson(msg.payload!);
    ref.read(chatProvider.notifier).addMessage(chatMessage);
    if (state.isHost) {
      _server?.broadcast(NetworkMessage(
        type: NetworkEventType.chatMessage,
        senderId: 'HOST',
        payload: chatMessage.toJson(),
      ));
    }
  }

  void startScanning() {
    _discovery = UdpDiscoveryService();
    _discovery!.startScanning();
    _discovery!.hostFoundStream.listen((ip) {
      final current = state.discoveredHosts;
      if (!current.contains(ip)) {
        state = state.copyWith(discoveredHosts: [...current, ip]);
      }
    });
  }


  Future<void> connectToHost(String ip, String playerName) async {
    try {
      _client = SocketClient(onMessageReceived: _handleClientMessage, onDisconnected: () {
        state = state.copyWith(isConnected: false);
      });
      await _client!.connect(ip);
      
      final prefs = await SharedPreferences.getInstance();
      String? myId = prefs.getString('monopoly_client_player_id');
      if (myId == null) {
        myId = const Uuid().v4();
        await prefs.setString('monopoly_client_player_id', myId);
      }
      
      state = state.copyWith(isConnected: true, myPlayerId: myId);

      _client!.send(NetworkMessage(
        type: NetworkEventType.playerJoined,
        senderId: myId,
        payload: {'playerName': playerName},
      ));
      
      ref.read(chatProvider.notifier).addSystemMessage('Connected to host!');
    } catch (e) {
      state = state.copyWith(error: 'Connection failed: $e');
    }
  }

  void _handleClientMessage(NetworkMessage msg) {
    if (msg.type == NetworkEventType.stateUpdate && msg.payload != null) {
      final newState = GameState.fromJson(msg.payload!);
      ref.read(gameStateProvider.notifier).updateState(newState);
    } else if (msg.type == NetworkEventType.rollDice && state.isHost) {
      _engine.processRollDiceForPlayer(msg.senderId);
    } else if (msg.type == NetworkEventType.payBail && state.isHost) {
      _engine.processPayBail(msg.senderId);
    } else if (msg.type == NetworkEventType.chatMessage) {
      _handleIncomingChatMessage(msg);
    }
  }

  // ---------------------------------------------------------------------------
  // Client Actions â€” wrappers that send messages to host or process locally
  // ---------------------------------------------------------------------------

  void startGame() {
    if (!state.isHost) return;
    final gameState = ref.read(gameStateProvider);
    if (gameState.players.length < 2) return;
    
    final newState = gameState.copyWith(
      phase: GamePhase.playing, currentPlayerId: gameState.players.first.id,
    );
    ref.read(gameStateProvider.notifier).updateState(newState);
    _broadcastState(newState);
    ref.read(chatProvider.notifier).addSystemMessage('Game started!');
    _startTurnTimer();
  }

  void sendChatMessage(String text, {bool isEmoji = false}) {
    final myPlayer = _getMyPlayer();
    if (myPlayer == null) return;
    
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: myPlayer.id,
      senderName: myPlayer.name,
      senderColorHex: myPlayer.colorHex,
      message: text,
      timestamp: DateTime.now(),
      type: isEmoji ? ChatMessageType.emoji : ChatMessageType.text,
    );
    
    if (state.isHost) {
      ref.read(chatProvider.notifier).addMessage(message);
      _server?.broadcast(NetworkMessage(
        type: NetworkEventType.chatMessage,
        senderId: 'HOST',
        payload: message.toJson(),
      ));
    } else {
      _client?.send(NetworkMessage(
        type: NetworkEventType.chatMessage,
        senderId: state.myPlayerId ?? '',
        payload: message.toJson(),
      ));
    }
  }

  void rollDice() {
    if (!_isMyTurn()) return;
    if (state.isHost) {
      _engine.processRollDiceForPlayer(state.myPlayerId!);
    } else {
      _client?.send(NetworkMessage(
        type: NetworkEventType.rollDice,
        senderId: state.myPlayerId!,
      ));
    }
  }

  void buyProperty() {
    if (!_isMyTurn()) return;
    final gameState = ref.read(gameStateProvider);
    _engine.processBuyProperty(state.myPlayerId!, gameState.players.firstWhere((p) => p.id == state.myPlayerId).position);
  }

  void endTurn() {
    if (!_isMyTurn()) return;
    _engine.processEndTurn(state.myPlayerId!, onStartTurnTimer: _startTurnTimer, onCancelTurnTimer: _cancelTurnTimer);
  }

  void payBail() {
    final myId = state.myPlayerId;
    if (myId == null) return;
    if (state.isHost) {
      _engine.processPayBail(myId);
    } else {
      _client?.send(NetworkMessage(
        type: NetworkEventType.payBail,
        senderId: myId,
      ));
    }
  }

  bool _isMyTurn() {
    final gameState = ref.read(gameStateProvider);
    return gameState.currentPlayerId == state.myPlayerId;
  }

  // ---------------------------------------------------------------------------
  // Broadcast + Persistence
  // ---------------------------------------------------------------------------

  void _broadcastState(GameState newState) {
    _server?.broadcast(NetworkMessage(
      type: NetworkEventType.stateUpdate,
      senderId: 'HOST',
      payload: newState.toJson(),
    ));
    _saveGameState(newState);
  }

  Future<void> _saveGameState(GameState gameState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(gameState.toJson());
      await prefs.setString('monopoly_saved_game', json);
    } catch (e) {
      // Silently fail â€” saving is best-effort
    }
  }

  Future<GameState?> loadGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('monopoly_saved_game');
      if (json == null) return null;
      final loadedState = GameState.fromJson(jsonDecode(json));
      if (loadedState.phase == GamePhase.ended) return null;
      ref.read(gameStateProvider.notifier).updateState(loadedState);
      return loadedState;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('monopoly_saved_game');
  }

  // ---------------------------------------------------------------------------
  // Delegated Game Logic â€” thin wrappers to GameEngine
  // ---------------------------------------------------------------------------

  void processRollDiceForPlayer(String playerId) => _engine.processRollDiceForPlayer(playerId);

  void applyDiceResult() => _engine.applyDiceResult(onStartTurnTimer: _startTurnTimer, onCancelTurnTimer: _cancelTurnTimer);

  void processBuyProperty(String playerId, int? propertyIndex) => _engine.processBuyProperty(playerId, propertyIndex);

  void processTradeOffer(TradeOffer offer) => _engine.processTradeOffer(offer);

  void processAcceptTrade(String acceptingPlayerId) => _engine.processAcceptTrade(acceptingPlayerId);

  void processRejectTrade(String rejectingPlayerId) => _engine.processRejectTrade(rejectingPlayerId);

  void processEndTurn(String playerId) => _engine.processEndTurn(playerId, onStartTurnTimer: _startTurnTimer, onCancelTurnTimer: _cancelTurnTimer);

  void processPayBail(String playerId) => _engine.processPayBail(playerId);

  void processBuildHouse(String playerId, int propertyIndex) => _engine.processBuildHouse(playerId, propertyIndex, isHost: state.isHost);

  void processSellHouse(String playerId, int propertyIndex) => _engine.processSellHouse(playerId, propertyIndex);

  void startAuction(int propertyIndex) => _engine.startAuction(propertyIndex);

  void processAuctionBid(String playerId, int bidAmount) => _engine.processAuctionBid(playerId, bidAmount);

  void processAuctionPass(String playerId) => _engine.processAuctionPass(playerId, onStartTurnTimer: _startTurnTimer, onCancelTurnTimer: _cancelTurnTimer);

  // ---------------------------------------------------------------------------
  // Timer (#6)
  // ---------------------------------------------------------------------------

  void _startTurnTimer() {
    _cancelTurnTimer();
    if (!state.isHost) return;
    _turnTimer = Timer(const Duration(seconds: 30), () {
      final current = ref.read(gameStateProvider);
      if (current.phase != GamePhase.playing) return;
      final playerId = current.currentPlayerId;
      if (playerId == null) return;
      
      if (!current.hasRolled) {
        ref.read(chatProvider.notifier).addActionMessage('Turn timer expired â€” auto-rolling');
        _engine.processRollDiceForPlayer(playerId);
      } else {
        ref.read(chatProvider.notifier).addActionMessage('Turn timer expired â€” auto-ending turn');
        _engine.processEndTurn(playerId, onStartTurnTimer: _startTurnTimer, onCancelTurnTimer: _cancelTurnTimer);
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

