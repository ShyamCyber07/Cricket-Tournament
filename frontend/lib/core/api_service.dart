import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final Dio _dio = Dio();
  static String? _token;
  static String? _refreshToken;
  static const String _tokenKey = "jwt_auth_token";
  static const String _refreshTokenKey = "jwt_refresh_token";

  ApiService() {
    _dio.options.baseUrl = AppConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Inject logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint("[Dio Request] => Method: ${options.method} | URL: ${options.baseUrl}${options.path}");
          debugPrint("[Dio Request Headers] => ${options.headers}");
          if (options.data != null) {
            debugPrint("[Dio Request Data] => ${options.data}");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint("[Dio Response] <= Status: ${response.statusCode} | URL: ${response.requestOptions.baseUrl}${response.requestOptions.path}");
          debugPrint("[Dio Response Data] <= ${response.data}");
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          debugPrint("[Dio Error] <= Status: ${e.response?.statusCode} | Error: ${e.error} | Message: ${e.message} | URL: ${e.requestOptions.baseUrl}${e.requestOptions.path}");
          if (e.response?.data != null) {
            debugPrint("[Dio Error Data] <= ${e.response?.data}");
          }
          return handler.next(e);
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
            if (_refreshToken != null) {
              try {
                debugPrint("[Dio Interceptor] Access token expired, attempting refresh...");
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
                  debugPrint("[Dio Interceptor] Token refresh successful. Retrying original request...");
                  await persistToken(newAccessToken, newRefreshToken);
                  
                  // Retry the original request
                  final options = e.requestOptions;
                  options.headers["Authorization"] = "Bearer $newAccessToken";
                  
                  final cloneResponse = await _dio.fetch(options);
                  return handler.resolve(cloneResponse);
                }
              } catch (refreshErr) {
                debugPrint("[Dio Interceptor] Token refresh failed: $refreshErr. Clearing credentials.");
                await clearToken();
              }
            } else {
              await clearToken();
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
    print("SIGNUP REQUEST STARTING");
    print("BASE URL: ${_dio.options.baseUrl}");
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        },
      );
      print("STATUS CODE: ${response.statusCode}");
      return response;
    } catch (e, stackTrace) {
      print("SIGNUP ERROR: $e");
      print(stackTrace);
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
    return await _dio.get('/auth/me');
  }

  Future<Response> logout() async {
    final response = await _dio.post('/auth/logout');
    await clearToken();
    return response;
  }

  // PLAYERS
  Future<Response> getPlayers({String? search}) async {
    final query = search != null ? {'search': search} : null;
    return await _dio.get('/players/', queryParameters: query);
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

  Future<Response> updateTeam(String id, String name, {String? captainId}) async {
    return await _dio.put(
      '/teams/$id',
      data: {
        'name': name,
        'captain_id': captainId,
      },
    );
  }

  Future<Response> deleteTeam(String id) async {
    return await _dio.delete('/teams/$id');
  }

  Future<Response> getTeamStats(String teamId) async {
    return await _dio.get('/teams/$teamId/stats');
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
        'tournament_id': tournamentId,
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

  Future<Response> testConnection() async {
    final uri = Uri.parse(AppConfig.baseUrl);
    final hostUrl = "${uri.scheme}://${uri.host}:${uri.port}/";
    debugPrint("[Connection Test] Probing host URL: $hostUrl");
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 5);
    return await dio.get(hostUrl);
  }
}
