import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/services/app_logger.dart';
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';

class UdpDiscoveryService {
  static const int discoveryPort = 45454;
  static const String multicastGroup = '239.1.2.3'; // Optional, but broadcast is easier for simple LAN

  // For Host: Start broadcasting presence
  Timer? _broadcastTimer;
  RawDatagramSocket? _socket;
  final _multicastLock = FlutterMulticastLock();
  
  // For Client: Listening stream
  final StreamController<String> _hostFoundController = StreamController.broadcast();
  Stream<String> get hostFoundStream => _hostFoundController.stream;

  Future<void> startBroadcasting(String roomName) async {
    stop();
    if (Platform.isAndroid) {
      await _multicastLock.acquireMulticastLock();
    }
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.broadcastEnabled = true;

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final message = jsonEncode({'type': 'DISCOVERY', 'name': roomName, 'port': 45455});
      _socket?.send(utf8.encode(message), InternetAddress('255.255.255.255'), discoveryPort);
    });
    AppLogger.info("Started broadcasting on UDP");
  }

  Future<void> startScanning() async {
    stop();
    if (Platform.isAndroid) {
      await _multicastLock.acquireMulticastLock();
    }
    // Bind to the specific port to listen for broadcasts
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
    _socket?.broadcastEnabled = true;
    _socket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          final message = utf8.decode(datagram.data);
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'DISCOVERY') {
              // Found a host
              final ip = datagram.address.address;
             // _hostFoundController.add("$ip:${data['port']}");
              _hostFoundController.add(ip); // Just return IP for now
            }
          } catch (e) {
            // Ignore malformed
          }
        }
      }
    });
    AppLogger.info("Started scanning on UDP port $discoveryPort");
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
    if (Platform.isAndroid) {
      _multicastLock.releaseMulticastLock();
    }
  }
}
