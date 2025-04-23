import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_chat_mvp/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/presence_service.dart';
import 'package:flutter_chat_mvp/pages/login_page.dart';
import 'package:flutter_chat_mvp/pages/home_page.dart';
import 'package:flutter_chat_mvp/pages/chat_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

// Navigator key for push notification routing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showLocalNotification(message);
}

// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Setup local notifications channel
Future<void> _setupLocalNotifications() async {
  // Define notification channel
  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  // Initialize settings for Android
  final AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // Handle notification tap
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final String? payload = response.payload;
      if (payload != null) {
        // Navigate based on payload content
        navigatorKey.currentState?.pushNamed('/home', arguments: jsonDecode(payload));
      }
    },
    // Handle background notification tap (Android)
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}

// Background tap handler (must be a top-level function)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final String? payload = response.payload;
  if (payload != null) {
    navigatorKey.currentState?.pushNamed('/home', arguments: jsonDecode(payload));
  }
}

// Show a local notification
void _showLocalNotification(RemoteMessage message) {
  final notif = message.notification;
  final android = message.notification?.android;
  if (notif != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Chat message alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase Core initialized successfully');

    // Configure Firebase Storage settings with more robust configuration
    FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 15));
    FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 15));
    FirebaseStorage.instance.setMaxDownloadRetryTime(const Duration(seconds: 10));
    
    // Verify storage connection
    try {
      final storageRef = FirebaseStorage.instance.ref();
      await storageRef.child('test_connection').listAll();
      print('Firebase Storage connection verified successfully');
    } catch (storageError) {
      print('Firebase Storage connection test failed: $storageError');
      print('This is expected on first run, app will still function normally');
    }
    
    print('Firebase Storage configured successfully');

    // Initialize Firebase App Check in debug mode
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print('Firebase App Check activated');
    } catch (appCheckError) {
      print('Firebase App Check activation failed: $appCheckError');
    }
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  // Initialize presence tracking for authenticated users
  PresenceService().initialize();
  // Initialize local notifications and FCM
  await _setupLocalNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  messaging.getToken().then((token) => print('FCM Token: $token'));
  FirebaseMessaging.onMessage.listen(_showLocalNotification);
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final data = msg.data;
    if (data['conversationId'] != null) {
      navigatorKey.currentState?.pushNamed(
        '/chat', arguments: data,
      );
    }
  });
  runApp(
    MultiProvider(
      providers: appProviders,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      routes: {
        '/home': (ctx) => const HomePage(),
        '/chat': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
          return ChatPage(
            conversationId: args['conversationId'],
            otherUserId: args['otherUserId'],
            otherUserName: args['otherUserName'],
          );
        },
      },
      title: 'Flutter Chat MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.robotoTextTheme(),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.blue.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.hasData ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}
