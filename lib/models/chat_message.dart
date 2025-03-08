import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.timestamp,
    required this.senderName,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'senderName': senderName,
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final timestampField = map['timestamp'];
    DateTime timestamp;

    if (timestampField is Timestamp) {
      timestamp = timestampField.toDate();
    } else if (timestampField is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampField);
    } else {
      timestamp = DateTime.now(); // Fallback in case of unexpected type
    }

    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'],
      imageUrl: map['imageUrl'],
      timestamp: timestamp,
      senderName: map['senderName'] ?? '',
    );
  }
} 