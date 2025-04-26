import 'package:flutter/material.dart';
import 'dart:io';
import '../services/image_service.dart';
import '../services/typing_status.dart';
import 'package:file_picker/file_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File) onImageSelected;
  final Function(File, String) onDocumentSelected;
  final String chatId;
  final String userId;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.chatId,
    required this.userId,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final ImageService _imageService = ImageService();
  final TypingStatusService _typingService = TypingStatusService();
  bool _isTyping = false;

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
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  Widget build(BuildContext context) {
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
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                widget.onSendMessage(_controller.text.trim());
                _controller.clear();
              }
            },
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
    super.dispose();
  }
} 