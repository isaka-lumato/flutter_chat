import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';
import 'package:flutter_chat_mvp/services/user_status_service.dart';
import 'package:flutter_chat_mvp/services/media_repository.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../services/document_service.dart';
import '../widgets/chat_input.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${lastSeen.year}-${lastSeen.month.toString().padLeft(2, '0')}-${lastSeen.day.toString().padLeft(2, '0')} ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
  }

  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User currentUser;
  late final CollectionReference _messages;
  late final DocumentReference _conversation;

  // Voice message recording
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String _recordingPath = '';
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  final Map<String, FlutterSoundPlayer> _audioPlayers = {};
  final Set<String> _deletedMessagesForMe = {};

  @override
  void dispose() {
    _messageController.dispose();
    // Cleanup audio resources
    _recorder.closeRecorder();
    _player.closePlayer();
    // Close all active players
    for (final player in _audioPlayers.values) {
      player.closePlayer();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser!;
    _conversation = FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId);
    _messages = _conversation.collection('messages');
    // Reset unread message count for this user
    _conversation.update({'unreadCounts.${currentUser.uid}': 0});
    // Initialize audio recorder
    _initRecorder();
    // Initialize audio player
    _initPlayer();
    // In-app notification banner for incoming messages
    _messages.orderBy('timestamp', descending: false)
      .snapshots()
      .skip(1)
      .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            if (data['sender'] != currentUser.uid && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.otherUserName}: ${data['text']}'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      });
  }
  
  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
      
      await _recorder.openRecorder();
      
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | 
                                       AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      
      _isRecorderInitialized = true;
    } catch (e) {
      print('Error initializing recorder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize voice recorder: $e')),
        );
      }
    }
  }
  
  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
    } catch (e) {
      print('Error initializing player: $e');
    }
  }


  // Voice recording methods
  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      await _initRecorder();
      if (!_isRecorderInitialized) return;
    }
    
    try {
      // Create temp directory for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      // Start recording
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      
      // Start a timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
      
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }
  
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    try {
      // Stop the timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      // Stop recording
      await _recorder.stopRecorder();
      
      setState(() {
        _isRecording = false;
      });
      
      // Send the recorded audio if it's at least 1 second long
      if (_recordingDuration >= 1) {
        await _sendVoiceMessage(_recordingPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording too short')),
          );
        }
      }
      
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }
  
  Future<void> _sendVoiceMessage(String filePath) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending voice message...')),
        );
      }
      final File file = File(filePath);
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      // Use MediaRepository to upload audio
      final mediaRepository = Provider.of<MediaRepository>(context, listen: false);
      final downloadUrl = await mediaRepository.uploadAudio(
        file: file,
        conversationId: widget.conversationId,
        uploadedBy: currentUser.uid,
      );
      await _messages.add({
        'sender': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'text': '(Voice message)',
        'audioUrl': downloadUrl,
        'audioName': file.path.split('/').last,
        'audioDuration': _recordingDuration,
        'conversationId': widget.conversationId,
        'reactions': {},
      });
      await _conversation.update({
        'lastMessage': '(Voice message)',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
      await file.delete();
    } catch (e) {
      print('Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }
  
  // Audio playback methods
  Future<void> _playVoiceMessage(String messageId, String audioUrl) async {
    try {
      // Check if we already have a player for this message
      if (!_audioPlayers.containsKey(messageId)) {
        // Create a new player
        final player = FlutterSoundPlayer();
        await player.openPlayer();
        _audioPlayers[messageId] = player;
      }
      
      final player = _audioPlayers[messageId]!;
      
      // If currently playing, stop it
      if (player.isPlaying) {
        await player.stopPlayer();
        setState(() {});
        return;
      }
      
      // Play the audio
      await player.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {});
        },
      );
      
      // Force UI update to show the playing state
      setState(() {});
      
    } catch (e) {
      print('Error playing voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play voice message: $e')),
        );
      }
    }
  }

  late final DocumentService _documentService = DocumentService();

  /// Handle a document file selected from ChatInput or legacy UI
  Future<void> _sendDocumentMessage(File file, String fileName) async {
    try {
      final uid = currentUser.uid;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending document...')),
        );
      }
      final downloadUrl = await _documentService.uploadDocument(
        file: file,
        conversationId: widget.conversationId,
        uploadedBy: uid,
      );
      // Add document message to Firestore
      await _messages.add({
        'documentUrl': downloadUrl,
        'documentName': fileName,
        'sender': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'document',
        'conversationId': widget.conversationId,
        'reactions': {},
      });
      // Update conversation last message and unread counts
      final convoDoc = await _conversation.get();
      final convoData = convoDoc.data() as Map<String, dynamic>? ?? {};
      final participants = List<String>.from(convoData['participants'] ?? []);
      final updateData = {
        'lastMessage': fileName,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };
      for (var p in participants) {
        if (p == uid) {
          updateData['unreadCounts.$p'] = 0;
        } else {
          updateData['unreadCounts.$p'] = FieldValue.increment(1);
        }
      }
      await _conversation.update(updateData);
    } catch (e, stackTrace) {
      print('Error sending document: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(userId: widget.otherUserId),
              ),
            );
          },
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.otherUserName, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                ],
              ),
              StreamBuilder<Map<String, dynamic>?>(
                stream: UserStatusService.userStatusStream(widget.otherUserId),
                builder: (context, snapshot) {
                  final status = snapshot.data;
                  if (status == null) {
                    return const SizedBox.shrink();
                  }
                  if (status['online'] == true) {
                    return Text(
                      'Online',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                    );
                  } else if (status['lastSeen'] != null) {
                    final lastSeen = DateTime.fromMillisecondsSinceEpoch(status['lastSeen']);
                    final formatted = _formatLastSeen(lastSeen);
                    return Text(
                      'Last seen $formatted',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    );
                  } else {
                    return Text(
                      'Offline',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          image: DecorationImage(
            image: NetworkImage(
              'https://www.transparenttextures.com/patterns/subtle-dots.png',
            ),
            repeat: ImageRepeat.repeat,
            opacity: 0.1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(50)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No messages yet'));
                  }
                  return ListView.builder(
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final message = snapshot.data!.docs[index];
                      final messageData = message.data() as Map<String, dynamic>;
                      messageData['id'] = message.id; // Add document ID to messageData
                      final isMe =
                          messageData['sender'] == _auth.currentUser?.uid;
                      return _buildMessage(messageData, isMe, theme);
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    Map<String, dynamic> messageData,
    bool isMe,
    ThemeData theme,
  ) {
    // Variable declarations must be at the top of the function
    final imageUrl = messageData['imageUrl'];
    final hasValidImage = imageUrl is String && imageUrl.trim().isNotEmpty;
    final text = messageData['text'];
    final hasValidText = text is String && text.trim().isNotEmpty;
    // Document message UI
    if ((messageData['type'] ?? '') == 'document') {
      final docName = messageData['documentName'] ?? 'Document';
      final docUrl = messageData['documentUrl'];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Card(
            color: isMe ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surface,
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blueAccent),
              title: Text(docName, style: theme.textTheme.bodyMedium),
              subtitle: Text('Document', style: theme.textTheme.bodySmall),
              trailing: IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () async {
                  if (docUrl != null) {
                    await OpenFile.open(docUrl);
                  }
                },
                tooltip: 'Open/Download',
              ),
            ),
          ),
        ),
      );
    }
    if (_deletedMessagesForMe.contains(messageData['id'])) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) _buildAvatar(widget.otherUserName),
              const SizedBox(width: 8),
              GestureDetector(
                onLongPress: () async {
                  final isMe = messageData['sender'] == _auth.currentUser?.uid;
                  if (isMe) {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.delete_forever, color: Colors.red),
                              title: const Text('Delete for Everyone'),
                              onTap: () => Navigator.pop(context, 'delete_all'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.grey),
                              title: const Text('Delete for Me'),
                              onTap: () => Navigator.pop(context, 'delete_me'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.emoji_emotions),
                              title: const Text('React'),
                              onTap: () => Navigator.pop(context, 'react'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (action == 'delete_all') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Message'),
                          content: const Text('Are you sure you want to delete this message?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        _deleteMessage(messageData['id']);
                      }
                    } else if (action == 'delete_me') {
                      setState(() {
                        _deletedMessagesForMe.add(messageData['id']);
                      });
                    } else if (action == 'react') {
                      _showReactionPicker(messageData['id']);
                    }
                  } else {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.grey),
                              title: const Text('Delete for Me'),
                              onTap: () => Navigator.pop(context, 'delete_me'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.emoji_emotions),
                              title: const Text('React'),
                              onTap: () => Navigator.pop(context, 'react'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (action == 'delete_me') {
                      setState(() {
                        _deletedMessagesForMe.add(messageData['id']);
                      });
                    } else if (action == 'react') {
                      _showReactionPicker(messageData['id']);
                    }
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? theme.colorScheme.primary : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasValidImage)
                        GestureDetector(
                          onTap: () => _showFullScreenImage(imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade200,
                                height: 200,
                                width: double.infinity,
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  height: 200,
                                  width: double.infinity,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            ),
                          ),
                        ),
                      if (hasValidText)
                        Text(
                          text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isMe ? Colors.white : null,
                          ),
                        ),
                      if (!hasValidImage && !hasValidText)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'Unsupported or empty message',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ),
                      if (messageData['audioUrl'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _audioPlayers.containsKey(messageData['id']) &&
                                          _audioPlayers[messageData['id']]!.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                color: Theme.of(context).primaryColor,
                                onPressed: () => _playVoiceMessage(
                                    messageData['id'], messageData['audioUrl']),
                              ),
                              Expanded(
                                child: Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blue.shade200 : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: CustomPaint(
                                      painter: WaveformPainter(
                                        isPlaying: _audioPlayers.containsKey(messageData['id']) && 
                                                  _audioPlayers[messageData['id']]!.isPlaying,
                                        color: isMe ? Colors.blue.shade700 : Colors.grey.shade600,
                                      ),
                                      size: const Size(double.infinity, 30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${messageData['audioDuration'] ?? 0}s',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe) _buildAvatar('Me'),
            ],
          ),
          if (messageData['reactions'] != null && (messageData['reactions'] as Map).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 40,
                right: isMe ? 40 : 0,
                top: 4,
              ),
              child: _buildReactions(messageData['reactions'] as Map),
            ),
        ],
      ),
    );
  }

  Widget _buildReactions(Map reactions) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(entry.key),
                const SizedBox(width: 4),
                Text(
                  (entry.value as List).length.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'React to message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: ['❤️', '👍', '👎', '😂', '😮', '😢', '🎉', '🤔'].map((emoji) {
                return InkWell(
                  onTap: () {
                    _addReaction(messageId, emoji);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final messageRef = _messages.doc(messageId);
    final message = await messageRef.get();
    final reactions = (message.data() as Map<String, dynamic>)['reactions'] ?? {};
    
    if (reactions[emoji] == null) {
      reactions[emoji] = [userId];
    } else {
      final List userList = reactions[emoji];
      if (userList.contains(userId)) {
        userList.remove(userId);
        if (userList.isEmpty) {
          reactions.remove(emoji);
        }
      } else {
        userList.add(userId);
      }
    }

    await messageRef.update({'reactions': reactions});
  }

  Widget _buildAvatar(String name) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildMessageInput() {
    return ChatInput(
      onSendMessage: (text) => _sendMessage(text),
      onImageSelected: (file) => _pickImage(file),
      onDocumentSelected: (file, fileName) => _sendDocumentMessage(file, fileName),
      chatId: widget.conversationId,
      userId: currentUser.uid,
      onVoiceRecordStart: _startRecording,
      onVoiceRecordStop: _stopRecording,
    );
  }

  /// Handle an image file selected from ChatInput or legacy UI
  Future<void> _pickImage(File file) async {
    try {
      final uid = currentUser.uid;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending image...')),
        );
      }
      final mediaRepo = Provider.of<MediaRepository>(context, listen: false);
      final downloadUrl = await mediaRepo.uploadImage(
        file: file,
        conversationId: widget.conversationId,
        uploadedBy: uid,
      );
      // Add image message
      await _messages.add({
        'imageUrl': downloadUrl,
        'sender': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
        'conversationId': widget.conversationId,
        'reactions': {},
      });
      // Update conversation
      final doc = await _conversation.get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final participants = List<String>.from(data['participants'] ?? []);
      final updateData = {
        'lastMessage': '(Image)',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };
      for (var participant in participants) {
        if (participant == uid) {
          updateData['unreadCounts.$participant'] = 0;
        } else {
          updateData['unreadCounts.$participant'] = FieldValue.increment(1);
        }
      }
      await _conversation.update(updateData);
    } catch (e, stackTrace) {
      print('Error sending image: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  // Legacy input UI (if needed)
  Widget _buildMessageInputLegacy() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () async {
              // Document picker for legacy UI
              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']);
              if (result != null && result.files.single.path != null) {
                final file = File(result.files.single.path!);
                final fileName = result.files.single.name;
                _sendDocumentMessage(file, fileName);
              }
            },
            color: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () { _pickAndSendImage(); },
            color: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _sendMessage();
                    _messageController.clear();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  _sendMessage();
                  _messageController.clear();
                }
              },
              color: Colors.white,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isRecording 
                ? Colors.red 
                : Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isRecording 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stop, size: 20),
                      Text(" ${_recordingDuration}s", style: const TextStyle(fontSize: 10, color: Colors.white))
                    ],
                  )
                : const Icon(Icons.mic),
              onPressed: _isRecording ? () => _stopRecording() : () => _startRecording(),
              color: Colors.white,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        ],
      ),
    );
  }

  /// Convenience method for legacy UI to pick and send an image
  Future<void> _pickAndSendImage() async {
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      await _pickImage(file);
    }
  }

  /// Show image in full screen dialog
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () => Provider.of<MediaRepository>(context, listen: false).saveImageToGallery(imageUrl, context: context),
                    tooltip: 'Save to gallery',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => Provider.of<MediaRepository>(context, listen: false).shareImage(imageUrl, context: context),
                    tooltip: 'Share image',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? text]) async {
    final content = (text?.trim()) ?? _messageController.text.trim();
    if (content.isEmpty) return;
    // clear legacy input controller
    if (text == null) {
      _messageController.clear();
    }
    try {
      final uid = currentUser.uid;
      await _messages.add({
        'text': content,
        'sender': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'conversationId': widget.conversationId,
        'reactions': {},
      });
      // Update conversation with last message and unread counts
      final doc = await _conversation.get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final participants = List<String>.from(data['participants'] ?? []);
      final Map<String, dynamic> updateData = {
        'lastMessage': content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };
      for (var participant in participants) {
        if (participant == uid) {
          updateData['unreadCounts.$participant'] = 0;
        } else {
          updateData['unreadCounts.$participant'] = FieldValue.increment(1);
        }
      }
      await _conversation.update(updateData);
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _messages.doc(messageId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final Color color;

  WaveformPainter({required this.isPlaying, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (isPlaying) {
      // Draw waveform when playing
      for (int i = 0; i < size.width; i += 10) {
        canvas.drawRect(
          Rect.fromLTWH(i.toDouble(), size.height / 2, 5, size.height / 2),
          paint,
        );
      }
    } else {
      // Draw waveform when not playing
      for (int i = 0; i < size.width; i += 10) {
        canvas.drawRect(
          Rect.fromLTWH(i.toDouble(), size.height / 2, 5, size.height / 4),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
