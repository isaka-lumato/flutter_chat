import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chat_mvp/services/media_repository.dart';
import 'dart:io';
import 'dart:typed_data';

import 'media_repository_test.mocks.dart';

@GenerateMocks([
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
])
void main() {
  group('MediaRepository', () {
    late MediaRepository mediaRepository;
    late MockFirebaseStorage mockStorage;
    late MockFirebaseFirestore mockFirestore;
    late MockReference mockRef;
    late MockUploadTask mockUploadTask;
    late MockTaskSnapshot mockSnapshot;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDoc;

    setUp(() {
      print('setUp: start');
      mockStorage = MockFirebaseStorage();
      print('setUp: mockStorage created');
      mockFirestore = MockFirebaseFirestore();
      print('setUp: mockFirestore created');
      mockRef = MockReference();
      print('setUp: mockRef created');
      mockUploadTask = MockUploadTask();
      print('setUp: mockUploadTask created');
      mockSnapshot = MockTaskSnapshot();
      print('setUp: mockSnapshot created');
      mockCollection = MockCollectionReference();
      print('setUp: mockCollection created');
      mockDoc = MockDocumentReference();
      print('setUp: mockDoc created');
      mediaRepository = MediaRepository(storage: mockStorage, firestore: mockFirestore);
      print('setUp: mediaRepository created');
    });

    test('uploadImage returns download URL and stores metadata', () async {
      final file = File('test_image.jpg');
      const conversationId = 'conv1';
      const uploadedBy = 'user1';
      const downloadUrl = 'https://test.com/image.jpg';

      when(mockStorage.ref(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenAnswer((_) => mockUploadTask);
      when(mockUploadTask.whenComplete(any)).thenAnswer((_) async => mockSnapshot);
      when(mockUploadTask.snapshot).thenReturn(mockSnapshot);
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) => Future.value(downloadUrl));
      when(mockFirestore.collection('media')).thenReturn(mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.add(any)).thenAnswer((_) => Future.value(mockDoc as DocumentReference<Map<String, dynamic>>));

      final result = await mediaRepository.uploadImage(
        file: file,
        conversationId: conversationId,
        uploadedBy: uploadedBy,
      );
      expect(result, downloadUrl);
      verify(mockFirestore.collection('media')).called(1);
      verify(mockCollection.add(argThat(containsPair('url', downloadUrl)))).called(1);
    });

    test('uploadAudio returns download URL and stores metadata', () async {
      final file = File('test_audio.aac');
      const conversationId = 'conv2';
      const uploadedBy = 'user2';
      const downloadUrl = 'https://test.com/audio.aac';

      when(mockStorage.ref(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenAnswer((_) => mockUploadTask);
      when(mockUploadTask.whenComplete(any)).thenAnswer((_) async => mockSnapshot);
      when(mockUploadTask.snapshot).thenReturn(mockSnapshot);
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) => Future.value(downloadUrl));
      when(mockFirestore.collection('media')).thenReturn(mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.add(any)).thenAnswer((_) => Future.value(mockDoc as DocumentReference<Map<String, dynamic>>));

      final result = await mediaRepository.uploadAudio(
        file: file,
        conversationId: conversationId,
        uploadedBy: uploadedBy,
      );
      expect(result, downloadUrl);
      verify(mockFirestore.collection('media')).called(1);
      verify(mockCollection.add(argThat(containsPair('url', downloadUrl)))).called(1);
    });

    test('downloadImage returns bytes', () async {
      const url = 'https://test.com/image.jpg';
      final expectedBytes = Uint8List.fromList([1, 2, 3]);
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      when(mockRef.getData()).thenAnswer((_) async => expectedBytes);
      final result = await mediaRepository.downloadImage(url);
      expect(result, expectedBytes);
    });

    test('downloadImage throws if null', () async {
      const url = 'https://test.com/image.jpg';
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      when(mockRef.getData()).thenAnswer((_) async => null);
      expect(() => mediaRepository.downloadImage(url), throwsException);
    });

    test('downloadAudio returns bytes', () async {
      print('Test started');
      const url = 'https://test.com/audio.aac';
      final expectedBytes = Uint8List.fromList([4, 5, 6]);
      print('Before mockStorage.refFromURL');
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      print('Before mockRef.getData');
      when(mockRef.getData()).thenAnswer((_) async => expectedBytes);
      print('Before calling mediaRepository.downloadAudio');
      final result = await mediaRepository.downloadAudio(url);
      print('After calling mediaRepository.downloadAudio');
      expect(result, expectedBytes);
      print('Test finished');
    });
  });
}
