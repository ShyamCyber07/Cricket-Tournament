import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'package:cricket_scorer/core/widgets/reusable_error.dart';
import 'package:cricket_scorer/core/widgets/reusable_empty.dart';

class TeamHistoryScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamHistoryScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamHistoryScreen> createState() => _TeamHistoryScreenState();
}

class _TeamHistoryScreenState extends State<TeamHistoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isInvitesLoading = false;
  bool _isRequestsLoading = false;
  dynamic _invitesError;
  dynamic _requestsError;

  List<dynamic> _invitations = [];
  List<dynamic> _joinRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvitations();
    _loadJoinRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isInvitesLoading = true;
      _invitesError = null;
    });
    try {
      final res = await _apiService.getTeamInvitationsHistory(widget.teamId);
      setState(() {
        _invitations = res.data;
      });
    } catch (e) {
      setState(() {
        _invitesError = e;
      });
    } finally {
      setState(() {
        _isInvitesLoading = false;
      });
    }
  }

  Future<void> _loadJoinRequests() async {
    setState(() {
      _isRequestsLoading = true;
      _requestsError = null;
    });
    try {
      final res = await _apiService.getTeamJoinRequestsHistory(widget.teamId);
      setState(() {
        _joinRequests = res.data;
      });
    } catch (e) {
      setState(() {
        _requestsError = e;
      });
    } finally {
      setState(() {
        _isRequestsLoading = false;
      });
    }
  }

  String _formatDateTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'approved':
      case 'active':
        return AppColors.primary;
      case 'pending':
        return AppColors.accent;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
      case 'withdrawn':
      case 'expired':
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Audit History"),
            Text(
              widget.teamName,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline_rounded), text: "Sent Invites"),
            Tab(icon: Icon(Icons.assignment_ind_outlined), text: "Join Requests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvitationsList(),
          _buildJoinRequestsList(),
        ],
      ),
    );
  }

  Widget _buildInvitationsList() {
    if (_isInvitesLoading) return const Center(child: ListLoader());
    if (_invitesError != null) {
      return ErrorDisplayWidget(
        error: _invitesError,
        onRetry: _loadInvitations,
      );
    }
    if (_invitations.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_toggle_off_rounded,
        title: "No Invite History",
        description: "You haven't sent any invitations to players for this team yet.",
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitations,
      child: ListView.builder(
        itemCount: _invitations.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final inv = _invitations[index];
          final status = (inv['status'] ?? 'pending').toString().toUpperCase();
          final invitedBy = inv['invited_by_name'] ?? 'Captain';
          final dateStr = _formatDateTime(inv['created_at']);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: AppColors.glassDecoration(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(inv['status']).withOpacity(0.08),
                  child: Icon(Icons.mail_rounded, color: _getStatusColor(inv['status'])),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['user_name'] ?? 'Player',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Invited by $invitedBy",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(inv['status']).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(inv['status']).withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(inv['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinRequestsList() {
    if (_isRequestsLoading) return const Center(child: ListLoader());
    if (_requestsError != null) {
      return ErrorDisplayWidget(
        error: _requestsError,
        onRetry: _loadJoinRequests,
      );
    }
    if (_joinRequests.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_toggle_off_rounded,
        title: "No Join Requests",
        description: "No players have requested to join your team yet.",
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJoinRequests,
      child: ListView.builder(
        itemCount: _joinRequests.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final req = _joinRequests[index];
          final status = (req['status'] ?? 'pending').toString().toUpperCase();
          final dateStr = _formatDateTime(req['created_at']);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: AppColors.glassDecoration(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(req['status']).withOpacity(0.08),
                  child: Icon(Icons.assignment_ind_rounded, color: _getStatusColor(req['status'])),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['user_name'] ?? 'Player',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Requested to join",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(req['status']).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(req['status']).withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(req['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
