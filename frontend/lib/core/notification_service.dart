import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_details_screen.dart';
import 'package:cricket_scorer/features/tournaments/screens/tournament_details_screen.dart';
import 'package:cricket_scorer/features/matches/screens/match_center_screen.dart';
import 'package:cricket_scorer/features/profile/screens/profile_screen.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("[NotificationService Background] Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ApiService _apiService = ApiService();

  // Local Notifications Plugin
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Streams for UI updates
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // Constants
  static const String channelId = "cricup_default_channel";
  static const String channelName = "CricUP Default Notifications";
  static const String channelDescription = "Handles default notifications for CricUP app";

  // Notification types defined in Phase 4.2.2 requirements
  static const String typeTeamInvite = "TEAM_INVITE";
  static const String typeJoinRequest = "JOIN_REQUEST";
  static const String typeMatchReminder = "MATCH_REMINDER";
  static const String typePlayingXi = "PLAYING_XI";
  static const String typeMatchStarted = "MATCH_STARTED";
  static const String typeMatchFinished = "MATCH_FINISHED";
  static const String typeTournament = "TOURNAMENT";
  static const String typeSystem = "SYSTEM";
  static const String typeAnnouncement = "ANNOUNCEMENT";

  Future<void> initialize() async {
    try {
      // 1. Initialize Firebase Messaging Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Initialize Local Notifications for Foreground display
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android = androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              _handleNotificationTap(data);
            } catch (e) {
              debugPrint("[NotificationService] Error parsing tap payload: $e");
            }
          }
        },
      );

      // 3. Configure Android High Importance Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Request permissions
      await requestPermissions();

      // 5. Handle Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("[NotificationService Foreground] Message received: ${message.messageId}");
        _showForegroundNotification(message);
        refreshUnreadCount();
      });

      // 6. Handle Background/Terminated Click messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("[NotificationService BackgroundClick] Message click: ${message.data}");
        _handleNotificationTap(message.data);
      });

      // Check if app launched from terminated state via notification click
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("[NotificationService TerminatedClick] Initial message: ${initialMessage.data}");
        // Wait slightly for routing/UI to mount before navigation
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // 7. Setup Token Refresh Listener
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        debugPrint("[NotificationService FCM] Token refreshed: $token");
        _registerTokenOnBackend(token);
      });

      // 8. Register initial token if authenticated
      if (ApiService.isAuthenticated) {
        registerCurrentFCMToken();
        refreshUnreadCount();
      }
    } catch (e) {
      debugPrint("[NotificationService] Error initializing NotificationService: $e");
    }
  }

  Future<void> requestPermissions() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint("[NotificationService FCM] Permission status: ${settings.authorizationStatus}");
    } catch (e) {
      debugPrint("[NotificationService] Error requesting notification permissions: $e");
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("[NotificationService] Error getting FCM Token: $e");
      return null;
    }
  }

  Future<void> registerCurrentFCMToken() async {
    final token = await getFCMToken();
    if (token != null) {
      await _registerTokenOnBackend(token);
    }
  }

  Future<void> _registerTokenOnBackend(String token) async {
    if (!ApiService.isAuthenticated) return;
    try {
      final String deviceName = "Android Device"; // Standard platform identifier
      final String platform = "android";
      await _apiService.registerDeviceToken(token, deviceName, platform);
      debugPrint("[NotificationService FCM] Registered FCM Token on Backend successfully.");
    } catch (e) {
      debugPrint("[NotificationService FCM] Failed to register token on backend: $e");
    }
  }

  Future<void> unregisterFCMToken() async {
    try {
      final token = await getFCMToken();
      if (token != null) {
        await _apiService.unregisterDeviceToken(token);
        debugPrint("[NotificationService FCM] Unregistered FCM Token from Backend.");
      }
    } catch (e) {
      debugPrint("[NotificationService FCM] Failed to unregister token: $e");
    }
  }

  Future<void> refreshUnreadCount() async {
    if (!ApiService.isAuthenticated) return;
    try {
      final res = await _apiService.getNotifications();
      final List<dynamic> notifs = res.data as List<dynamic>? ?? [];
      final count = notifs.where((n) => n['is_read'] == false).length;
      _updateUnreadCount(count);
    } catch (e) {
      debugPrint("[NotificationService] Failed to refresh unread count: $e");
    }
  }

  void _updateUnreadCount(int count) {
    _unreadCount = count;
    _unreadCountController.add(_unreadCount);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android = androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint("[NotificationService Tap] Actioning payload: $data");
    
    // Deep Link Navigation logic based on Phase 4.2.2 specifications: Match, Team, Tournament, Profile, details
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint("[NotificationService Navigation] Navigator Context is not mounted yet.");
      return;
    }

    try {
      final String? type = data['type']?.toString().toUpperCase();
      
      // Determine screen routing
      if (type == typeTeamInvite || type == typeJoinRequest || data.containsKey('team_id')) {
        final teamId = data['team_id']?.toString();
        final teamName = data['team_name']?.toString() ?? "Team Info";
        if (teamId != null && teamId.isNotEmpty) {
          // Route to TeamDetailsScreen
          _safeNavigate(
            context,
            "/team-details",
            data: {
              'teamId': teamId,
              'teamName': teamName,
              'userRole': 'player',
            },
          );
        }
      } else if (type == typeTournament || data.containsKey('tournament_id')) {
        final tournamentId = data['tournament_id']?.toString();
        final tournamentName = data['tournament_name']?.toString() ?? "Tournament Info";
        if (tournamentId != null && tournamentId.isNotEmpty) {
          // Route to TournamentDetailsScreen
          _safeNavigate(
            context,
            "/tournament-details",
            data: {
              'tournamentId': tournamentId,
              'tournamentName': tournamentName,
            },
          );
        }
      } else if (type == typeMatchStarted || type == typeMatchFinished || type == typeMatchReminder || type == typePlayingXi || data.containsKey('match_id')) {
        final matchId = data['match_id']?.toString();
        if (matchId != null && matchId.isNotEmpty) {
          // Route to MatchCenterScreen
          _safeNavigate(
            context,
            "/match-center",
            data: {
              'matchId': matchId,
            },
          );
        }
      } else if (data.containsKey('public_id') || data.containsKey('user_id')) {
        final publicId = data['public_id']?.toString() ?? data['user_id']?.toString();
        if (publicId != null && publicId.isNotEmpty) {
          // Route to ProfileScreen
          _safeNavigate(
            context,
            "/profile",
            data: {
              'publicId': publicId,
            },
          );
        }
      } else {
        // Fallback: Navigation to general Notification Details or Refresh Dashboard
        refreshUnreadCount();
      }
    } catch (e) {
      debugPrint("[NotificationService Navigation Error] failed to route: $e");
    }
  }

  void _safeNavigate(BuildContext context, String route, {required Map<String, dynamic> data}) {
    Widget? screen;
    
    if (route == "/team-details") {
      screen = TeamDetailsScreen(
        teamId: data['teamId'],
        teamName: data['teamName'],
        userRole: data['userRole'] ?? 'player',
      );
    } else if (route == "/tournament-details") {
      screen = TournamentDetailsScreen(
        tournamentId: data['tournamentId'],
        tournamentName: data['tournamentName'],
      );
    } else if (route == "/match-center") {
      screen = MatchCenterScreen(
        matchId: data['matchId'],
      );
    } else if (route == "/profile") {
      screen = ProfileScreen(
        publicId: data['publicId'],
      );
    }

    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }
}
