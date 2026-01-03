import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'protocol.dart';

class SocketClient {
  Socket? _socket;
  final Function(NetworkMessage) onMessageReceived;
  final Function() onDisconnected;

  SocketClient({required this.onMessageReceived, required this.onDisconnected});

  Future<void> connect(String ip) async {
    try {
      _socket = await Socket.connect(ip, 45455, timeout: const Duration(seconds: 5));
      print('Connected to $ip:45455');

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
                  print('Error parsing message: $e');
                }
             } else {
                break;
             }
          }
        },
        onError: (e) {
          print('Connection error: $e');
          disconnect();
        },
        onDone: () {
          print('Disconnected from server');
          disconnect();
        },
      );
    } catch (e) {
      print("Could not connect: $e");
      rethrow;
    }
  }

  void send(NetworkMessage message) {
    final socket = _socket;
    if (socket == null) return;
    try {
      final jsonString = jsonEncode(message.toJson());
      final bytes = utf8.encode(jsonString);
      final length = bytes.length;
      final lengthBytes = _int32ToBytes(length);
      
      // Combine into a single write to be more efficient and avoid socket state issues
      final data = Uint8List.fromList([...lengthBytes, ...bytes]);
      socket.add(data);
    } catch (e) {
       print("Send error: $e");
       disconnect();
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

  void disconnect() {
    _socket?.destroy();
    _socket = null;
    onDisconnected();
  }
}
