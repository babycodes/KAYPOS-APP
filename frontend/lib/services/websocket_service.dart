import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  // Stream for Held Carts updates
  final _heldCartsStreamController = StreamController<void>.broadcast();
  Stream<void> get heldCartsUpdates => _heldCartsStreamController.stream;

  /// Lazy, non-blocking connection trigger
  void connect() {
    if (_isConnected || _isConnecting) return;
    
    // Defer the actual connection logic so it doesn't block UI rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateConnection();
    });
  }

  Future<void> _initiateConnection() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final apiBase = Api.getApiBase();
      String wsUrl = apiBase.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      
      if (wsUrl.endsWith('/api')) {
        wsUrl = '${wsUrl.substring(0, wsUrl.length - 4)}/api/ws';
      } else {
        wsUrl = '$wsUrl/ws';
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Await ready silently to prevent unhandled Web exceptions from crashing the thread
      await _channel!.ready.catchError((_) {});

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      _channel!.stream.listen(
        (message) {
          if (message.toString().contains('HELD_CARTS_UPDATED')) {
            _heldCartsStreamController.add(null);
          }
        },
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    // Exponential backoff logic (max 30 seconds)
    _reconnectAttempts++;
    int delaySeconds = (2 * _reconnectAttempts).clamp(2, 30);
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isConnected && !_isConnecting) {
        _initiateConnection();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close().catchError((_) {});
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
  }
}
