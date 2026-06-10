import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio = Dio();
  static String? _token;
  static const String _tokenKey = "jwt_auth_token";

  // Local SQLite FastAPI server running on default port 8000
  // Android emulator uses 10.0.2.2 to access localhost on host machine
  static String get baseUrl {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000/api/v1";
    }
    return "http://localhost:8000/api/v1";
  }

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

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

  Future<Response> createPlayer(String name, String role, String batting, String bowling) async {
    return await _dio.post(
      '/players/',
      data: {
        'name': name,
        'role': role,
        'batting_style': batting,
        'bowling_style': bowling,
      },
    );
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

  Future<Response> getTournamentStandings(String tournamentId) async {
    return await _dio.get('/tournaments/$tournamentId/points-table');
  }

  Future<Response> createTournament({
    required String name,
    required String startDate,
    required String endDate,
    required String format,
  }) async {
    return await _dio.post(
      '/tournaments/',
      data: {
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'format': format,
      },
    );
  }
}
