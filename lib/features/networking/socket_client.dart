import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'protocol.dart';
import '../../core/services/app_logger.dart';
import 'network_utils.dart';

class SocketClient {
  Socket? _socket;
  final Function(NetworkMessage) onMessageReceived;
  final Function() onDisconnected;
  String? _lastIp;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  SocketClient({required this.onMessageReceived, required this.onDisconnected});

  Future<void> connect(String ip) async {
    _lastIp = ip;
    _reconnectAttempts = 0;
    await _connectInternal(ip);
  }

  Future<void> _connectInternal(String ip) async {
    try {
      _socket = await Socket.connect(ip, 45455, timeout: const Duration(seconds: 5));
      AppLogger.info('Connected to $ip:45455');
      _reconnectAttempts = 0;
      _isReconnecting = false;

      // Buffer for incoming data
      List<int> buffer = [];

      _socket?.listen(
        (data) {
          buffer.addAll(data);
           while (buffer.length >= 4) {
             int length = (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];
             if (buffer.length >= 4 + length) {
                final messageBytes = buffer.sublist(4, 4 + length);
                buffer = buffer.sublist(4 + length);
                
                try {
                  final jsonString = utf8.decode(messageBytes);
                  final msg = NetworkMessage.fromJson(jsonDecode(jsonString));
                  onMessageReceived(msg);
                } catch (e) {
                  AppLogger.info('Error parsing message: $e');
                }
             } else {
                break;
             }
          }
        },
        onError: (e) {
          AppLogger.info('Connection error: $e');
          _attemptReconnect();
        },
        onDone: () {
          AppLogger.info('Disconnected from server');
          _attemptReconnect();
        },
      );
    } catch (e) {
      AppLogger.info("Could not connect: $e");
      if (_isReconnecting) {
        // During reconnection, try again or give up
        _attemptReconnect();
      } else {
        rethrow;
      }
    }
  }

  /// #13: Attempt reconnection with exponential backoff (max 3 attempts)
  void _attemptReconnect() {
    if (_isReconnecting && _reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.info('Max reconnection attempts reached. Giving up.');
      _isReconnecting = false;
      _reconnectAttempts = 0;
      disconnect();
      return;
    }

    final ip = _lastIp;
    if (ip == null) {
      disconnect();
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // 2s, 4s, 6s
    AppLogger.info('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)...');

    _socket?.destroy();
    _socket = null;

    Future.delayed(delay, () {
      if (_isReconnecting) {
        _connectInternal(ip);
      }
    });
  }

  void send(NetworkMessage message) {
    final socket = _socket;
    if (socket == null) return;
    try {
      final jsonString = jsonEncode(message.toJson());
      final bytes = utf8.encode(jsonString);
      final length = bytes.length;
      final lengthBytes = int32ToBytes(length);
      
      // Combine into a single write to be more efficient and avoid socket state issues
      final data = Uint8List.fromList([...lengthBytes, ...bytes]);
      socket.add(data);
    } catch (e) {
       AppLogger.info("Send error: $e");
       _attemptReconnect();
    }
  }

  /// Whether the client is currently trying to reconnect
  bool get isReconnecting => _isReconnecting;

  void disconnect() {
    _isReconnecting = false;
    _socket?.destroy();
    _socket = null;
    onDisconnected();
  }
}
