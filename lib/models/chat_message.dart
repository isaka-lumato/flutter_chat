import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String? documentUrl;
  final String? documentName;
  final String type; // 'text', 'image', 'document', etc.
  final DateTime timestamp;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.documentUrl,
    this.documentName,
    required this.timestamp,
    required this.senderName,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'type': type,
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
      documentUrl: map['documentUrl'],
      documentName: map['documentName'],
      type: map['type'] ?? 'text',
      timestamp: timestamp,
      senderName: map['senderName'] ?? '',
    );
  }
}