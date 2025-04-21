import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  DatabaseReference? _userStatusDatabaseRef;
  StreamSubscription? _connectionSubscription;
  String? _userId;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userStatusDatabaseRef = FirebaseDatabase.instance.ref('status/$_userId');
      _setupPresence();
    }
  }

  void _setupPresence() {
    // Always set a node for this user if it doesn't exist
    _userStatusDatabaseRef!.get().then((snapshot) {
      if (!snapshot.exists) {
        _userStatusDatabaseRef!.set({
          'online': true,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
    final connectedRef = FirebaseDatabase.instance.ref('.info/connected');
    _connectionSubscription = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        _setOnline();
        _userStatusDatabaseRef!.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
  }

  void _setOnline() {
    _userStatusDatabaseRef?.set({
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  void _setOffline() {
    _userStatusDatabaseRef?.set({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _setOffline();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
  }
}
