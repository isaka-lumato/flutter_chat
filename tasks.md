# Media Migration Tasks

Below is a checklist of improvements. Mark each task as done by changing `[ ]` to `[x]` when complete.

- [x] Migrate media blobs to Firebase Storage
  - Store images under `chat_images/{conversationId}/{timestamp}.jpg` and audio under `chat_audio/{conversationId}/{timestamp}.m4a`.
  - In Firestore, save only the download URL and metadata (sender, timestamp, duration, mime-type).

- [ ] Compress/resize before upload
  - Use `flutter_image_compress` for images and convert/trim recordings to lower-bitrate AAC/MP3.

- [ ] Show resumable uploads & progress
  - Leverage `UploadTask.snapshotEvents` to drive progress UI and allow pause/resume.

- [ ] Cache & offline playback
  - Use `cached_network_image` for images and save downloaded audio locally via `path_provider`.

- [ ] Harden Storage rules
  - Write per-conversation rules so users can only read/write their own media.

- [ ] Generate thumbnails & transcripts (optional)
  - Cloud Function to create image previews or use Vision API/Speech-to-Text for transcripts.

- [ ] Refactor UI/architecture
  - Extract upload/download logic into a `MediaRepository` service and adopt Provider/BLoC/Riverpod.

- [ ] Cleanup & retention
  - Cloud Function on Firestore deletes to remove corresponding Storage files.
