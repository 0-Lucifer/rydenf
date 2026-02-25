import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton service for local push notifications.
/// Listens to Firestore `notifications` and `chat_rooms` for real-time phone alerts.
/// Notifications appear as heads-up pop-ups (like SMS) on both Android and iOS.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription? _notificationSub;
  StreamSubscription? _chatSub;
  bool _initialized = false;
  int _notificationId = 0;
  String? _activeChatRoomId;

  // Deduplication: track IDs we've already shown notifications for
  final Set<String> _shownNotificationIds = {};
  // Track last message time per room to avoid duplicate chat notifications
  final Map<String, DateTime> _lastNotifiedMessageTime = {};
  // Skip the initial snapshot load
  bool _notificationListenerReady = false;
  bool _chatListenerReady = false;

  /// Initialize the plugin (call once in main.dart)
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;

    // Request permissions on iOS
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request permissions on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Show a pop-up notification (heads-up, like SMS)
  Future<void> show({
    required String title,
    required String body,
    String channelId = 'ryden_activity',
    String channelName = 'Ride Activity',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ride requests, approvals, and activity alerts',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // Pop-up style: full-screen intent behavior for heads-up
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      ticker: title,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: _notificationId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Call when user enters a chat screen (suppresses notifications for that room)
  void setActiveChatRoom(String? roomId) {
    _activeChatRoomId = roomId;
  }

  /// Start listening for new Firestore notifications AND chat messages
  void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Cancel any previous listeners and reset state
    _notificationSub?.cancel();
    _chatSub?.cancel();
    _notificationListenerReady = false;
    _chatListenerReady = false;
    _shownNotificationIds.clear();
    _lastNotifiedMessageTime.clear();

    // ─── Listener 1: General notifications (rides, groups, approvals) ───
    // Simple query: only filter by userId — avoids composite index requirement.
    // Client-side filtering handles isRead.
    _notificationSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (!_notificationListenerReady) {
        // First snapshot = existing data. Just record IDs, don't notify.
        for (final doc in snapshot.docs) {
          _shownNotificationIds.add(doc.id);
        }
        _notificationListenerReady = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          // Skip if we already showed this one
          if (_shownNotificationIds.contains(docId)) continue;
          _shownNotificationIds.add(docId);

          final data = change.doc.data();
          if (data != null) {
            // Skip already-read notifications
            if (data['isRead'] == true) continue;

            final title = data['title'] as String? ?? '';
            final body = data['body'] as String? ?? '';
            if (title.isNotEmpty) {
              show(
                title: title,
                body: body,
                channelId: 'ryden_activity',
                channelName: 'Ride Activity',
              );
            }
          }
        }
      }
    }, onError: (error) {
      print('[LocalNotificationService] Notification listener error: $error');
    });

    // ─── Listener 2: Chat messages ───
    _chatSub = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      if (!_chatListenerReady) {
        // First snapshot = existing data. Record last message times.
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final lastMsgTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
          if (lastMsgTime != null) {
            _lastNotifiedMessageTime[doc.id] = lastMsgTime;
          }
        }
        _chatListenerReady = true;
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
        if (roomId == _activeChatRoomId) continue;
        // Skip closed/empty
        if (status == 'closed' || lastMessage.isEmpty || lastMsgTime == null) continue;

        // Skip if we already notified for this timestamp (dedup)
        final prevTime = _lastNotifiedMessageTime[roomId];
        if (prevTime != null && !lastMsgTime.isAfter(prevTime)) continue;

        // Update tracked time
        _lastNotifiedMessageTime[roomId] = lastMsgTime;

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

        show(
          title: '💬 $senderName',
          body: lastMessage,
          channelId: 'ryden_chat',
          channelName: 'Chat Messages',
        );
      }
    }, onError: (error) {
      print('[LocalNotificationService] Chat listener error: $error');
    });
  }

  /// Stop listening (call on logout)
  void stopListening() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _chatSub?.cancel();
    _chatSub = null;
    _activeChatRoomId = null;
    _shownNotificationIds.clear();
    _lastNotifiedMessageTime.clear();
    _notificationListenerReady = false;
    _chatListenerReady = false;
  }
}
