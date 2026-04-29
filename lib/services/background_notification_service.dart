import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

/// Background notification service that keeps Firestore listeners alive
/// even when the app is swiped from recents or in the background.
/// Runs as an Android foreground service with a persistent notification.
class BackgroundNotificationService {
  BackgroundNotificationService._();

  /// Initialize and start the background service. Call once from main().
  static Future<void> initialize() async {
    if (kIsWeb) return; // No background service on web
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Ryden',
        initialNotificationContent: 'Your Location is Secured',
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  /// Notify the background service that the app is in foreground
  /// (so it skips showing notifications to avoid duplicates)
  static void notifyAppResumed() {
    if (kIsWeb) return;
    FlutterBackgroundService().invoke('appResumed');
  }

  /// Notify the background service that the app is in background
  /// (so it starts showing notifications)
  static void notifyAppPaused() {
    if (kIsWeb) return;
    FlutterBackgroundService().invoke('appPaused');
  }

  /// Tell the background service which chat room the user is viewing
  static void setActiveChatRoom(String? roomId) {
    if (kIsWeb) return;
    FlutterBackgroundService().invoke('activeChatRoom', {'roomId': roomId ?? ''});
  }
}

/// Entry point for the background isolate. Must be top-level.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Firebase in this isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notifications
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await plugin.initialize(settings: initSettings);

  int notificationId = 100; // separate range from foreground service

  // Track whether the main app is in foreground
  bool appInForeground = true; // assume foreground at start

  // Track active chat room (to suppress chat notifications for it)
  String? activeChatRoomId;

  // Listen for app lifecycle messages from the main isolate
  service.on('appResumed').listen((_) {
    appInForeground = true;
  });
  service.on('appPaused').listen((_) {
    appInForeground = false;
  });
  service.on('activeChatRoom').listen((data) {
    activeChatRoomId = (data?['roomId'] as String?)?.isEmpty == true ? null : data?['roomId'];
  });

  // Wait a moment for Firebase Auth to restore the persisted session
  await Future.delayed(const Duration(seconds: 2));

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    // No user logged in — wait for auth state change
    final completer = Completer<String>();
    late final StreamSubscription<User?> authSub;
    authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !completer.isCompleted) {
        completer.complete(user.uid);
        authSub.cancel();
      }
    });

    // Wait up to 30 seconds for login
    final resolvedUid = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => '',
    );

    if (resolvedUid.isEmpty) return; // No user, service idles
    _startListeners(service, plugin, resolvedUid, notificationId, () => appInForeground, () => activeChatRoomId);
  } else {
    _startListeners(service, plugin, uid, notificationId, () => appInForeground, () => activeChatRoomId);
  }
}

/// Ryden brand color
const int _rydenBlue = 0xFF2E7CF6;

/// Start Firestore listeners for notifications and chats
void _startListeners(
  ServiceInstance service,
  FlutterLocalNotificationsPlugin plugin,
  String uid,
  int notificationIdStart,
  bool Function() isAppInForeground,
  String? Function() getActiveChatRoomId,
) {
  int notificationId = notificationIdStart;
  final shownNotificationIds = <String>{};
  final lastNotifiedChatTime = <String, DateTime>{};
  bool notificationListenerReady = false;
  bool chatListenerReady = false;

  // ─── Listener 1: General notifications ───
  FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .listen((snapshot) {
    if (!notificationListenerReady) {
      // First snapshot — record existing IDs, don't notify
      for (final doc in snapshot.docs) {
        shownNotificationIds.add(doc.id);
      }
      notificationListenerReady = true;
      return;
    }

    // Skip when app is in foreground (main isolate handles it)
    if (isAppInForeground()) {
      // Still record IDs to avoid showing them later when app goes to background
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          shownNotificationIds.add(change.doc.id);
        }
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final docId = change.doc.id;
        if (shownNotificationIds.contains(docId)) continue;
        shownNotificationIds.add(docId);

        final data = change.doc.data();
        if (data != null && data['isRead'] != true) {
          final title = data['title'] as String? ?? '';
          final body = data['body'] as String? ?? '';
          if (title.isNotEmpty) {
            _showRideNotification(plugin, notificationId++, title, body);
          }
        }
      }
    }
  }, onError: (error) {
    // Silently handle errors
  });

  // ─── Listener 2: Chat messages ───
  FirebaseFirestore.instance
      .collection('chat_rooms')
      .where('participants', arrayContains: uid)
      .snapshots()
      .listen((snapshot) {
    if (!chatListenerReady) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastMsgTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
        if (lastMsgTime != null) {
          lastNotifiedChatTime[doc.id] = lastMsgTime;
        }
      }
      chatListenerReady = true;
      return;
    }

    // Skip when app is in foreground
    if (isAppInForeground()) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final lastMsgTime = (data?['lastMessageTime'] as Timestamp?)?.toDate();
          if (lastMsgTime != null) {
            lastNotifiedChatTime[change.doc.id] = lastMsgTime;
          }
        }
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.modified) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final roomId = change.doc.id;
      final lastMessage = data['lastMessage'] as String? ?? '';
      final status = data['status'] as String? ?? '';
      final lastMsgTime = (data['lastMessageTime'] as Timestamp?)?.toDate();

      // Skip if user is viewing this chat
      if (roomId == getActiveChatRoomId()) continue;
      if (status == 'closed' || lastMessage.isEmpty || lastMsgTime == null) continue;

      // Dedup
      final prevTime = lastNotifiedChatTime[roomId];
      if (prevTime != null && !lastMsgTime.isAfter(prevTime)) continue;
      lastNotifiedChatTime[roomId] = lastMsgTime;

      // Don't notify for our own messages
      final lastReadBy = data['lastReadBy'] as Map<String, dynamic>? ?? {};
      final ourLastRead = (lastReadBy[uid] as Timestamp?)?.toDate();
      if (ourLastRead != null && !lastMsgTime.isAfter(ourLastRead)) continue;

      // Build notification
      final participantNames = Map<String, String>.from(data['participantNames'] ?? {});
      final isGroup = data['type'] == 'group';

      String senderName;
      if (isGroup) {
        senderName = data['groupTitle'] as String? ?? 'Group Chat';
      } else {
        senderName = 'Someone';
        for (final entry in participantNames.entries) {
          if (entry.key != uid) {
            senderName = entry.value;
            break;
          }
        }
      }

      _showChatNotification(plugin, notificationId++, senderName, lastMessage, isGroup);
    }
  }, onError: (error) {
    // Silently handle errors
  });
}

/// Show a polished ride/activity notification (BigText, brand color, LED)
Future<void> _showRideNotification(
  FlutterLocalNotificationsPlugin plugin,
  int id,
  String title,
  String body,
) async {
  final androidDetails = AndroidNotificationDetails(
    'ryden_activity_v3',
    'Ride Activity',
    channelDescription: 'Ride requests, approvals, and activity alerts',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    color: const Color(_rydenBlue),
    colorized: false,
    subText: 'Ryden',
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: 'Ryden',
    ),
    fullScreenIntent: true,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('ryden_alert'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 250, 150, 250]),
    enableLights: true,
    ledColor: const Color(_rydenBlue),
    ledOnMs: 800,
    ledOffMs: 400,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'ryden_alert.wav',
  );

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
  );
}

/// Show a polished chat notification
Future<void> _showChatNotification(
  FlutterLocalNotificationsPlugin plugin,
  int id,
  String senderName,
  String message,
  bool isGroup,
) async {
  final chatTitle = '💬 $senderName';

  final androidDetails = AndroidNotificationDetails(
    'ryden_chat_v3',
    'Chat Messages',
    channelDescription: 'New messages from your ride chats',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    color: const Color(_rydenBlue),
    subText: isGroup ? 'Group Chat' : 'Chat',
    styleInformation: BigTextStyleInformation(
      message,
      contentTitle: chatTitle,
      summaryText: isGroup ? 'Group Chat' : 'Direct Message',
    ),
    fullScreenIntent: true,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('ryden_alert'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
    ticker: '$senderName: $message',
    enableLights: true,
    ledColor: const Color(_rydenBlue),
    ledOnMs: 800,
    ledOffMs: 400,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'ryden_alert.wav',
  );

  await plugin.show(
    id: id,
    title: chatTitle,
    body: message,
    notificationDetails: NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
  );
}

