import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class SmartwatchService {
  static const EventChannel _ch =
      EventChannel('traininghub.dev/hr_stream');
  static const String _base = 'http://localhost:3000';

  final StreamController<int> _hr = StreamController<int>.broadcast();
  Stream<int> get hrStream => _hr.stream;

  final List<int> currentSetBpm = [];
  bool _recording = false;
  StreamSubscription<dynamic>? _sub;

  SmartwatchService() {
    _startListening();
  }

  void _startListening() {
    _sub?.cancel();
    _sub = _ch.receiveBroadcastStream().listen((b) {
      final bpm = (b is int) ? b : int.tryParse(b.toString()) ?? 0;
      if (bpm > 0) {
        _hr.add(bpm);
        if (_recording) currentSetBpm.add(bpm);
      }
    });
  }

  void startSet() {
    currentSetBpm.clear();
    _recording = true;
  }

  Future<Map<String, dynamic>> finishSetAndSend(
    String uId,
    String exId,
    int duration,
  ) async {
    _recording = false;
    final res = await http.post(
      Uri.parse('$_base/telemetry/live-set'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uId,
        'eid': exId,
        'dur': duration,
        'hr': currentSetBpm,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  void dispose() {
    _recording = false;
    _sub?.cancel();
    _sub = null;
    _hr.close();
  }
}