# Chat App Roadmap

Below is a prioritized checklist for building a complete, production-ready chat app. Mark each task as done by changing `[ ]` to `[x]` when complete.

---

## 1. User Account & Profile
- [x] User registration and login (email/password)
- [ ] Google/social login
- [ ] Password reset and email verification
- [ ] User profile management page
    - [x] View profile (picture, username, bio)
    - [ ] Edit/change username
    - [ ] Set/change profile picture
    - [ ] Edit bio/about field
- [x] User status (online/offline/last seen)
- [x] Logout

## 2. Core Chat Features
- [x] List all conversations for user
- [x] Start new conversation (1:1)
- [ ] Group chat (add/remove participants)
- [ ] Leave/delete conversation
- [x] Send/receive text messages
    - [ ] Edit/delete own message
    - [ ] Reply to specific message (quote/reply)
    - [x] Emoji reactions to messages
    - [ ] Message read/delivery indicators (✓/✓✓)
    - [x] Typing indicator ("User is typing...")

## 3. Media & Attachments
- [x] Migrate media blobs to Firebase Storage
    - [x] Store images under `chat_images/{conversationId}/{timestamp}.jpg`
    - [x] Store audio under `chat_audio/{conversationId}/{timestamp}.m4a`
    - [x] In Firestore, save only download URL and metadata (sender, timestamp, duration, mime-type)
- [x] Send/receive images
    - [ ] Compress/resize before upload (`flutter_image_compress`)
    - [~] Show upload progress (basic debug prints, no UI progress bar)
    - [ ] Download/save images to device
- [x] Send/receive audio messages
    - [ ] Compress/convert to AAC/MP3 before upload
    - [~] Show upload progress (basic debug prints, no UI progress bar)
    - [ ] Download/save audio to device
- [ ] Send/receive files/documents

## 4. Notifications
- [ ] Push notifications for new messages
- [ ] In-app notification banners

## 5. Caching & Offline Support
- [ ] Cache images (`cached_network_image`)
- [ ] Offline playback for audio (save locally via `path_provider`)
- [ ] Load recent messages offline

## 6. Security & Privacy
- [~] Harden Firebase Storage rules (improved, but not per-conversation)
    - [ ] Per-conversation access control
- [ ] Block/report user
- [ ] Delete account

## 7. Advanced & Polish
- [ ] Generate thumbnails for images
- [ ] Generate transcripts for audio (speech-to-text)
- [ ] Refactor upload/download logic into a MediaRepository service
- [ ] Adopt Provider/BLoC/Riverpod for state management
- [ ] Cleanup & retention (Cloud Function to delete Storage files when Firestore doc is deleted)

---

Legend: [x] = done, [~] = partially/in progress, [ ] = not implemented

Feel free to re-order, add, or remove tasks as priorities change!
- [ ] Generate thumbnails & transcripts (optional)
  - Cloud Function to create image previews or use Vision API/Speech-to-Text for transcripts.

- [ ] Refactor UI/architecture
  - Extract upload/download logic into a `MediaRepository` service and adopt Provider/BLoC/Riverpod.

- [ ] Cleanup & retention
  - Cloud Function on Firestore deletes to remove corresponding Storage files.
