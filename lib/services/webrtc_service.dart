import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_application_2/services/socket_service.dart';
import 'package:flutter_application_2/environment.dart';

class WebRTCService {
  final SocketService _socketService;

  // Map of peer connections by user ID
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Map of remote video renderers by user ID
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  // Local media stream
  MediaStream? _localStream;

  // Local video renderer
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  // Stream controllers for events
  final StreamController<String> _onUserConnectedController =
      StreamController<String>.broadcast();
  final StreamController<String> _onUserDisconnectedController =
      StreamController<String>.broadcast();

  // Track if the service is disposed
  bool _isDisposed = false;

  // Event streams
  Stream<String> get onUserConnected => _onUserConnectedController.stream;
  Stream<String> get onUserDisconnected => _onUserDisconnectedController.stream;

  // Constructor
  WebRTCService(this._socketService) {
    _initialize();
  }

  // Initialize WebRTC
  Future<void> _initialize() async {
    await localRenderer.initialize();

    // Set up socket event listeners
    _socketService.onOffer.listen(_handleOffer);
    _socketService.onAnswer.listen(_handleAnswer);
    _socketService.onIceCandidate.listen(_handleIceCandidate);
    _socketService.onUserLeft.listen(_handleUserLeft);
  }

  // Get list of remote renderers
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;

  // Initialize local media
  Future<void> initLocalMedia({bool video = true, bool audio = true}) async {
    if (_isDisposed) return;

    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (!_isDisposed) {
        localRenderer.srcObject = _localStream;
      }
    } catch (e) {
      // Fallback to audio only if video fails
      if (video && audio && !_isDisposed) {
        await initLocalMedia(video: false, audio: true);
      } else {
        rethrow;
      }
    }
  }

  // Create a peer connection for a user
  Future<RTCPeerConnection?> _createPeerConnection(String userId) async {
    if (_isDisposed) return null;

    // RTC configuration with ICE servers from environment
    final Map<String, dynamic> configuration = {
      'iceServers': Environment.iceServers,
      'sdpSemantics': 'unified-plan',
    };

    final RTCPeerConnection pc = await createPeerConnection(configuration);

    // Add local stream tracks to the peer connection
    if (_localStream != null && !_isDisposed) {
      for (final track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    // Create and initialize remote renderer
    final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();
    if (_isDisposed) {
      await remoteRenderer.dispose();
      await pc.close();
      return null;
    }

    _remoteRenderers[userId] = remoteRenderer;

    // Handle ICE connection state changes
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _cleanupPeerConnection(userId);
      }
    };

    // Set up event listeners for remote streams
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty && !_isDisposed) {
        final renderer = _remoteRenderers[userId];
        if (renderer != null) {
          renderer.srcObject = event.streams[0];
          _onUserConnectedController.add(userId);
        }
      }
    };

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (!_isDisposed) {
        _socketService.sendIceCandidate(userId, candidate.toMap());
      }
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  // Initiate a call to a user
  Future<void> call(String userId) async {
    if (_isDisposed) return;

    final RTCPeerConnection? pc = await _createPeerConnection(userId);
    if (pc == null) return;

    try {
      final RTCSessionDescription offer = await pc.createOffer();
      if (_isDisposed) return;

      await pc.setLocalDescription(offer);
      if (!_isDisposed) {
        _socketService.sendOffer(userId, offer.toMap());
      }
    } catch (e) {
      _cleanupPeerConnection(userId);
      rethrow;
    }
  }

  // Handle incoming offer
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_isDisposed) return;

    final String fromId = data['fromId'];
    final Map<String, dynamic> sdpData = data['sdp'];

    try {
      // Clean up any existing connection to ensure we're in a clean state
      await _cleanupPeerConnection(fromId);

      // Create a new peer connection
      final pc = await _createPeerConnection(fromId);
      if (pc == null || _isDisposed) return;

      // Set remote description
      await pc.setRemoteDescription(
          RTCSessionDescription(sdpData['sdp'], sdpData['type']));

      if (_isDisposed) return;

      // Create and set local answer
      final RTCSessionDescription answer = await pc.createAnswer();
      if (_isDisposed) return;

      await pc.setLocalDescription(answer);

      if (!_isDisposed) {
        _socketService.sendAnswer(fromId, answer.toMap());
      }
    } catch (e) {
      print('Error handling offer: $e');
      await _cleanupPeerConnection(fromId);
    }
  }

  // Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_isDisposed) return;

    final String fromId = data['fromId'];
    final Map<String, dynamic> sdpData = data['sdp'];

    final RTCPeerConnection? pc = _peerConnections[fromId];
    if (pc != null) {
      try {
        final RTCSignalingState signalingState = pc.signalingState!;

        // Only set remote description if we're in have-local-offer state
        if (signalingState ==
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          await pc.setRemoteDescription(
              RTCSessionDescription(sdpData['sdp'], sdpData['type']));
        } else {
          print('Cannot set remote description in state: $signalingState');
          // If we're in a bad state, recreate the connection
          await _cleanupPeerConnection(fromId);
          await call(fromId);
        }
      } catch (e) {
        print('Error handling answer: $e');
        await _cleanupPeerConnection(fromId);
      }
    }
  }

  // Handle incoming ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_isDisposed) return;

    final String fromId = data['fromId'];
    final Map<String, dynamic> candidateData = data['candidate'];

    final RTCPeerConnection? pc = _peerConnections[fromId];
    if (pc != null) {
      try {
        final RTCIceCandidate candidate = RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
      } catch (e) {
        print('Error adding ice candidate: $e');
      }
    }
  }

  // Handle user leaving
  void _handleUserLeft(String userId) {
    if (_isDisposed) return;

    _cleanupPeerConnection(userId);
    _onUserDisconnectedController.add(userId);
  }

  // Clean up peer connection
  Future<void> _cleanupPeerConnection(String userId) async {
    final RTCPeerConnection? pc = _peerConnections.remove(userId);
    if (pc != null) {
      try {
        await pc.close();
      } catch (e) {
        print('Error closing peer connection: $e');
      }
    }

    final RTCVideoRenderer? renderer = _remoteRenderers.remove(userId);
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (e) {
        print('Error disposing renderer: $e');
      }
    }
  }

  // Toggle local video
  Future<void> toggleVideo() async {
    if (_isDisposed) return;

    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
      }
    }
  }

  // Toggle local audio
  Future<void> toggleAudio() async {
    if (_isDisposed) return;

    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
      }
    }
  }

  // Switch camera
  Future<void> switchCamera() async {
    if (_isDisposed) return;

    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        try {
          // On web, we need to enumerate devices and select a different camera
          final devices = await navigator.mediaDevices.enumerateDevices();
          if (_isDisposed) return;

          final videoDevices =
              devices.where((device) => device.kind == 'videoinput').toList();

          if (videoDevices.length > 1) {
            // Get current device ID
            String? currentDeviceId;
            try {
              currentDeviceId = videoTrack.getSettings()['deviceId'];
            } catch (e) {
              // Ignore if we can't get the current device ID
            }

            // Find a different device
            String? newDeviceId;
            for (final device in videoDevices) {
              if (device.deviceId != currentDeviceId) {
                newDeviceId = device.deviceId;
                break;
              }
            }

            if (newDeviceId != null && !_isDisposed) {
              // Stop current track
              await videoTrack.stop();
              if (_isDisposed) return;

              // Get new stream with different camera
              final newStream = await navigator.mediaDevices.getUserMedia({
                'video': {'deviceId': newDeviceId},
                'audio': false,
              });

              if (_isDisposed) {
                // Clean up new stream if we're disposed
                for (final track in newStream.getTracks()) {
                  track.stop();
                }
                newStream.dispose();
                return;
              }

              // Replace the track in local stream
              final newVideoTrack = newStream.getVideoTracks().first;
              await _localStream!.addTrack(newVideoTrack);
              await _localStream!.removeTrack(videoTrack);

              // Update local renderer
              if (!_isDisposed) {
                localRenderer.srcObject = _localStream;
              }

              // Update tracks in peer connections
              for (final pc in _peerConnections.values) {
                if (_isDisposed) break;

                final senders = await pc.getSenders();
                for (final sender in senders) {
                  if (sender.track?.kind == 'video') {
                    await sender.replaceTrack(newVideoTrack);
                  }
                }
              }
            }
          } else {
            print('Only one camera available');
          }
        } catch (e) {
          print('Error switching camera: $e');
        }
      }
    }
  }

  // Dispose of resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    print('Disposing WebRTC service...');

    // Stop all tracks in local stream
    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        _localStream?.dispose();
      } catch (e) {
        print('Error disposing local stream: $e');
      }
      _localStream = null;
    }

    // Close all peer connections
    final connections = Map<String, RTCPeerConnection>.from(_peerConnections);
    _peerConnections.clear();

    for (final entry in connections.entries) {
      try {
        await entry.value.close();
      } catch (e) {
        print('Error closing peer connection: $e');
      }
    }

    // Clean up remote renderers
    final renderers = Map<String, RTCVideoRenderer>.from(_remoteRenderers);
    _remoteRenderers.clear();

    for (final renderer in renderers.values) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (e) {
        print('Error disposing remote renderer: $e');
      }
    }

    // Clean up local renderer last
    try {
      localRenderer.srcObject = null;
      await localRenderer.dispose();
    } catch (e) {
      print('Error disposing local renderer: $e');
    }

    // Close stream controllers
    try {
      await _onUserConnectedController.close();
    } catch (e) {
      print('Error closing user connected controller: $e');
    }

    try {
      await _onUserDisconnectedController.close();
    } catch (e) {
      print('Error closing user disconnected controller: $e');
    }

    print('WebRTC service disposed');
  }
}
