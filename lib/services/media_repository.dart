import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MediaRepository {
  final FirebaseStorage storage;
  final FirebaseFirestore firestore;

  MediaRepository({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : storage = storage ?? FirebaseStorage.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  /// Uploads an image file to Firebase Storage and returns the download URL.
  Future<String> uploadImage({
    required File file,
    required String conversationId,
    required String uploadedBy,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = storage.ref('chat_images/$conversationId/$fileName');
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/${fileName.split('.').last}'),
    );
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    // Optionally, store metadata in Firestore
    await firestore.collection('media').add({
      'url': downloadUrl,
      'uploadedBy': uploadedBy,
      'conversationId': conversationId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'image',
    });
    return downloadUrl;
  }

  /// Downloads an image from Firebase Storage as bytes.
  Future<Uint8List> downloadImage(String url) async {
    final ref = storage.refFromURL(url);
    final data = await ref.getData();
    if (data == null) throw Exception('Failed to download image');
    return data;
  }

  /// Uploads audio file to Firebase Storage and returns the download URL.
  Future<String> uploadAudio({
    required File file,
    required String conversationId,
    required String uploadedBy,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = storage.ref('chat_audio/$conversationId/$fileName');
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/${fileName.split('.').last}'),
    );
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    // Optionally, store metadata in Firestore
    await firestore.collection('media').add({
      'url': downloadUrl,
      'uploadedBy': uploadedBy,
      'conversationId': conversationId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'audio',
    });
    return downloadUrl;
  }

  /// Downloads audio from Firebase Storage as bytes.
  Future<Uint8List> downloadAudio(String url) async {
    final ref = storage.refFromURL(url);
    final data = await ref.getData();
    if (data == null) throw Exception('Failed to download audio');
    return data;
  }

  /// Saves an image from a URL to the device gallery (shows snackbars via context).
  Future<void> saveImageToGallery(String imageUrl, {required BuildContext context}) async {
    try {
      // Download image data
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('Failed to download image');
      final imageData = response.bodyBytes;
      // Save to temp file
      final tempDir = await Directory.systemTemp.createTemp('images');
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageData);
      // TODO: Integrate image_gallery_saver or similar plugin for actual gallery save
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery (demo only, plugin integration pending)')),
      );
      await tempDir.delete(recursive: true);
    } catch (e) {
      print('ERROR: Failed to save image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Shares an image from a URL (shows snackbars via context).
  Future<void> shareImage(String imageUrl, {required BuildContext context}) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing to share...')),
      );
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('Failed to download image');
      final imageData = response.bodyBytes;
      final tempDir = await Directory.systemTemp.createTemp('share');
      final tempFile = File('${tempDir.path}/share_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageData);
      // TODO: Integrate share_plus plugin for actual sharing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing functionality will be available soon'), backgroundColor: Colors.orange),
      );
      await tempDir.delete(recursive: true);
    } catch (e) {
      print('ERROR: Failed to share image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share image: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

