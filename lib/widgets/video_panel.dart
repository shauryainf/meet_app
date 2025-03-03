import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_application_2/models/participant.dart';

class VideoPanel extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final List<Participant> participants;

  const VideoPanel({
    super.key,
    required this.localRenderer,
    required this.remoteRenderers,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    // If there are no remote renderers, show only local video
    if (remoteRenderers.isEmpty) {
      return _buildSingleVideo(context, localRenderer, 'You');
    }

    // If there's only one remote renderer, show a 1x1 grid
    if (remoteRenderers.length == 1) {
      return _buildTwoPersonGrid(context);
    }

    // Otherwise, show a grid of videos
    return _buildVideoGrid(context);
  }

  // Build a single video view
  Widget _buildSingleVideo(
      BuildContext context, RTCVideoRenderer renderer, String name) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video renderer
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),

          // Name label
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a 1x1 grid for two people
  Widget _buildTwoPersonGrid(BuildContext context) {
    final remoteId = remoteRenderers.keys.first;
    final remoteName = _getParticipantName(remoteId);

    return Column(
      children: [
        // Remote video (larger)
        Expanded(
          flex: 3,
          child: _buildSingleVideo(
              context, remoteRenderers[remoteId]!, remoteName),
        ),

        // Local video (smaller)
        Expanded(
          flex: 1,
          child: _buildSingleVideo(context, localRenderer, 'You'),
        ),
      ],
    );
  }

  // Build a grid of videos for multiple participants
  Widget _buildVideoGrid(BuildContext context) {
    // Calculate grid dimensions
    final int totalVideos = remoteRenderers.length + 1; // +1 for local video
    final int columns = totalVideos <= 4 ? 2 : 3;
    final int rows = (totalVideos / columns).ceil();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 4 / 3,
      ),
      itemCount: totalVideos,
      itemBuilder: (context, index) {
        // Local video is the last item
        if (index == totalVideos - 1) {
          return _buildSingleVideo(context, localRenderer, 'You');
        }

        // Remote videos
        final remoteId = remoteRenderers.keys.elementAt(index);
        final remoteName = _getParticipantName(remoteId);

        return _buildSingleVideo(
            context, remoteRenderers[remoteId]!, remoteName);
      },
    );
  }

  // Get participant name by ID
  String _getParticipantName(String id) {
    final participant = participants.firstWhere(
      (p) => p.id == id,
      orElse: () => Participant(
        id: id,
        name: 'Unknown',
        joinedAt: DateTime.now(),
      ),
    );

    return participant.name;
  }
}
