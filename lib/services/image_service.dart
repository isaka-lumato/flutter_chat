import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<String?> uploadImage(File imageFile, String folderId, {bool isProfilePhoto = false}) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final Reference ref = isProfilePhoto
          ? _storage.ref().child('profile_photos/$folderId/$fileName')
          : _storage.ref().child('chat_images/$folderId/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      final imageUrl = await snapshot.ref.getDownloadURL();
      print('Image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
}
