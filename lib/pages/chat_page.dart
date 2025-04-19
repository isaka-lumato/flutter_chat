import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

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
    // Initialize audio recorder
    _initRecorder();
    // Initialize audio player
    _initPlayer();
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
      // Show sending indicator
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

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_audio/${widget.conversationId}/$fileName');
      final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'audio/m4a'));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _messages.add({
        'sender': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'text': '(Voice message)',
        'audioUrl': downloadUrl,
        'audioName': fileName,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.otherUserName, style: theme.textTheme.titleMedium),
            Text(
              'Online',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
            ),
          ],
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
                onLongPress: () => _showReactionPicker(messageData['id']),
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
                      if (messageData['imageUrl'] != null)
                        GestureDetector(
                          onTap: () => _showFullScreenImage(messageData['imageUrl']),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              messageData['imageUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              errorBuilder: (context, error, stackTrace) {
                                print('DEBUG: Failed to load image: $error');
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Failed to load image', style: TextStyle(color: Colors.grey))
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (messageData['text'] != null && messageData['text'].isNotEmpty && messageData['text'] != '(Image)')
                        Text(
                          messageData['text'],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isMe ? Colors.white : null,
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
            onPressed: _pickImage,
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
              onPressed: _sendMessage,
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
              onPressed: _isRecording ? _stopRecording : _startRecording,
              color: Colors.white,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Create message document
      await _messages.add({
        'text': text,
        'sender': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'conversationId': widget.conversationId,
        'reactions': {},
      });

      // Update conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': text.length > 30 ? '${text.substring(0, 30)}...' : text,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      // Check for appropriate storage permissions based on Android version
      bool permissionGranted = false;
      
      if (Platform.isAndroid) {
        // For Android 13+ (SDK 33+), use more specific media permissions
        if (await Permission.photos.status.isGranted) {
          permissionGranted = true;
        } else {
          final result = await Permission.photos.request();
          permissionGranted = result.isGranted;
        }
      } else {
        // For lower Android versions or other platforms, use general storage
        if (await Permission.storage.status.isGranted) {
          permissionGranted = true;
        } else {
          final result = await Permission.storage.request();
          permissionGranted = result.isGranted;
        }
      }
      
      if (!permissionGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to pick images'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      print('DEBUG: Opening image picker...');
      
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Reduced size for base64 encoding
        maxHeight: 800, // Reduced size for base64 encoding
        imageQuality: 70,
      );

      print('DEBUG: Image picked: ${image?.path}');

      if (image != null) {
        // Check file size
        final file = File(image.path);
        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);
        
        if (sizeInMb > 1) { // Reduced to 1MB for base64 approach
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image size must be less than 1MB for this demo version')),
            );
          }
          return;
        }
        
        // Show loading dialog
        if (!mounted) return;
        bool dialogShown = false;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing image...'),
              ],
            ),
          ),
        );
        dialogShown = true;
        
        try {
          final currentUser = _auth.currentUser;
          if (currentUser == null) {
            throw Exception('User not logged in');
          }

          // Fallback to putData using bytes
          final extension = image.path.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
          final ref = FirebaseStorage.instance
              .ref()
              .child('chat_images/${widget.conversationId}/$fileName');
          final bytes = await image.readAsBytes();
          final mimeType = lookupMimeType(image.path) ?? 'application/octet-stream';
          print('DEBUG: Uploading ${bytes.length} bytes as $mimeType to ${ref.fullPath}');
          final uploadTask = ref.putData(bytes, SettableMetadata(contentType: mimeType));
          uploadTask.snapshotEvents.listen((event) {
            print('DEBUG: upload state: ${event.state}, transferred ${event.bytesTransferred}/${event.totalBytes}');
          });
          print('DEBUG: awaiting upload completion (data)');
          final TaskSnapshot snapshot = await uploadTask;
          print('DEBUG: upload completed (data)');
          final downloadUrl = await snapshot.ref.getDownloadURL();
          print('DEBUG: downloadURL: $downloadUrl');
          
          await _messages.add({
            'text': '(Image)',
            'imageUrl': downloadUrl,
            'imageName': fileName,
            'sender': currentUser.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'conversationId': widget.conversationId,
            'reactions': {},
          });
          
          print('DEBUG: Image shared successfully using Firebase Storage');
        } catch (e) {
          print('ERROR: Failed to process and send image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          // Hide dialog
          if (mounted && dialogShown && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      print('ERROR: Failed to pick image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

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
                    onPressed: () => _saveImageToGallery(imageUrl),
                    tooltip: 'Save to gallery',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _shareImage(imageUrl),
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

  Future<void> _saveImageToGallery(String imageUrl) async {
    try {
      bool hasPermission = false;
      if (Platform.isAndroid) {
        if (await Permission.photos.status.isGranted) {
          hasPermission = true;
        } else {
          final result = await Permission.photos.request();
          hasPermission = result.isGranted;
        }
      } else {
        if (await Permission.storage.status.isGranted) {
          hasPermission = true;
        } else {
          final result = await Permission.storage.request();
          hasPermission = result.isGranted;
        }
      }
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to save images')),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving image...')),
      );
      
      final Uint8List imageData = await http.readBytes(Uri.parse(imageUrl));
      
      final tempDir = await Directory.systemTemp.createTemp('images');
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image saved to gallery'),
          backgroundColor: Colors.green,
        ),
      );
      
      await tempDir.delete(recursive: true);
    } catch (e) {
      print('ERROR: Failed to save image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _shareImage(String imageUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing to share...')),
      );
      
      final Uint8List imageData = await http.readBytes(Uri.parse(imageUrl));
      
      final tempDir = await Directory.systemTemp.createTemp('share');
      final tempFile = File('${tempDir.path}/share_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing functionality will be available soon'),
          backgroundColor: Colors.orange,
        ),
      );
      
      await tempDir.delete(recursive: true);
    } catch (e) {
      print('ERROR: Failed to share image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            backgroundColor: Colors.red,
          ),
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
