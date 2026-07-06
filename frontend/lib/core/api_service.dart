import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';

class ApiService {
  final Dio _dio = Dio();
  static String? _token;
  static String? _refreshToken;
  static const String _tokenKey = "jwt_auth_token";
  static const String _refreshTokenKey = "jwt_refresh_token";
  static final StreamController<String?> onUnauthorized = StreamController<String?>.broadcast();

  ApiService() {
    _dio.options.baseUrl = AppConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Inject logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print("[Dio Request] => Method: ${options.method} | URL: ${options.baseUrl}${options.path}");
          print("[Dio Request Headers] => ${options.headers}");
          if (options.data != null) {
            print("[Dio Request Data] => ${options.data}");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print("[Dio Response] <= Status: ${response.statusCode} | URL: ${response.requestOptions.baseUrl}${response.requestOptions.path}");
          print("[Dio Response Data] <= ${response.data}");
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          final req = e.requestOptions;
          final resp = e.response;
          
          print("================== [CRITICAL CONNECTION DIAGNOSTICS] ==================");
          print("Request URL: ${req.baseUrl}${req.path}");
          print("Method: ${req.method}");
          print("Status Code: ${resp?.statusCode}");
          print("Response Body: ${resp?.data}");
          print("DioException Type: ${e.type}");
          print("Inner Exception: ${e.error}");
          print("Inner Exception Type: ${e.error?.runtimeType}");
          print("Message: ${e.message}");
          print("Stacktrace: ${e.stackTrace}");
          
          String category = "Unknown/Other Error";
          if (e.error is SocketException) {
            category = "SocketException (No connection / Network Down / DNS failure / Connection refused)";
          } else if (e.error is TimeoutException) {
            category = "TimeoutException";
          } else if (e.type == DioExceptionType.connectionTimeout) {
            category = "DioException.connectionTimeout";
          } else if (e.type == DioExceptionType.receiveTimeout) {
            category = "DioException.receiveTimeout";
          } else if (e.type == DioExceptionType.badResponse) {
            category = "DioException.badResponse (HTTP ${resp?.statusCode})";
            if (resp?.statusCode == 401) category = "HTTP 401 Unauthorized";
            if (resp?.statusCode == 403) category = "HTTP 403 Forbidden";
            if (resp?.statusCode == 404) category = "HTTP 404 Not Found";
            if (resp?.statusCode == 500) category = "HTTP 500 Internal Server Error";
          } else if (e.type == DioExceptionType.connectionError) {
            category = "DioException.connectionError (Connection refused or network issue)";
          }
          
          print("CLASSIFIED ERROR: $category");
          print("=======================================================================");
          
          final friendlyMessage = _getFriendlyMessage(e);
          if (resp != null) {
            resp.data = {
              'detail': friendlyMessage,
              'message': friendlyMessage,
            };
          }
          final customException = UserFriendlyDioException(
            requestOptions: e.requestOptions,
            response: resp,
            type: e.type,
            error: e.error,
            stackTrace: e.stackTrace,
            friendlyMessage: friendlyMessage,
          );
          return handler.next(customException);
        },
      ),
    );

    // Inject Auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers["Authorization"] = "Bearer $_token";
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Global 401 error handling with token refresh
          if (e.response?.statusCode == 401) {
            final path = e.requestOptions.path;
            final isAuthRoute = path.contains('/auth/logout') || path.contains('/auth/refresh') || path.contains('/auth/login');
            
            String? reason;
            if (e.response?.data is Map) {
              reason = e.response!.data['detail']?.toString();
            }

            if (_refreshToken != null && !isAuthRoute) {
              try {
                print("[Dio Interceptor] Access token expired, attempting refresh...");
                final refreshDio = Dio();
                refreshDio.options.baseUrl = AppConfig.baseUrl;
                refreshDio.options.connectTimeout = const Duration(seconds: 5);
                refreshDio.options.receiveTimeout = const Duration(seconds: 5);
                final refreshRes = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refresh_token': _refreshToken},
                );
                if (refreshRes.statusCode == 200) {
                  final newAccessToken = refreshRes.data['access_token'];
                  final newRefreshToken = refreshRes.data['refresh_token'];
                  print("[Dio Interceptor] Token refresh successful. Retrying original request...");
                  await persistToken(newAccessToken, newRefreshToken);
                  
                  // Retry the original request
                  final options = e.requestOptions;
                  options.headers["Authorization"] = "Bearer $newAccessToken";
                  
                  final cloneResponse = await _dio.fetch(options);
                  return handler.resolve(cloneResponse);
                }
              } catch (refreshErr) {
                print("[Dio Interceptor] Token refresh failed: $refreshErr. Clearing credentials.");
                await clearToken();
                if (!isAuthRoute) onUnauthorized.add(reason);
              }
            } else {
              await clearToken();
              if (!isAuthRoute) onUnauthorized.add(reason);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  static Future<void> loadPersistedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
    } catch (_) {
      _token = null;
      _refreshToken = null;
    }
  }

  static Future<void> persistToken(String token, [String? refreshToken]) async {
    _token = token;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {}
  }

  static void setToken(String? token) {
    _token = token;
    if (token == null) {
      clearToken();
    } else {
      persistToken(token);
    }
  }

  static bool get isAuthenticated => _token != null;

  // AUTH ENDPOINTS
  Future<Response> login(String email, String password) async {
    final formData = FormData.fromMap({
      'username': email,
      'password': password,
    });
    final response = await _dio.post('/auth/login', data: formData);
    if (response.statusCode == 200) {
      await persistToken(response.data['access_token'], response.data['refresh_token']);
    }
    return response;
  }

  Future<Response> signup(String email, String password, String username, String confirmPassword) async {
    final fullUrl = "${_dio.options.baseUrl}/auth/signup";
    final requestBody = {
      'username': username,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    };
    print("[DIAGNOSTICS] Signup Request Starting");
    print("[DIAGNOSTICS] Full URL: $fullUrl");
    print("[DIAGNOSTICS] Request Body: $requestBody");
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: requestBody,
      );
      print("[DIAGNOSTICS] Signup Response Status Code: ${response.statusCode}");
      print("[DIAGNOSTICS] Signup Response Body: ${response.data}");
      return response;
    } catch (e, stackTrace) {
      print("[DIAGNOSTICS] Signup Error Encountered: $e");
      if (e is DioException) {
        print("[DIAGNOSTICS] Signup DioException Details:");
        print("[DIAGNOSTICS]   Response Status Code: ${e.response?.statusCode}");
        print("[DIAGNOSTICS]   Response Body: ${e.response?.data}");
        print("[DIAGNOSTICS]   Error Type: ${e.type}");
        print("[DIAGNOSTICS]   Message: ${e.message}");
      }
      print("[DIAGNOSTICS] Signup Error StackTrace:\n$stackTrace");
      rethrow;
    }
  }

  Future<Response> verifyOtp(String email, String otpCode) async {
    final response = await _dio.post(
      '/auth/verify-otp',
      data: {
        'email': email,
        'otp_code': otpCode,
      },
    );
    if (response.statusCode == 200) {
      await persistToken(response.data['access_token'], response.data['refresh_token']);
    }
    return response;
  }

  Future<Response> resendOtp(String email) async {
    return await _dio.post(
      '/auth/resend-otp',
      data: {
        'email': email,
      },
    );
  }

  Future<Response> forgotPassword(String email) async {
    return await _dio.post(
      '/auth/forgot-password',
      data: {
        'email': email,
      },
    );
  }

  Future<Response> verifyResetOtp(String email, String otpCode) async {
    return await _dio.post(
      '/auth/verify-reset-otp',
      data: {
        'email': email,
        'otp_code': otpCode,
      },
    );
  }

  Future<Response> resetPassword(String email, String otpCode, String newPassword, String confirmPassword) async {
    return await _dio.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'otp_code': otpCode,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }

  Future<Response> completeProfile(
    String fullName,
    String displayName, {
    String? username,
    String? role,
    String? profilePicture,
    String? country,
    String? favoriteTeam,
  }) async {
    return await _dio.post(
      '/auth/complete-profile',
      data: {
        'full_name': fullName,
        'display_name': displayName,
        if (username != null) 'username': username,
        if (role != null) 'role': role,
        if (profilePicture != null) 'profile_picture': profilePicture,
        if (country != null) 'country': country,
        if (favoriteTeam != null) 'favorite_team': favoriteTeam,
      },
    );
  }

  Future<Response> loginWithGoogle(String googleToken) async {
    final response = await _dio.post(
      '/auth/google',
      data: {'token': googleToken},
    );
    if (response.statusCode == 200) {
      await persistToken(response.data['access_token'], response.data['refresh_token']);
    }
    return response;
  }

  Future<Response> getMe() async {
    print("[FRONTEND VERIFICATION] Access Token: $_token");
    print("[FRONTEND VERIFICATION] Refresh Token: $_refreshToken");
    print("[FRONTEND VERIFICATION] Authorization Header: Bearer $_token");
    return await _dio.get('/auth/me');
  }

  Future<Response> logout() async {
    final response = await _dio.post('/auth/logout');
    await clearToken();
    return response;
  }

  // PROFILE ENDPOINTS
  Future<Response> getProfile() async {
    return await _dio.get('/profile/');
  }

  Future<Response> updateProfile({
    required String fullName,
    required String username,
    String? bio,
    String? profilePicture,
    String? profilePhotoUrl,
    String? phoneNumber,
    String? city,
    String? dob,
    String? battingStyle,
    String? bowlingStyle,
    String? playerType,
    String? dominantHand,
    int? defaultJerseyNumber,
    String? privacySettings,
  }) async {
    return await _dio.put(
      '/profile/',
      data: {
        'full_name': fullName,
        'username': username,
        if (bio != null) 'bio': bio,
        if (profilePicture != null) 'profile_picture': profilePicture,
        if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (city != null) 'city': city,
        if (dob != null) 'dob': dob,
        if (battingStyle != null) 'batting_style': battingStyle,
        if (bowlingStyle != null) 'bowling_style': bowlingStyle,
        if (playerType != null) 'player_type': playerType,
        if (dominantHand != null) 'dominant_hand': dominantHand,
        if (defaultJerseyNumber != null) 'default_jersey_number': defaultJerseyNumber,
        if (privacySettings != null) 'privacy_settings': privacySettings,
      },
    );
  }

  Future<Response> getPublicProfile(String identifier) async {
    return await _dio.get('/profile/public/$identifier');
  }

  Future<Response> searchPlayers(String query) async {
    return await _dio.get('/profile/search', queryParameters: {'query': query});
  }

  Future<Response> joinTeamByCode(String teamCode) async {
    return await _dio.post(
      '/teams/join-by-code',
      data: {'team_code': teamCode},
    );
  }

  Future<Response> regenerateTeamCode(String teamId) async {
    return await _dio.post('/teams/$teamId/regenerate-code');
  }

  Future<Response> uploadProfilePhoto(String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
    return await _dio.post('/profile/upload-photo', data: formData);
  }

  Future<Response> uploadTeamLogo(String teamId, String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
    return await _dio.post('/teams/$teamId/upload-logo', data: formData);
  }

  Future<Response> deleteTeamLogo(String teamId) async {
    return await _dio.delete('/teams/$teamId/logo');
  }

  Future<Response> uploadTournamentLogo(String tournamentId, String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
    return await _dio.post('/tournaments/$tournamentId/upload-logo', data: formData);
  }

  Future<Response> getProfileStats() async {
    return await _dio.get('/profile/stats');
  }

  Future<Response> getProfileActivity() async {
    return await _dio.get('/profile/activity');
  }

  Future<Response> getProfileAchievements() async {
    return await _dio.get('/profile/achievements');
  }

  // PLAYERS
  Future<Response> getPlayers({String? search, bool includeAssigned = false}) async {
    final Map<String, dynamic> query = {};
    if (search != null) query['search'] = search;
    if (includeAssigned) query['include_assigned'] = 'true';
    return await _dio.get('/players/', queryParameters: query.isNotEmpty ? query : null);
  }

  Future<Response> getPlayerStats(String id) async {
    return await _dio.get('/players/$id/stats');
  }

  Future<Response> createPlayer(String name, String role, String batting, String bowling, {int? jerseyNumber}) async {
    return await _dio.post(
      '/players/',
      data: {
        'name': name,
        'role': role,
        'batting_style': batting,
        'bowling_style': bowling,
        if (jerseyNumber != null) 'jersey_number': jerseyNumber,
      },
    );
  }

  Future<Response> updatePlayer(String id, String name, String role, String batting, String bowling, {int? jerseyNumber}) async {
    return await _dio.put(
      '/players/$id',
      data: {
        'name': name,
        'role': role,
        'batting_style': batting,
        'bowling_style': bowling,
        'jersey_number': jerseyNumber,
      },
    );
  }

  Future<Response> deletePlayer(String id) async {
    return await _dio.delete('/players/$id');
  }

  // TEAMS
  Future<Response> createTeam(String name, {String? captainId}) async {
    return await _dio.post(
      '/teams/',
      data: {
        'name': name,
        'captain_id': captainId,
      },
    );
  }

  Future<Response> getTeams() async {
    return await _dio.get('/teams/');
  }

  Future<Response> getTeam(String teamId) async {
    return await _dio.get('/teams/$teamId');
  }

  Future<Response> addPlayerToTeam(String teamId, String playerId) async {
    return await _dio.post(
      '/teams/$teamId/players',
      data: {'player_id': playerId},
    );
  }

  Future<Response> removePlayerFromTeam(String teamId, String playerId) async {
    return await _dio.delete('/teams/$teamId/players/$playerId');
  }

  Future<Response> addPlayersToTeamBulk(String teamId, List<String> playerIds) async {
    return await _dio.post(
      '/teams/$teamId/players/bulk',
      data: {
        'player_ids': playerIds,
      },
    );
  }

  Future<Response> updateTeam(String id, String name, {
    String? captainId,
    String? description,
    String? homeGround,
    String? city,
    String? teamMotto,
    int? foundedYear,
  }) async {
    return await _dio.put(
      '/teams/$id',
      data: {
        'name': name,
        if (captainId != null) 'captain_id': captainId,
        if (description != null) 'description': description,
        if (homeGround != null) 'home_ground': homeGround,
        if (city != null) 'city': city,
        if (teamMotto != null) 'team_motto': teamMotto,
        if (foundedYear != null) 'founded_year': foundedYear,
      },
    );
  }

  Future<Response> deleteTeam(String id) async {
    return await _dio.delete('/teams/$id');
  }

  Future<Response> getTeamStats(String teamId) async {
    return await _dio.get('/teams/$teamId/stats');
  }

  Future<Response> getMyTeams() async {
    return await _dio.get('/teams/my-teams');
  }

  Future<Response> getTeamMembers(String teamId) async {
    return await _dio.get('/teams/$teamId/members');
  }

  Future<Response> addTeamMember(String teamId, String email) async {
    return await _dio.post(
      '/teams/$teamId/members',
      data: {'email': email},
    );
  }

  Future<Response> removeTeamMember(String teamId, String userId) async {
    return await _dio.delete('/teams/$teamId/members/$userId');
  }

  Future<Response> updateMemberRole(String teamId, String userId, String role) async {
    return await _dio.put(
      '/teams/$teamId/members/$userId/role',
      data: {'role': role},
    );
  }

  Future<Response> joinRequest(String teamId) async {
    return await _dio.post('/teams/$teamId/join-request');
  }

  Future<Response> approveJoinRequest(String teamId, String userId) async {
    return await _dio.post(
      '/teams/$teamId/approve-request',
      data: {'user_id': userId},
    );
  }

  Future<Response> rejectJoinRequest(String teamId, String userId) async {
    return await _dio.post(
      '/teams/$teamId/reject-request',
      data: {'user_id': userId},
    );
  }

  Future<Response> getMyInvitations() async {
    return await _dio.get('/teams/my-invitations');
  }

  Future<Response> acceptInvitation(String teamId) async {
    return await _dio.post('/teams/$teamId/invitations/accept');
  }

  Future<Response> rejectInvitation(String teamId) async {
    return await _dio.post('/teams/$teamId/invitations/reject');
  }

  // NOTIFICATIONS
  Future<Response> getNotifications() async {
    return await _dio.get('/notifications/');
  }

  Future<Response> markNotificationRead(String id) async {
    return await _dio.post('/notifications/$id/read');
  }

  Future<Response> markAllNotificationsRead() async {
    return await _dio.post('/notifications/read-all');
  }

  // MATCHES
  Future<Response> createMatch({
    required String venue,
    required String matchDate,
    required String matchType,
    required int overLimit,
    required String team1Id,
    required String team2Id,
    String? tournamentId,
    String? assignedScorerId,
  }) async {
    return await _dio.post(
      '/matches/',
      data: {
        'venue': venue,
        'match_date': matchDate,
        'match_type': matchType,
        'over_limit': overLimit,
        'team1_id': team1Id,
        'team2_id': team2Id,
        if (tournamentId != null) 'tournament_id': tournamentId,
        if (assignedScorerId != null) 'assigned_scorer_id': assignedScorerId,
      },
    );
  }

  Future<Response> getMatches() async {
    return await _dio.get('/matches/');
  }

  Future<Response> submitToss(String matchId, String tossWinnerId, String tossDecision) async {
    return await _dio.post(
      '/matches/$matchId/toss',
      data: {
        'toss_winner_id': tossWinnerId,
        'toss_decision': tossDecision,
      },
    );
  }

  Future<Response> initiateToss(String matchId) async {
    return await _dio.post('/matches/$matchId/toss/initiate');
  }

  Future<Response> submitTossDecision(String matchId, String decision) async {
    return await _dio.post(
      '/matches/$matchId/toss/decision',
      data: {'toss_decision': decision},
    );
  }

  Future<Response> resetToss(String matchId) async {
    return await _dio.post('/matches/$matchId/toss/reset');
  }

  Future<Response> getMatchActivities(String matchId) async {
    return await _dio.get('/matches/$matchId/activities');
  }


  Future<Response> submitSquad(String matchId, String teamId, List<Map<String, dynamic>> players) async {
    return await _dio.post(
      '/matches/$matchId/squads',
      data: {
        'team_id': teamId,
        'players': players,
      },
    );
  }

  Future<Response> getMatchSquads(String matchId) async {
    return await _dio.get('/matches/$matchId/squads');
  }

  Future<Response> lockMatchSquad(String matchId, String teamId) async {
    return await _dio.post('/matches/$matchId/squads/$teamId/lock');
  }

  Future<Response> getLiveMatch(String matchId) async {
    return await _dio.get('/matches/$matchId/live');
  }

  Future<Response> getMatchScorecard(String matchId) async {
    return await _dio.get('/matches/$matchId/scorecard');
  }

  Future<Response> submitBall(String matchId, Map<String, dynamic> ballData) async {
    return await _dio.post(
      '/matches/$matchId/balls',
      data: ballData,
    );
  }

  Future<Response> undoLastBall(String matchId) async {
    return await _dio.post('/matches/$matchId/undo');
  }

  Future<Response> startMatch(String matchId, String strikerId, String nonStrikerId, String bowlerId) async {
    return await _dio.post(
      '/matches/$matchId/start',
      data: {
        'striker_id': strikerId,
        'non_striker_id': nonStrikerId,
        'bowler_id': bowlerId,
      },
    );
  }

  Future<Response> getActiveSession() async {
    return await _dio.get('/matches/active-session');
  }

  Future<Response> pauseMatch(String matchId) async {
    return await _dio.post('/matches/$matchId/pause');
  }

  Future<Response> resumeMatch(String matchId) async {
    return await _dio.post('/matches/$matchId/resume');
  }

  // TOURNAMENTS
  Future<Response> getTournaments() async {
    return await _dio.get('/tournaments/');
  }

  Future<Response> getTournament(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId');
  }

  Future<Response> getTournamentStandings(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/points-table');
  }

  Future<Response> createTournament({
    required String name,
    required String startDate,
    required String endDate,
    required String format,
    required int numTeams,
    String? bannerUrl,
  }) async {
    return await _dio.post(
      '/tournaments/',
      data: {
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'format': format,
        'num_teams': numTeams,
        'banner_url': bannerUrl,
      },
    );
  }

  Future<Response> registerTeam(String tournamentId, String teamId) async {
    return await _dio.post(
      '/tournaments/$tournamentId/teams',
      queryParameters: {'team_id': teamId},
    );
  }

  Future<Response> deregisterTeam(String tournamentId, String teamId) async {
    return await _dio.delete(
      '/tournaments/$tournamentId/teams/$teamId',
    );
  }

  Future<Response> generateFixtures(
    String tournamentId, {
    bool homeAway = false,
    String venue = "Main Ground",
    int overLimit = 20,
    String matchType = "T20",
  }) async {
    return await _dio.post(
      '/tournaments/$tournamentId/fixtures/generate',
      data: {
        'home_away': homeAway,
        'venue': venue,
        'over_limit': overLimit,
        'match_type': matchType,
      },
    );
  }

  Future<Response> getTournamentLeaderboards(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/leaderboards');
  }

  Future<Response> getTournamentDashboard(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/dashboard');
  }

  Future<Response> updateTournament(String id, Map<String, dynamic> data) async {
    return await _dio.put('/tournaments/$id', data: data);
  }

  Future<Response> deleteTournament(String id) async {
    return await _dio.delete('/tournaments/$id');
  }

  Future<Response> updateMatch(String id, Map<String, dynamic> data) async {
    return await _dio.put('/matches/$id', data: data);
  }

  Future<Response> deleteMatch(String id) async {
    return await _dio.delete('/matches/$id');
  }

  Future<Response> submitReport(String contentType, String contentId, String reason) async {
    return await _dio.post('/reports', data: {
      'content_type': contentType,
      'content_id': contentId,
      'reason': reason,
    });
  }

  Future<Response> adminGetAnalytics() async {
    return await _dio.get('/admin/analytics');
  }

  Future<Response> adminGetUsers({String? query}) async {
    return await _dio.get(
      '/admin/users',
      queryParameters: query != null ? {'search': query} : null,
    );
  }

  Future<Response> adminToggleUserActive(String userId) async {
    return await _dio.put('/admin/users/$userId/toggle-active');
  }

  Future<Response> adminDeleteUser(String userId) async {
    return await _dio.delete('/admin/users/$userId');
  }

  Future<Response> adminGetReports({String? status}) async {
    return await _dio.get('/admin/reports', queryParameters: status != null ? {'status': status} : null);
  }

  Future<Response> adminResolveReport(String reportId, {String action = 'resolved', String? adminNotes}) async {
    final params = <String, dynamic>{'action': action};
    if (adminNotes != null) params['admin_notes'] = adminNotes;
    return await _dio.post('/admin/reports/$reportId/resolve', queryParameters: params);
  }

  // Admin Activity Logs
  Future<Response> adminGetActivityLogs({int limit = 50}) async {
    return await _dio.get('/admin/activity-logs', queryParameters: {'limit': limit});
  }

  // Admin User Management
  Future<Response> adminGetUserDetails(String userId) async {
    return await _dio.get('/admin/users/$userId');
  }

  Future<Response> adminBanUser(String userId) async {
    return await _dio.put('/admin/users/$userId/ban');
  }

  Future<Response> adminUnbanUser(String userId) async {
    return await _dio.put('/admin/users/$userId/unban');
  }

  // Admin Team Management
  Future<Response> adminGetTeams({String? search}) async {
    return await _dio.get('/admin/teams', queryParameters: search != null ? {'search': search} : null);
  }

  Future<Response> adminGetTeamDetails(String teamId) async {
    return await _dio.get('/admin/teams/$teamId');
  }

  Future<Response> adminUpdateTeam(String teamId, {String? name, String? captainId}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (captainId != null) data['captain_id'] = captainId;
    return await _dio.put('/admin/teams/$teamId', data: data);
  }

  Future<Response> adminDeleteTeam(String teamId) async {
    return await _dio.delete('/admin/teams/$teamId');
  }

  // Admin Player Management
  Future<Response> adminGetPlayers({String? search}) async {
    return await _dio.get('/admin/players', queryParameters: search != null ? {'search': search} : null);
  }

  Future<Response> adminGetPlayerDetails(String playerId) async {
    return await _dio.get('/admin/players/$playerId');
  }

  Future<Response> adminUpdatePlayer(String playerId, {String? name, String? role, String? battingStyle, String? bowlingStyle, int? jerseyNumber}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (role != null) data['role'] = role;
    if (battingStyle != null) data['batting_style'] = battingStyle;
    if (bowlingStyle != null) data['bowling_style'] = bowlingStyle;
    if (jerseyNumber != null) data['jersey_number'] = jerseyNumber;
    return await _dio.put('/admin/players/$playerId', data: data);
  }

  Future<Response> adminDeletePlayer(String playerId) async {
    return await _dio.delete('/admin/players/$playerId');
  }

  // Admin Tournament Management
  Future<Response> adminGetTournaments({String? search}) async {
    return await _dio.get('/admin/tournaments', queryParameters: search != null ? {'search': search} : null);
  }

  Future<Response> adminGetTournamentDetails(String tournamentId) async {
    return await _dio.get('/admin/tournaments/$tournamentId');
  }

  Future<Response> adminUpdateTournament(String tournamentId, {String? name, String? status}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (status != null) data['status'] = status;
    return await _dio.put('/admin/tournaments/$tournamentId', data: data);
  }

  Future<Response> adminDeleteTournament(String tournamentId) async {
    return await _dio.delete('/admin/tournaments/$tournamentId');
  }

  // Admin Match Management
  Future<Response> adminGetMatches({String? search, String? status}) async {
    final params = <String, dynamic>{};
    if (search != null) params['search'] = search;
    if (status != null) params['status'] = status;
    return await _dio.get('/admin/matches', queryParameters: params.isNotEmpty ? params : null);
  }

  Future<Response> adminGetMatchDetails(String matchId) async {
    return await _dio.get('/admin/matches/$matchId');
  }

  Future<Response> adminUpdateMatch(String matchId, {String? title, String? status, String? result}) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (status != null) data['status'] = status;
    if (result != null) data['result'] = result;
    return await _dio.put('/admin/matches/$matchId', data: data);
  }

  Future<Response> adminForceEndMatch(String matchId) async {
    return await _dio.post('/admin/matches/$matchId/force-end');
  }

  Future<Response> adminDeleteMatch(String matchId) async {
    return await _dio.delete('/admin/matches/$matchId');
  }

  // Admin Team Members Management
  Future<Response> adminGetTeamMembers({String? search}) async {
    return await _dio.get('/admin/team-members', queryParameters: search != null ? {'search': search} : null);
  }

  Future<Response> adminDeleteTeamMember(String id) async {
    return await _dio.delete('/admin/team-members/$id');
  }

  // Admin Bulk Deletion
  Future<Response> adminBulkDeleteUsers(List<String> ids) async {
    return await _dio.post('/admin/users/bulk-delete', data: {'ids': ids});
  }

  Future<Response> adminBulkDeleteTeams(List<String> ids) async {
    return await _dio.post('/admin/teams/bulk-delete', data: {'ids': ids});
  }

  Future<Response> adminBulkDeleteMatches(List<String> ids) async {
    return await _dio.post('/admin/matches/bulk-delete', data: {'ids': ids});
  }

  Future<Response> adminBulkDeleteTournaments(List<String> ids) async {
    return await _dio.post('/admin/tournaments/bulk-delete', data: {'ids': ids});
  }

  Future<Response> updateSquadConfig(String teamId, List<Map<String, dynamic>> members) async {
    return await _dio.put(
      '/teams/$teamId/squad-config',
      data: {
        'members': members,
      },
    );
  }

  Future<Response> lockSquad(String teamId) async {
    return await _dio.post('/teams/$teamId/lock');
  }

  Future<Response> unlockSquad(String teamId) async {
    return await _dio.post('/teams/$teamId/unlock');
  }

  Future<Response> getTeamActivities(String teamId) async {
    return await _dio.get('/teams/$teamId/activities');
  }

  Future<Response> getExploreTournaments({String? search}) async {
    return await _dio.get(
      '/tournaments/explore',
      queryParameters: search != null ? {'search': search} : null,
    );
  }

  Future<Response> publishTournament(String tournamentId) async {
    return await _dio.post('/tournaments/$tournamentId/publish');
  }

  Future<Response> openTournamentRegistration(String tournamentId) async {
    return await _dio.post('/tournaments/$tournamentId/open-registration');
  }

  Future<Response> closeTournamentRegistration(String tournamentId) async {
    return await _dio.post('/tournaments/$tournamentId/close-registration');
  }

  Future<Response> sendTournamentRequest(String tournamentId, String teamId) async {
    return await _dio.post(
      '/tournaments/$tournamentId/requests',
      queryParameters: {'team_id': teamId},
    );
  }

  Future<Response> cancelTournamentRequest(String tournamentId, String requestId) async {
    return await _dio.delete('/tournaments/$tournamentId/requests/$requestId');
  }

  Future<Response> getTournamentRequests(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/requests');
  }

  Future<Response> approveTournamentRequest(String tournamentId, String requestId) async {
    return await _dio.post('/tournaments/$tournamentId/requests/$requestId/approve');
  }

  Future<Response> rejectTournamentRequest(String tournamentId, String requestId) async {
    return await _dio.post('/tournaments/$tournamentId/requests/$requestId/reject');
  }

  Future<Response> getTournamentActivities(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/activities');
  }

  Future<Response> searchTeams([String query = ""]) async {
    return await _dio.get('/teams/search', queryParameters: {'query': query});
  }

  Future<Response> searchTournaments(String query) async {
    return await _dio.get('/tournaments/search', queryParameters: {'query': query});
  }

  Future<Response> getTeamInvitationsHistory(String teamId) async {
    return await _dio.get('/teams/$teamId/invitations');
  }

  Future<Response> getTeamJoinRequestsHistory(String teamId) async {
    return await _dio.get('/teams/$teamId/join-requests');
  }

  Future<Response> changePassword(String oldPassword, String newPassword) async {
    return await _dio.post('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<Response> deleteAccount() async {
    return await _dio.delete('/auth/delete-account');
  }

  Future<Response> publishFixtures(String tournamentId) async {
    return await _dio.post('/tournaments/$tournamentId/fixtures/publish');
  }

  Future<Response> createManualFixture(String tournamentId, Map<String, dynamic> data) async {
    return await _dio.post('/tournaments/$tournamentId/fixtures/manual', data: data);
  }

  Future<Response> testConnection() async {
    final uri = Uri.parse(AppConfig.baseUrl);
    final hostUrl = "${uri.scheme}://${uri.host}:${uri.port}/";
    print("[Connection Test] Probing host URL: $hostUrl");
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 5);
    return await dio.get(hostUrl);
  }
}

class UserFriendlyDioException extends DioException {
  final String friendlyMessage;

  UserFriendlyDioException({
    required super.requestOptions,
    super.response,
    super.type,
    super.error,
    super.stackTrace,
    required this.friendlyMessage,
  }) : super(message: friendlyMessage);

  @override
  String toString() {
    return friendlyMessage;
  }
}

String _getFriendlyMessage(DioException e) {
  if (e.response?.data != null) {
    final data = e.response!.data;
    if (data is Map) {
      if (data.containsKey('detail') && data['detail'] != null && data['detail'].toString().isNotEmpty) {
        return data['detail'].toString();
      }
      if (data.containsKey('message') && data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.error?.toString().contains("SocketException") == true ||
      e.message?.contains("SocketException") == true) {
    return "Connection timeout. Please check your internet connection and try again.";
  }
  
  if (e.type == DioExceptionType.badResponse) {
    final status = e.response?.statusCode;
    if (status == 404) {
      return "This item is no longer available.";
    } else if (status == 403) {
      return "You don't have permission to perform this action.";
    } else if (status == 422) {
      return "Please check the information and try again.";
    } else if (status == 500) {
      return "Something went wrong. Please try again.";
    }
  }
  
  return "Something went wrong. Please try again.";
}

