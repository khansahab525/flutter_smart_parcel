import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/delivery_model.dart';
import 'api_service.dart';

class StreamEvent {
  final int? id;
  final String type;
  final Map<String, dynamic> payload;
  final String? timestamp;

  const StreamEvent({
    this.id,
    required this.type,
    required this.payload,
    this.timestamp,
  });

  factory StreamEvent.fromJson(Map<String, dynamic> json) {
    return StreamEvent(
      id: json['id'] as int?,
      type: json['type'] as String? ?? 'unknown',
      payload: json['payload'] as Map<String, dynamic>? ??
          (json['delivery'] != null
              ? {'delivery': json['delivery']}
              : {}),
      timestamp: json['timestamp'] as String?,
    );
  }

  DeliveryModel? get delivery {
    final data = payload['delivery'] as Map<String, dynamic>?;
    if (data == null) return null;
    return DeliveryModel.fromJson(data);
  }
}

/// Real-time tracking via SSE (Server-Sent Events) with long-poll fallback.
class TrackingStreamService {
  final ApiService _api;
  http.Client? _sseClient;
  StreamSubscription<String>? _sseSubscription;
  int _lastEventId = 0;
  bool _useStream = true;
  int _generation = 0;

  final _eventController = StreamController<StreamEvent>.broadcast();
  Stream<StreamEvent> get events => _eventController.stream;

  TrackingStreamService(this._api);

  void start(int deliveryId) {
    stop();
    _useStream = true;
    final generation = _generation;
    if (_useStream) {
      _connectSse(deliveryId, generation);
    } else {
      _startPolling(deliveryId, generation);
    }
  }

  void stop() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseClient?.close();
    _sseClient = null;
    _generation++;
    _lastEventId = 0;
  }

  void dispose() {
    stop();
    _eventController.close();
  }

  Future<void> _connectSse(int deliveryId, int generation) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.trackingStream(deliveryId)}',
      ).replace(queryParameters: {
        'last_event_id': '$_lastEventId',
      });
      final request = http.Request('GET', uri);
      request.headers.addAll({
        ...ApiConfig.defaultHeaders,
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });

      _sseClient = http.Client();
      final response = await _sseClient!.send(request);
      if (generation != _generation) return;

      if (response.statusCode != 200) {
        _fallbackToPolling(deliveryId, generation);
        return;
      }

      String buffer = '';
      _sseSubscription = response.stream
          .transform(utf8.decoder)
          .listen(
        (chunk) {
          buffer += chunk;
          while (buffer.contains('\n\n')) {
            final index = buffer.indexOf('\n\n');
            final block = buffer.substring(0, index);
            buffer = buffer.substring(index + 2);
            _parseSseBlock(block);
          }
        },
        onError: (_) => _fallbackToPolling(deliveryId, generation),
        onDone: () {
          Future.delayed(ApiConfig.streamReconnectDelay, () {
            if (
                generation == _generation &&
                _sseClient != null &&
                _useStream) {
              _connectSse(deliveryId, generation);
            }
          });
        },
      );
    } catch (_) {
      _fallbackToPolling(deliveryId, generation);
    }
  }

  void _parseSseBlock(String block) {
    String? data;
    int? eventId;

    for (final line in block.split('\n')) {
      if (line.startsWith('data: ')) {
        data = line.substring(6);
      } else if (line.startsWith('id: ')) {
        eventId = int.tryParse(line.substring(4));
      }
    }

    if (data == null) return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'update';

      if (type == 'stream_end') return;
      if (type == 'connected') return;

      if (eventId != null) _lastEventId = eventId;

      _eventController.add(StreamEvent(
        id: eventId ?? json['id'] as int?,
        type: type == 'heartbeat' ? 'heartbeat' : (json['type'] as String? ?? type),
        payload: json['payload'] as Map<String, dynamic>? ?? json,
        timestamp: json['timestamp'] as String?,
      ));
    } catch (_) {}
  }

  void _fallbackToPolling(int deliveryId, int generation) {
    if (generation != _generation || !_useStream) return;
    _useStream = false;
    _sseSubscription?.cancel();
    _sseClient?.close();
    _sseClient = null;
    _startPolling(deliveryId, generation);
  }

  Future<void> _startPolling(int deliveryId, int generation) async {
    var retrySeconds = 2;
    while (generation == _generation && !_useStream) {
      try {
        final response = await _api.get(
          '${ApiConfig.trackingPoll(deliveryId)}'
          '?last_event_id=$_lastEventId&timeout=25',
        );
        if (generation != _generation) return;
        final data = response['data'] as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>? ?? [];

        for (final raw in events) {
          final event = StreamEvent.fromJson(raw as Map<String, dynamic>);
          if (event.id != null) _lastEventId = event.id!;
          _eventController.add(event);
        }

        if (events.isEmpty && data['delivery'] != null) {
          _eventController.add(StreamEvent(
            type: 'heartbeat',
            payload: {'delivery': data['delivery']},
          ));
        }
        retrySeconds = 2;
      } catch (_) {
        await Future<void>.delayed(Duration(seconds: retrySeconds));
        retrySeconds = retrySeconds >= 15 ? 30 : retrySeconds * 2;
      }
    }
  }
}
