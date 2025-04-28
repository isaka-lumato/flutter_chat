import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';

/// A circular play/pause button for voice messages that manages its own playback state.
class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  const AudioMessageWidget({Key? key, required this.audioUrl}) : super(key: key);

  @override
  _AudioMessageWidgetState createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  late FlutterSoundPlayer _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer()..openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_isPlaying) {
      setState(() => _isPlaying = true);
      await _player.startPlayer(
        fromURI: widget.audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() => _isPlaying = false);
        },
      );
    } else {
      await _player.pausePlayer();
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _isPlaying ? theme.primaryColor : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          color: _isPlaying ? Colors.white : theme.primaryColor,
        ),
        onPressed: _togglePlay,
        splashRadius: 24,
      ),
    );
  }
}
