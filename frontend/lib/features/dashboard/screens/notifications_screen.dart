import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_invitations_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getNotifications();
      setState(() {
        _notifications = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching notifications: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _markRead(String notifId, String type) async {
    try {
      await _apiService.markNotificationRead(notifId);
      if (type == 'invitation_received' && mounted) {
        // Navigate to team invitations
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TeamInvitationsScreen()),
        ).then((_) => _fetchNotifications());
      } else {
        _fetchNotifications();
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.markAllNotificationsRead();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read"), backgroundColor: AppColors.primary),
      );
      _fetchNotifications();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark all read: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invitation_received':
        return Icons.group_add_rounded;
      case 'request_approved':
      case 'invitation_accepted':
        return Icons.check_circle_outline_rounded;
      case 'request_rejected':
      case 'invitation_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'invitation_received':
        return AppColors.secondary;
      case 'request_approved':
      case 'invitation_accepted':
        return AppColors.primary;
      case 'request_rejected':
      case 'invitation_rejected':
        return AppColors.error;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
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
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final notifId = notif['id'];
                      final title = notif['title'] ?? 'Notification';
                      final message = notif['message'] ?? '';
                      final isRead = notif['is_read'] ?? false;
                      final type = notif['type'] ?? '';
                      final createdAt = notif['created_at'] != null 
                          ? DateTime.parse(notif['created_at']).toLocal() 
                          : DateTime.now();

                      return GestureDetector(
                        onTap: () => _markRead(notifId, type),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
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
                                        Text(
                                          title,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                            color: isRead ? Colors.white70 : Colors.white,
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
                        ),
                      );
                    },
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
