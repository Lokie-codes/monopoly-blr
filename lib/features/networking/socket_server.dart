import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'protocol.dart';

class SocketServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final Function(NetworkMessage, Socket) onMessageReceived;

  SocketServer({required this.onMessageReceived});

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 45455);
    print('Server running on ${_server?.address.address}:45455');
    
    _server?.listen((Socket client) {
      print('New connection from ${client.remoteAddress.address}');
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
                  print('Error parsing message: $e');
                }
             } else {
                // Not enough data yet, wait for more
                break;
             }
          }
        },
        onError: (e) {
          print('Client error: $e');
          _scheduleRemoveClient(client);
        },
        onDone: () {
          print('Client disconnected');
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
      final lengthBytes = _int32ToBytes(length);
      
      // Create combined message bytes
      final fullMessage = [...lengthBytes, ...bytes];
      
      // Copy client list to avoid concurrent modification
      final clientsCopy = List<Socket>.from(_clients);
      
      for (final client in clientsCopy) {
          try {
            client.add(fullMessage);
          } catch (e) {
            print('Error broadcasting to client: $e');
            _scheduleRemoveClient(client);
          }
      } 
    } catch (e) {
      print("Broadcast encoding error: $e");
    }
  }

  List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
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
