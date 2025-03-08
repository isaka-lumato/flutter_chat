import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  String _getMimeType(String filePath) {
    final mimeType = lookupMimeType(filePath);
    return mimeType ?? 'application/octet-stream';
  }

  Future<String?> uploadFile(String filePath, String folder) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('File does not exist: $filePath');
        return null;
      }

      final extension = path.extension(filePath).toLowerCase();
      final fileName = '${_uuid.v4()}$extension';
      final destination = '$folder/$fileName';
      final ref = _storage.ref().child(destination);

      // Set proper content type based on file
      final metadata = SettableMetadata(
        contentType: _getMimeType(filePath),
        customMetadata: {
          'uploaded_at': DateTime.now().toIso8601String(),
          'original_name': path.basename(filePath)
        }
      );

      // Upload with progress monitoring
      final uploadTask = ref.putFile(file, metadata);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: $progress%');
      });

      // Wait for completion
      await uploadTask;

      if (uploadTask.snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        print('File uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('Upload failed with state: ${uploadTask.snapshot.state}');
        return null;
      }

    } catch (e, stackTrace) {
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
