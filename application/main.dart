/* 
  메인 파일 입니다.
  firebase를 활용한 푸시 알림 기능이 중점적으로 설정되어 있습니다.
  기기마다 고유한 fcm 토큰이 자체 생성되어 서버에 전달됩니다.
*/

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:dku_capstone/screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class PushNotification {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static String? _token;

  static Future<void> init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    _token = await _firebaseMessaging.getToken();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(message.notification!);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    await localNotiInit();
  }

  static String? getToken() {
    return _token;
  }

  static Future localNotiInit() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) => null,
    );
    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveBackgroundNotificationResponse: onNotificationTap,
        onDidReceiveNotificationResponse: onNotificationTap);

    // 알림 채널 생성
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // 채널 ID
      'High Importance Notifications', // 채널 이름
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // 채널 ID
      'High Importance Notifications', // 채널 이름
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload:
          jsonEncode({'title': notification.title, 'body': notification.body}),
    );
  }

  static void onNotificationTap(NotificationResponse notificationResponse) {
    navigatorKey.currentState!
        .pushNamed('/message', arguments: notificationResponse);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Firebase 초기화
  if (message.notification != null) {
    print('Message handled in the background!');
    await PushNotification.showNotification(message.notification!);
  }
}

Future<void> setupInteractedMessage() async {
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
}

void _handleMessage(RemoteMessage message) {
  Future.delayed(const Duration(seconds: 1), () {
    navigatorKey.currentState!.pushNamed('/message', arguments: message);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await PushNotification.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  setupInteractedMessage();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<String?>(
        future: Future.value(PushNotification.getToken()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(); // 로딩 화면
          } else if (snapshot.hasError) {
            return const Center(
                child: Text('Error loading FCM Token')); // 오류 처리
          } else {
            final fcmToken = snapshot.data;
            return LoginScreen(token: fcmToken); // 토큰 전달
          }
        },
      ),
    );
  }
}

class Message extends StatefulWidget {
  const Message({super.key});
  @override
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> {
  @override
  Widget build(BuildContext context) {
    Map payload = {};
    final data = ModalRoute.of(context)!.settings.arguments;
    if (data is RemoteMessage) {
      payload = data.data;
    } else if (data is NotificationResponse) {
      payload = jsonDecode(data.payload!);
    }
    return Scaffold(
        appBar: AppBar(
          title: const Text('FCM PUSH MESSAGE'),
        ),
        body: Center(
          child: Text(payload.toString()),
        ));
  }
}
