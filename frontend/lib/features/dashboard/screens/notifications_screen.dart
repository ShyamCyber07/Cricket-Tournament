import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_details_screen.dart';
import 'package:cricket_scorer/core/event_bus.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _notifications = [];
  String _selectedCategory = "All";
  final Set<String> _processingNotifIds = {};
  final Set<String> _processedNotifIds = {};
  StreamSubscription? _eventSubscription;
  
  // Pagination variables
  int _skip = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    
    // Setup scroll controller for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore) {
          _loadMoreNotifications();
        }
      }
    });

    _eventSubscription = AppEventBus().on.listen((event) {
      if (event is NotificationRefreshedEvent) {
        _fetchNotificationsQuietly();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotificationsQuietly() async {
    try {
      final res = await _apiService.getNotifications(limit: _limit, skip: 0);
      if (mounted) {
        setState(() {
          _notifications = res.data;
          _skip = res.data.length;
          _hasMore = res.data.length >= _limit;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _skip = 0;
      _hasMore = true;
    });
    try {
      final res = await _apiService.getNotifications(limit: _limit, skip: 0);
      setState(() {
        _notifications = res.data;
        _isLoading = false;
        _skip = res.data.length;
        _hasMore = res.data.length >= _limit;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching notifications: $e", AppColors.error);
    }
  }

  Future<void> _loadMoreNotifications() async {
    setState(() => _isLoadingMore = true);
    try {
      final res = await _apiService.getNotifications(limit: _limit, skip: _skip);
      final List<dynamic> newNotifs = res.data as List<dynamic>? ?? [];
      setState(() {
        _notifications.addAll(newNotifs);
        _isLoadingMore = false;
        _skip += newNotifs.length;
        _hasMore = newNotifs.length >= _limit;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
      debugPrint("[NotificationsScreen] Failed to load more: $e");
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleNotificationTap(String notifId, String type, String? teamId) async {
    try {
      await _apiService.markNotificationRead(notifId);
    } catch (_) {}

    if (!mounted) return;

    if (teamId != null && teamId.isNotEmpty) {
      // Deep link to team details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeamDetailsScreen(
            teamId: teamId,
            teamName: "Team Details",
            userRole: "player",
          ),
        ),
      ).then((_) => _fetchNotifications());
    } else {
      _fetchNotifications();
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.markAllNotificationsRead();
      _showSnackBar("All notifications marked as read", AppColors.primary);
      _fetchNotifications();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to mark all read: $e", AppColors.error);
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    try {
      await _apiService.deleteNotification(notifId);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notifId);
      });
      _showSnackBar("Notification deleted", Colors.white60);
    } catch (e) {
      _showSnackBar("Failed to delete notification: $e", AppColors.error);
    }
  }

  String _getCategoryForType(String type) {
    type = type.toLowerCase();
    if (type.contains('team') || type.contains('invitation') || type.contains('request') || type.contains('captain') || type.contains('member')) {
      return 'Team';
    } else if (type.contains('tournament')) {
      return 'Tournament';
    } else if (type.contains('match') || type.contains('score')) {
      return 'Match';
    } else if (type.contains('admin') || type.contains('report')) {
      return 'Admin';
    } else {
      return 'Account';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invitation_received':
      case 'join_request_sent':
        return Icons.group_add_rounded;
      case 'request_approved':
      case 'invitation_accepted':
      case 'captain_changed':
      case 'vice_captain_assigned':
        return Icons.check_circle_outline_rounded;
      case 'request_rejected':
      case 'invitation_rejected':
      case 'member_left':
      case 'member_removed':
      case 'join_request_cancelled':
      case 'vice_captain_removed':
      case 'team_deleted':
        return Icons.cancel_outlined;
      case 'team_updated':
        return Icons.info_outline_rounded;
      default:
        final cat = _getCategoryForType(type);
        if (cat == 'Tournament') return Icons.emoji_events_rounded;
        if (cat == 'Match') return Icons.sports_cricket_rounded;
        if (cat == 'Admin') return Icons.admin_panel_settings_rounded;
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'invitation_received':
      case 'join_request_sent':
      case 'vice_captain_assigned':
        return AppColors.secondary;
      case 'request_approved':
      case 'invitation_accepted':
      case 'captain_changed':
        return AppColors.primary;
      case 'request_rejected':
      case 'invitation_rejected':
      case 'member_left':
      case 'member_removed':
      case 'join_request_cancelled':
      case 'vice_captain_removed':
      case 'team_deleted':
        return AppColors.error;
      default:
        final cat = _getCategoryForType(type);
        if (cat == 'Tournament') return Colors.amber;
        if (cat == 'Match') return Colors.greenAccent;
        if (cat == 'Admin') return Colors.purpleAccent;
        return Colors.white70;
    }
  }

  Map<String, List<dynamic>> _groupNotifications(List<dynamic> list) {
    final groups = <String, List<dynamic>>{
      "Today": [],
      "Yesterday": [],
      "Older": [],
    };
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    for (final item in list) {
      if (item['created_at'] == null) {
        groups["Older"]!.add(item);
        continue;
      }
      
      final dt = DateTime.parse(item['created_at']).toLocal();
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      
      if (dateOnly.isAtSameMomentAs(today)) {
        groups["Today"]!.add(item);
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        groups["Yesterday"]!.add(item);
      } else {
        groups["Older"]!.add(item);
      }
    }
    
    return groups;
  }

  Widget _buildCategoryChips() {
    final categories = ["All", "Team", "Tournament", "Match", "Account", "Admin"];
    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withOpacity(0.05),
              checkmarkColor: Colors.black,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifs = _selectedCategory == "All"
        ? _notifications
        : _notifications.where((n) => _getCategoryForType(n['type'] ?? '') == _selectedCategory).toList();

    final groupedNotifs = _groupNotifications(filteredNotifs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (filteredNotifs.any((n) => n['is_read'] == false))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
              label: Text(
                "Mark all read",
                style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: NeonBallOrbitLoader())
                  : filteredNotifs.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          children: [
                            if (groupedNotifs["Today"]!.isNotEmpty) ...[
                              _buildGroupHeader("Today"),
                              ...groupedNotifs["Today"]!.map((n) => _buildDismissibleNotificationCard(n)),
                            ],
                            if (groupedNotifs["Yesterday"]!.isNotEmpty) ...[
                              _buildGroupHeader("Yesterday"),
                              ...groupedNotifs["Yesterday"]!.map((n) => _buildDismissibleNotificationCard(n)),
                            ],
                            if (groupedNotifs["Older"]!.isNotEmpty) ...[
                              _buildGroupHeader("Older"),
                              ...groupedNotifs["Older"]!.map((n) => _buildDismissibleNotificationCard(n)),
                            ],
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDismissibleNotificationCard(dynamic notif) {
    final notifId = notif['id'].toString();
    return Dismissible(
      key: Key(notifId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(notifId),
      child: _buildNotificationCard(notif),
    );
  }

  Widget _buildNotificationCard(dynamic notif) {
    final notifId = notif['id'];
    final title = notif['title'] ?? 'Notification';
    final message = notif['message'] ?? '';
    final isRead = notif['is_read'] ?? false;
    final type = notif['type'] ?? '';
    final createdAt = notif['created_at'] != null 
        ? DateTime.parse(notif['created_at']).toLocal() 
        : DateTime.now();

    final String? extraDataStr = notif['extra_data'];
    String? teamId;
    String? requestUserId;
    if (extraDataStr != null) {
      try {
        final Map<String, dynamic> extraData = jsonDecode(extraDataStr);
        teamId = extraData['team_id'];
        requestUserId = extraData['user_id'];
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(16),
        borderColor: isRead 
            ? Colors.white.withOpacity(0.08) 
            : AppColors.primary.withOpacity(0.3),
      ).copyWith(
        color: isRead 
            ? Colors.white.withOpacity(0.02) 
            : AppColors.primary.withOpacity(0.05),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notifId, type, teamId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorForType(type).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(type),
                          color: _getColorForType(type),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: isRead ? Colors.white70 : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: isRead ? AppColors.textSecondary : const Color(0xFFE8E8E8),
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatTimeAgo(createdAt),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((type == 'join_request_sent' || type == 'invitation_received') &&
                      teamId != null &&
                      !isRead &&
                      !_processedNotifIds.contains(notifId)) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _processingNotifIds.contains(notifId) || _processedNotifIds.contains(notifId)
                              ? null
                              : () async {
                                  setState(() {
                                    _processingNotifIds.add(notifId);
                                  });
                                  
                                  dynamic removedNotif;
                                  int removedIndex = -1;
                                  for (int i = 0; i < _notifications.length; i++) {
                                    if (_notifications[i]['id']?.toString() == notifId.toString()) {
                                      removedNotif = _notifications[i];
                                      removedIndex = i;
                                      break;
                                    }
                                  }
                                  if (removedIndex != -1) {
                                    setState(() {
                                      _notifications.removeAt(removedIndex);
                                    });
                                  }
                                  
                                  try {
                                    if (type == 'join_request_sent') {
                                      await _apiService.rejectJoinRequest(teamId!, requestUserId!);
                                      _showSnackBar("Join request rejected.", AppColors.textSecondary);
                                    } else {
                                      await _apiService.rejectInvitation(teamId!);
                                      _showSnackBar("Invitation rejected.", AppColors.textSecondary);
                                    }
                                    await _apiService.markNotificationRead(notifId);
                                    setState(() {
                                      _processedNotifIds.add(notifId);
                                    });
                                    AppEventBus().fire(NotificationRefreshedEvent());
                                    AppEventBus().fire(TeamRefreshedEvent());
                                  } catch (e) {
                                    if (removedIndex != -1 && removedNotif != null) {
                                      setState(() {
                                        _notifications.insert(removedIndex, removedNotif);
                                      });
                                    }
                                    _showSnackBar("Action failed: $e", AppColors.error);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _processingNotifIds.remove(notifId);
                                      });
                                    }
                                  }
                                },
                          child: Text(
                            type == 'join_request_sent' ? "Reject" : "Decline",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _processingNotifIds.contains(notifId) || _processedNotifIds.contains(notifId)
                              ? null
                              : () async {
                                  setState(() {
                                    _processingNotifIds.add(notifId);
                                  });
                                  
                                  dynamic removedNotif;
                                  int removedIndex = -1;
                                  for (int i = 0; i < _notifications.length; i++) {
                                    if (_notifications[i]['id']?.toString() == notifId.toString()) {
                                      removedNotif = _notifications[i];
                                      removedIndex = i;
                                      break;
                                    }
                                  }
                                  if (removedIndex != -1) {
                                    setState(() {
                                      _notifications.removeAt(removedIndex);
                                    });
                                  }
                                  
                                  try {
                                    if (type == 'join_request_sent') {
                                      await _apiService.approveJoinRequest(teamId!, requestUserId!);
                                      _showSnackBar("Join request approved!", AppColors.primary);
                                    } else {
                                      await _apiService.acceptInvitation(teamId!);
                                      _showSnackBar("Invitation accepted!", AppColors.primary);
                                    }
                                    await _apiService.markNotificationRead(notifId);
                                    setState(() {
                                      _processedNotifIds.add(notifId);
                                    });
                                    AppEventBus().fire(NotificationRefreshedEvent());
                                    AppEventBus().fire(TeamRefreshedEvent());
                                  } catch (e) {
                                    if (removedIndex != -1 && removedNotif != null) {
                                      setState(() {
                                        _notifications.insert(removedIndex, removedNotif);
                                      });
                                    }
                                    _showSnackBar("Action failed: $e", AppColors.error);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _processingNotifIds.remove(notifId);
                                      });
                                    }
                                  }
                                },
                          child: Text(
                            type == 'join_request_sent' ? "Approve" : "Accept",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return "${diff.inDays}d ago";
    } else if (diff.inHours > 0) {
      return "${diff.inHours}h ago";
    } else if (diff.inMinutes > 0) {
      return "${diff.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "All Caught Up!",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "You don't have any notifications right now.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}