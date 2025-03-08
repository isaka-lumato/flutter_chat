import 'package:image_picker/image_picker.dart';

class FilePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickFile() async {
    try {
      final XFile? result = await _picker.pickMedia(requestFullMetadata: true);
      return result;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  static Future<XFile?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
}
