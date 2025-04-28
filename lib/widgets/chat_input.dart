import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../services/image_service.dart';
import '../services/typing_status.dart';
import 'package:file_picker/file_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File) onImageSelected;
  final Function(File, String) onDocumentSelected;
  final String chatId;
  final String userId;
  final VoidCallback? onVoiceRecordStart;
  final VoidCallback? onVoiceRecordStop;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.chatId,
    required this.userId,
    this.onVoiceRecordStart,
    this.onVoiceRecordStop,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final ImageService _imageService = ImageService();
  final TypingStatusService _typingService = TypingStatusService();
  bool _isTyping = false;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  late AudioPlayer _audioPlayer;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _audioPlayer = AudioPlayer();
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      // ignore sound errors
    }
  }

  Future<void> _startRecording() async {
    setState(() => _isRecording = true);
    await Future.delayed(Duration.zero, () => HapticFeedback.heavyImpact());
    await _playSound('assets/sounds/record_start.mp3');
    if (widget.onVoiceRecordStart != null) widget.onVoiceRecordStart!();
    // start duration timer
    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds:1));
    });
  }

  Future<void> _stopRecording() async {
    // Extra safeguard: Only stop if currently recording
    if (!_isRecording) return;
    setState(() => _isRecording = false);
    await Future.delayed(Duration.zero, () => HapticFeedback.heavyImpact());
    await _playSound('assets/sounds/record_stop.mp3');
    if (widget.onVoiceRecordStop != null) widget.onVoiceRecordStop!();
    // stop duration timer
    _recordTimer?.cancel();
    _recordDuration = Duration.zero;
    setState(() {});
  }

  Future<void> _pickImage() async {
    final File? image = await _imageService.pickImage();
    if (image != null) {
      widget.onImageSelected(image);
    }
  }

  Future<void> _pickDocument() async {
    // Use file_picker to select a document
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        widget.onDocumentSelected(file, fileName);
      }
    } catch (e) {
      // Handle error or cancellation
    }
  }

  void _onTextChanged() {
    final bool isCurrentlyTyping = _controller.text.isNotEmpty;
    if (_isTyping != isCurrentlyTyping) {
      _isTyping = isCurrentlyTyping;
      _typingService.setTypingStatus(
        widget.userId,
        widget.chatId,
        _isTyping,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _pickDocument,
          ),
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              minLines: 1,
              maxLines: 5,
              onChanged: (val) => setState(() {}), // To update button
            ),
          ),
          hasText
              // Only show send button when there is text. It must never trigger voice recording.
              ? IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final trimmed = _controller.text.trim();
                    print('ChatInput: send pressed: "$trimmed"');
                    if (trimmed.isNotEmpty) {
                      await Future.delayed(Duration.zero, () => HapticFeedback.lightImpact());
                      widget.onSendMessage(trimmed);
                      _controller.clear();
                      setState(() {});
                    }
                  },
                )
              // Only show mic button when there is NO text. It must never trigger send message.
              : GestureDetector(
                  onTap: () async {
                    print('ChatInput: mic tapped, _isRecording=$_isRecording');
                    // Only allow recording logic if not currently sending text
                    if (!_isRecording) {
                      await _startRecording();
                    } else {
                      await _stopRecording();
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red.withOpacity(0.15) : Colors.transparent,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isRecording)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: 1.2),
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(0.4),
                                  ),
                                ),
                              );
                            },
                            onEnd: () {
                              if (_isRecording) setState(() {}); // repeat animation
                            },
                          ),
                        Icon(
                          _isRecording ? Icons.stop : Icons.mic_none,
                          color: _isRecording ? Colors.red : null,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(left:8.0),
              child: Text(
                '${_recordDuration.inMinutes.toString().padLeft(2,'0')}:${(_recordDuration.inSeconds%60).toString().padLeft(2,'0')}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _typingService.setTypingStatus(widget.userId, widget.chatId, false);
    _audioPlayer.dispose();
    super.dispose();
  }
} 