import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/services/chat_service.dart';

/// Bridge between [ChatService]'s token stream and Server-Sent Events (SSE)
/// for the web UI.
///
/// Listens to [ChatService.tokenStream] and pushes each token as an SSE event.
/// Manages multiple concurrent SSE client connections.
class WebChatBridge extends ChangeNotifier {
  final ChatService _chatService;

  /// Active SSE connections. Each entry is a StreamController that produces
  /// SSE-formatted data lines. When the shelf handler returns a streamed
  /// Response, it reads from the controller's stream.
  final Set<StreamController<List<int>>> _sseClients = {};

  StreamSubscription<String>? _tokenSubscription;

  WebChatBridge(this._chatService) {
    _tokenSubscription = _chatService.tokenStream.listen(_onToken);
  }

  /// Number of connected SSE clients.
  int get clientCount => _sseClients.length;

  /// Register a new SSE client. Returns the stream of UTF-8 encoded SSE data
  /// that should be used as the Response body.
  Stream<List<int>> addClient() {
    final controller = StreamController<List<int>>();
    _sseClients.add(controller);
    debugPrint('[WebChatBridge] SSE client connected (${_sseClients.length} total)');

    // Send initial connection acknowledgement
    _sendToClient(controller, {'event': 'connected'});

    // If a generation is already in progress, notify the client
    if (_chatService.isGenerating) {
      _sendToClient(controller, {'event': 'generating'});
    }

    // Clean up when the client disconnects
    controller.onCancel = () {
      _sseClients.remove(controller);
      debugPrint('[WebChatBridge] SSE client disconnected (${_sseClients.length} remaining)');
    };

    return controller.stream;
  }

  /// Handle incoming tokens from ChatService.
  void _onToken(String token) {
    if (token == '__DONE__') {
      _broadcastToAll({'event': 'done'});
    } else if (token == '__ERROR__') {
      _broadcastToAll({'event': 'error'});
    } else {
      // Regular token
      _broadcastToAll({'event': 'token', 'data': token});
    }
  }

  /// Broadcast a message to all connected SSE clients.
  void _broadcastToAll(Map<String, dynamic> eventData) {
    // Remove closed controllers first
    _sseClients.removeWhere((c) => c.isClosed);

    for (final client in _sseClients) {
      _sendToClient(client, eventData);
    }
  }

  /// Send a single SSE event to a specific client.
  void _sendToClient(StreamController<List<int>> client, Map<String, dynamic> eventData) {
    if (client.isClosed) return;

    try {
      // SSE format: "data: <json>\n\n"
      final jsonStr = jsonEncode(eventData);
      final sseMessage = 'data: $jsonStr\n\n';
      client.add(utf8.encode(sseMessage));
    } catch (e) {
      debugPrint('[WebChatBridge] Error sending to SSE client: $e');
    }
  }

  /// Broadcast a chat state update to all connected clients.
  /// Called by WebServerService after chat actions (send, stop, select, etc.)
  void broadcastChatUpdate() {
    _broadcastToAll({'event': 'chat_updated'});
  }

  /// Disconnect all SSE clients.
  void disconnectAll() {
    for (final client in _sseClients) {
      if (!client.isClosed) {
        _sendToClient(client, {'event': 'disconnected'});
        client.close();
      }
    }
    _sseClients.clear();
    debugPrint('[WebChatBridge] All SSE clients disconnected');
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    disconnectAll();
    super.dispose();
  }
}
