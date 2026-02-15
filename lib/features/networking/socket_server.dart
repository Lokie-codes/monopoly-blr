import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'protocol.dart';
import '../../core/services/app_logger.dart';
import 'network_utils.dart';

class SocketServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final Function(NetworkMessage, Socket) onMessageReceived;

  SocketServer({required this.onMessageReceived});

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 45455);
    AppLogger.info('Server running on ${_server?.address.address}:45455');
    
    _server?.listen((Socket client) {
      AppLogger.info('New connection from ${client.remoteAddress.address}');
      _clients.add(client);
      
      // Buffer to hold incoming data
      List<int> buffer = [];

      client.listen(
        (data) {
          buffer.addAll(data);
          
          // Process loop
          while (buffer.length >= 4) {
             // Read length prefix
             int length = (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];
             
             if (buffer.length >= 4 + length) {
                // We have a full message
                final messageBytes = buffer.sublist(4, 4 + length);
                // Remove processed bytes from buffer
                buffer = buffer.sublist(4 + length);
                
                try {
                  final jsonString = utf8.decode(messageBytes);
                  final msg = NetworkMessage.fromJson(jsonDecode(jsonString));
                  onMessageReceived(msg, client);
                } catch (e) {
                  AppLogger.info('Error parsing message: $e');
                }
             } else {
                // Not enough data yet, wait for more
                break;
             }
          }
        },
        onError: (e) {
          AppLogger.info('Client error: $e');
          _scheduleRemoveClient(client);
        },
        onDone: () {
          AppLogger.info('Client disconnected');
          _scheduleRemoveClient(client);
        },
      );
    });
  }

  void broadcast(NetworkMessage message) {
    try {
      final jsonString = jsonEncode(message.toJson());
      final bytes = utf8.encode(jsonString);
      final length = bytes.length;
      final lengthBytes = int32ToBytes(length);
      
      // Create combined message bytes
      final fullMessage = [...lengthBytes, ...bytes];
      
      // Copy client list to avoid concurrent modification
      final clientsCopy = List<Socket>.from(_clients);
      
      for (final client in clientsCopy) {
          try {
            client.add(fullMessage);
          } catch (e) {
            AppLogger.info('Error broadcasting to client: $e');
            _scheduleRemoveClient(client);
          }
      } 
    } catch (e) {
      AppLogger.info("Broadcast encoding error: $e");
    }
  }


  void _scheduleRemoveClient(Socket client) {
    // Schedule removal to avoid concurrent modification
    Future.microtask(() {
      _clients.remove(client);
      try {
        client.close();
      } catch (_) {}
    });
  }

  void stop() {
    final clientsCopy = List<Socket>.from(_clients);
    for (var client in clientsCopy) {
      try {
        client.close();
      } catch (_) {}
    }
    _clients.clear();
    _server?.close();
  }
}
