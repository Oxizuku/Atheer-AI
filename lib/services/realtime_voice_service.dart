import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

enum AtheerVoiceState { idle, connecting, listening, thinking, speaking, error }

class RealtimeVoiceService {
  RTCPeerConnection? _peer;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  bool _disposed = false;

  AtheerVoiceState state = AtheerVoiceState.idle;
  String? lastError;
  String latestTranscript = '';
  void Function(AtheerVoiceState state)? onState;
  void Function(String text, {required bool isUser})? onTranscript;

  void _setState(AtheerVoiceState value, {String? error}) {
    state = value;
    lastError = error;
    if (!_disposed) onState?.call(value);
  }

  Future<void> start({List<String> memories = const <String>[]}) async {
    if (_peer != null) return;
    _setState(AtheerVoiceState.connecting);
    try {
      final backendUrl = await AppConfig.getBackendUrl();
      final accessCode = await AppConfig.getAccessCode();
      if (backendUrl.isEmpty) {
        throw Exception('أضف رابط الخادم من الإعدادات أولًا.');
      }
      if (accessCode.isEmpty) {
        throw Exception('أضف رمز الوصول الخاص بالخادم من الإعدادات.');
      }

      final ephemeralKey = await _fetchEphemeralKey(backendUrl, accessCode, memories);
      _peer = await createPeerConnection(<String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      _peer!.onConnectionState = (RTCPeerConnectionState connectionState) {
        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _setState(AtheerVoiceState.error, error: 'تعذر إنشاء اتصال الصوت. تحقق من الشبكة والخادم.');
        } else if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _setState(AtheerVoiceState.listening);
        } else if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setState(AtheerVoiceState.error, error: 'انقطع الاتصال الصوتي.');
        }
      };

      _peer!.onTrack = (RTCTrackEvent event) {
        // Remote audio is played by the WebRTC audio device on supported platforms.
      };

      _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      for (final track in _localStream!.getAudioTracks()) {
        await _peer!.addTrack(track, _localStream!);
      }

      final channelInit = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peer!.createDataChannel('oai-events', channelInit);
      _dataChannel!.onDataChannelState = (RTCDataChannelState channelState) {
        if (channelState == RTCDataChannelState.RTCDataChannelOpen) {
          _setState(AtheerVoiceState.listening);
        }
      };
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        if (message.isBinary) return;
        _handleRealtimeEvent(message.text);
      };

      final offer = await _peer!.createOffer(<String, dynamic>{'offerToReceiveAudio': true});
      await _peer!.setLocalDescription(offer);
      await _waitForIceGathering();
      final localDescription = await _peer!.getLocalDescription();
      final sdp = localDescription?.sdp;
      if (sdp == null || sdp.isEmpty) throw Exception('لم يتم إنشاء وصف اتصال WebRTC.');

      final answerResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/calls'),
        headers: <String, String>{
          'Authorization': 'Bearer $ephemeralKey',
          'Content-Type': 'application/sdp',
        },
        body: sdp,
      ).timeout(const Duration(seconds: 35));
      if (answerResponse.statusCode < 200 || answerResponse.statusCode >= 300) {
        throw Exception('رفض OpenAI الاتصال (${answerResponse.statusCode}): ${_safeResponse(answerResponse.body)}');
      }
      await _peer!.setRemoteDescription(RTCSessionDescription(answerResponse.body, 'answer'));
      _setState(AtheerVoiceState.listening);
    } catch (error) {
      await _cleanup();
      _setState(AtheerVoiceState.error, error: _humanize(error));
      rethrow;
    }
  }

  Future<String> _fetchEphemeralKey(String baseUrl, String accessCode, List<String> memories) async {
    final url = Uri.parse('$baseUrl/api/realtime/client-secret');
    final rawMemory = memories.take(30).join('\n');
    final memoryContext = rawMemory.length > 5000 ? rawMemory.substring(0, 5000) : rawMemory;
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-Atheer-Access-Code': accessCode,
      },
      body: jsonEncode(<String, dynamic>{
        'client': 'flutter-android',
        'memory': memoryContext,
      }),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل طلب جلسة آمنة من الخادم (${response.statusCode}). ${_safeResponse(response.body)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw Exception('رد الخادم غير مفهوم.');
    final secret = decoded['value'] ??
        (decoded['client_secret'] is Map ? decoded['client_secret']['value'] : null) ??
        decoded['clientSecret'] ??
        decoded['ephemeralKey'];
    if (secret is! String || secret.isEmpty) {
      throw Exception('الخادم لم يُرجع مفتاح جلسة مؤقتًا. راجع مسار /api/realtime/client-secret.');
    }
    return secret;
  }

  Future<void> _waitForIceGathering() async {
    final pc = _peer;
    if (pc == null) return;
    final current = await pc.getIceGatheringState();
    if (current == RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    final completer = Completer<void>();
    pc.onIceGatheringState = (RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !completer.isCompleted) {
        completer.complete();
      }
    };
    try {
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Trickle ICE is not used here; continue with candidates gathered so far.
    }
  }

  void _handleRealtimeEvent(String raw) {
    try {
      final event = jsonDecode(raw);
      if (event is! Map<String, dynamic>) return;
      final type = (event['type'] ?? '').toString();
      if (type == 'input_audio_buffer.speech_started') {
        _setState(AtheerVoiceState.listening);
      } else if (type == 'input_audio_buffer.speech_stopped' ||
          type == 'conversation.item.input_audio_transcription.delta') {
        _setState(AtheerVoiceState.thinking);
      } else if (type == 'response.created') {
        _setState(AtheerVoiceState.thinking);
      } else if (type == 'response.output_audio.delta' ||
          type == 'response.audio.delta' ||
          type == 'response.content_part.added') {
        _setState(AtheerVoiceState.speaking);
      } else if (type == 'response.output_audio_transcript.done' ||
          type == 'response.audio_transcript.done' ||
          type == 'response.text.done') {
        final text = (event['transcript'] ?? event['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          latestTranscript = text;
          onTranscript?.call(text, isUser: false);
        }
      } else if (type == 'conversation.item.input_audio_transcription.completed') {
        final text = (event['transcript'] ?? '').toString().trim();
        if (text.isNotEmpty) onTranscript?.call(text, isUser: true);
      } else if (type == 'response.done') {
        _setState(AtheerVoiceState.listening);
      } else if (type == 'error') {
        final message = event['error'] is Map ? event['error']['message'] : 'خطأ من خدمة الصوت.';
        _setState(AtheerVoiceState.error, error: message.toString());
      }
    } catch (_) {
      // Ignore malformed/non-JSON realtime messages.
    }
  }

  Future<void> stop() async {
    await _cleanup();
    _setState(AtheerVoiceState.idle);
  }

  Future<void> _cleanup() async {
    try { await _dataChannel?.close(); } catch (_) {}
    _dataChannel = null;
    try { await _localStream?.dispose(); } catch (_) {}
    _localStream = null;
    try { await _peer?.close(); } catch (_) {}
    _peer = null;
  }

  String _safeResponse(String value) {
    final clean = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return clean.length > 240 ? '${clean.substring(0, 240)}…' : clean;
  }

  String _humanize(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '');
    if (value.contains('Permission') || value.contains('permission')) {
      return 'ما قدرت أوصل للميكروفون. فعّل إذن الميكروفون من إعدادات أندرويد.';
    }
    return value;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _cleanup();
  }
}
