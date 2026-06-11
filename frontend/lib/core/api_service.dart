import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final Dio _dio = Dio();
  static String? _token;
  static const String _tokenKey = "jwt_auth_token";

  ApiService() {
    _dio.options.baseUrl = AppConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

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
          // Global 401 error handling
          if (e.response?.statusCode == 401) {
            await clearToken();
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
    } catch (_) {
      _token = null;
    }
  }

  static Future<void> persistToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  static void setToken(String? token) {
    _token = token;
    if (token != null) {
      persistToken(token);
    } else {
      clearToken();
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
      await persistToken(response.data['access_token']);
    }
    return response;
  }

  Future<Response> signup(String email, String password, String fullName) async {
    return await _dio.post(
      '/auth/signup',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      },
    );
  }

  Future<Response> loginWithGoogle(String googleToken) async {
    final response = await _dio.post(
      '/auth/google',
      data: {'token': googleToken},
    );
    if (response.statusCode == 200) {
      await persistToken(response.data['access_token']);
    }
    return response;
  }

  Future<Response> getMe() async {
    return await _dio.get('/auth/me');
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
