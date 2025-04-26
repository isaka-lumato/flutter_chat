import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentService {
  final FirebaseStorage storage;
  final FirebaseFirestore firestore;

  DocumentService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : storage = storage ?? FirebaseStorage.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  /// Uploads a document file to Firebase Storage and returns the download URL.
  Future<String> uploadDocument({
    required File file,
    required String conversationId,
    required String uploadedBy,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = storage.ref('chat_docs/$conversationId/$fileName');
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    // Optionally, store metadata in Firestore
    await firestore.collection('media').add({
      'url': downloadUrl,
      'uploadedBy': uploadedBy,
      'conversationId': conversationId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'document',
      'fileName': fileName,
    });
    return downloadUrl;
  }
}
