import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_rest_config.dart';
import 'history_manager.dart';

/// Desktop user info (REST-based auth).
class DesktopUser {
  final String uid;
  final String? displayName;
  final String? email;

  DesktopUser({required this.uid, this.displayName, this.email});
}

class _FirebaseSession {
  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? email;
  final String? displayName;

  _FirebaseSession({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.email,
    required this.displayName,
  });
}

/// Firebase Sync Service (desktop REST implementation).
///
/// This file must not import FlutterFire packages.
class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  static FirebaseSyncService get instance => _instance;

  FirebaseSyncService._internal();

  final StreamController<void> _authChanges = StreamController<void>.broadcast();
  _FirebaseSession? _session;
  bool _initialized = false;

  HttpClient? _sseClient;
  StreamSubscription<String>? _sseSubscription;
  int _syncGeneration = 0;

  static const String _prefsRefreshTokenKey = 'desktop_firebase_refresh_token';
  static const String _prefsEmailKey = 'desktop_firebase_email';
  static const String _prefsDisplayNameKey = 'desktop_firebase_display_name';

  DesktopUser? get currentUser {
    final s = _session;
    if (s == null) return null;
    return DesktopUser(uid: s.uid, displayName: s.displayName, email: s.email);
  }

  bool get isSignedIn => _session != null;
  String? get userDisplayName => _session?.displayName;
  String? get userEmail => _session?.email;

  Stream<void> get authStateChanges => _authChanges.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_prefsRefreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return;

    try {
      final refreshed = await _refreshFirebaseToken(refreshToken);
      final profile = await _lookupFirebaseProfile(refreshed.idToken);
      _session = _FirebaseSession(
        uid: refreshed.uid,
        idToken: refreshed.idToken,
        refreshToken: refreshed.refreshToken,
        expiresAt: refreshed.expiresAt,
        email: profile.email ?? prefs.getString(_prefsEmailKey),
        displayName: profile.displayName ?? prefs.getString(_prefsDisplayNameKey),
      );
      await _persistSession(_session!);
      _authChanges.add(null);
    } catch (_) {
      // Keep signed-out state if refresh fails.
      await _clearPersistedSession();
    }
  }

  Future<DesktopUser?> signInWithGoogle() async {
    await ensureInitialized();
    final clientId = FirebaseRestConfig.googleDesktopClientId;
    final clientSecret = FirebaseRestConfig.googleDesktopClientSecret;
    if (clientId.isEmpty) {
      throw Exception(
        'DESKTOP_GOOGLE_OAUTH_CLIENT_ID が未設定です（--dart-define で指定してください）',
      );
    }

    final pkce = _createPkce();
    final state = _randomString(24);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse('http://127.0.0.1:${server.port}/');

    final codeCompleter = Completer<Uri>();
    server.listen((request) async {
      try {
        final uri = request.uri;
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<html><body><h2>ログイン完了</h2><p>このウィンドウを閉じてアプリに戻ってください。</p></body></html>',
        );
        await request.response.close();

        if (!codeCompleter.isCompleted) {
          codeCompleter.complete(uri);
        }
      } catch (_) {
        if (!codeCompleter.isCompleted) {
          codeCompleter.completeError(Exception('ログインの受信に失敗しました'));
        }
      } finally {
        await server.close(force: true);
      }
    });

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': pkce.codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });

    final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await server.close(force: true);
      throw Exception('ブラウザを開けませんでした');
    }

    final callbackUri = await codeCompleter.future.timeout(const Duration(minutes: 3));
    if (callbackUri.queryParameters['state'] != state) {
      throw Exception('ログインの検証に失敗しました（state不一致）');
    }
    final error = callbackUri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw Exception('ログインに失敗しました: $error');
    }
    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('ログインコードが取得できませんでした');
    }

    final tokenResponse = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{
        'client_id': clientId,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
        'code': code,
        'code_verifier': pkce.codeVerifier,
        'redirect_uri': redirectUri.toString(),
        'grant_type': 'authorization_code',
      },
    );
    if (tokenResponse.statusCode != 200) {
      var message = 'トークン取得に失敗しました（${tokenResponse.statusCode}）';
      try {
        final err = jsonDecode(tokenResponse.body);
        if (err is Map) {
          final error = err['error']?.toString();
          final desc = err['error_description']?.toString();
          final combined = [
            if (error != null && error.isNotEmpty) error,
            if (desc != null && desc.isNotEmpty) desc,
          ].join(': ');
          if (combined.isNotEmpty) {
            message = '$message: $combined';
          }
        } else if (tokenResponse.body.isNotEmpty) {
          message = '$message: ${tokenResponse.body}';
        }
      } catch (_) {
        if (tokenResponse.body.isNotEmpty) {
          message = '$message: ${tokenResponse.body}';
        }
      }
      throw Exception(message);
    }
    final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final googleIdToken = tokenJson['id_token'] as String?;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw Exception('Googleのid_tokenが取得できませんでした');
    }

    final firebaseSession = await _firebaseSignInWithGoogleIdToken(googleIdToken);
    _session = firebaseSession;
    await _persistSession(firebaseSession);
    _authChanges.add(null);
    setupRealtimeSync();
    return currentUser;
  }

  Future<void> signOut() async {
    stopRealtimeSync();
    _session = null;
    await _clearPersistedSession();
    _authChanges.add(null);
  }

  void setupRealtimeSync() {
    if (_session == null) return;
    _syncGeneration++;
    _startSseLoop(_syncGeneration);
  }

  void stopRealtimeSync() {
    _syncGeneration++;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseClient?.close(force: true);
    _sseClient = null;
  }

  Future<bool> uploadHistory(QuizHistory history) async {
    final session = _session;
    if (session == null) return false;

    try {
      final idToken = await _getValidIdToken();
      final uri = Uri.parse(
        '${FirebaseRestConfig.databaseUrl}/users/${session.uid}/histories/${history.id}.json?auth=$idToken',
      );
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_historyToFirebaseJson(history)),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<int> uploadAllHistories() async {
    final histories = HistoryManager.instance.histories;
    var uploadedCount = 0;
    for (final h in histories) {
      if (await uploadHistory(h)) {
        uploadedCount++;
      }
    }
    return uploadedCount;
  }

  Future<bool> deleteHistoryFromFirebase(String historyId) async {
    final session = _session;
    if (session == null) return false;

    try {
      final idToken = await _getValidIdToken();
      final uri = Uri.parse(
        '${FirebaseRestConfig.databaseUrl}/users/${session.uid}/histories/$historyId.json?auth=$idToken',
      );
      final response = await http.delete(uri);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearFirebaseHistories() async {
    final session = _session;
    if (session == null) return false;

    try {
      final idToken = await _getValidIdToken();
      final uri = Uri.parse(
        '${FirebaseRestConfig.databaseUrl}/users/${session.uid}/histories.json?auth=$idToken',
      );
      final response = await http.delete(uri);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSseLoop(int generation) async {
    var backoffMs = 500;

    while (_syncGeneration == generation && _session != null) {
      try {
        await _connectAndListenSse(generation);
        backoffMs = 500;
      } catch (_) {
        // ignore and retry with backoff
      }

      if (_syncGeneration != generation || _session == null) return;
      await Future.delayed(Duration(milliseconds: backoffMs));
      backoffMs = min(backoffMs * 2, 30000);
    }
  }

  Future<void> _connectAndListenSse(int generation) async {
    final session = _session;
    if (session == null) return;

    final idToken = await _getValidIdToken();
    final uri = Uri.parse(
      '${FirebaseRestConfig.databaseUrl}/users/${session.uid}/histories.json?auth=$idToken',
    );

    _sseSubscription?.cancel();
    _sseClient?.close(force: true);

    final client = HttpClient();
    _sseClient = client;

    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

    final response = await request.close();
    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SSE failed: ${response.statusCode}');
    }

    final lines = response
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? currentEvent;
    final dataBuf = StringBuffer();

    _sseSubscription = lines.listen(
      (line) {
        if (_syncGeneration != generation) return;

        if (line.isEmpty) {
          final dataStr = dataBuf.toString().trim();
          if (dataStr.isNotEmpty) {
            _handleSseEvent(currentEvent ?? 'message', dataStr);
          }
          currentEvent = null;
          dataBuf.clear();
          return;
        }

        if (line.startsWith('event:')) {
          currentEvent = line.substring('event:'.length).trim();
          return;
        }

        if (line.startsWith('data:')) {
          dataBuf.writeln(line.substring('data:'.length).trimLeft());
          return;
        }
      },
      onError: (_) {},
      onDone: () {},
      cancelOnError: true,
    );
  }

  void _handleSseEvent(String event, String dataStr) {
    if (event != 'put' && event != 'patch') return;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final path = payload['path'] as String? ?? '/';
    final data = payload['data'];
    if (data == null) return;

    if (path == '/' && data is Map) {
      final remoteHistories = <QuizHistory>[];
      data.forEach((key, value) {
        if (value is Map) {
          final history = _historyFromFirebaseMap(value);
          if (history != null) remoteHistories.add(history);
        }
      });
      _mergeRemoteHistories(remoteHistories);
      return;
    }

    if (path.startsWith('/') && data is Map) {
      final history = _historyFromFirebaseMap(data);
      if (history != null) {
        _mergeRemoteHistories([history]);
      }
    }
  }

  void _mergeRemoteHistories(List<QuizHistory> remoteHistories) {
    final localIds = HistoryManager.instance.histories.map((h) => h.id).toSet();
    final newOnes = remoteHistories.where((h) => !localIds.contains(h.id)).toList();
    for (final h in newOnes) {
      HistoryManager.instance.saveHistory(h);
    }
  }

  QuizHistory? _historyFromFirebaseMap(Map<dynamic, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final tsRaw = map['timestamp'];
    final tsMillis = (tsRaw is num) ? tsRaw.toInt() : int.tryParse(tsRaw?.toString() ?? '') ?? 0;

    final qrList = (map['questionResults'] as List?) ?? const [];
    final questionResults = <QuestionResult>[];
    for (final item in qrList) {
      if (item is Map) {
        questionResults.add(
          QuestionResult(
            questionNumber: (item['questionNumber'] as num?)?.toInt() ?? 0,
            description: item['description'] as String? ?? '',
            isCorrect: item['isCorrect'] as bool? ?? false,
            wasSame: item['wasSame'] as bool? ?? false,
            answeredSame: item['answeredSame'] as bool? ?? false,
          ),
        );
      }
    }

    return QuizHistory(
      id: id,
      genre: map['genre'] as String? ?? '',
      responderName: map['responderName'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      timeMillis: (map['timeMillis'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMillis),
      questionResults: questionResults,
    );
  }

  Map<String, dynamic> _historyToFirebaseJson(QuizHistory history) {
    return {
      'id': history.id,
      'genre': history.genre,
      'responderName': history.responderName,
      'score': history.score,
      'total': history.total,
      'timeMillis': history.timeMillis,
      'timestamp': history.timestamp.millisecondsSinceEpoch,
      'questionResults': history.questionResults
          .map((qr) => {
                'questionNumber': qr.questionNumber,
                'description': qr.description,
                'isCorrect': qr.isCorrect,
                'wasSame': qr.wasSame,
                'answeredSame': qr.answeredSame,
              })
          .toList(),
    };
  }

  Future<String> _getValidIdToken() async {
    final s = _session;
    if (s == null) throw Exception('サインインしてください');

    final now = DateTime.now();
    if (s.expiresAt.isAfter(now.add(const Duration(minutes: 5)))) {
      return s.idToken;
    }

    final refreshed = await _refreshFirebaseToken(s.refreshToken);
    _session = _FirebaseSession(
      uid: s.uid,
      idToken: refreshed.idToken,
      refreshToken: refreshed.refreshToken,
      expiresAt: refreshed.expiresAt,
      email: s.email,
      displayName: s.displayName,
    );
    await _persistSession(_session!);
    return _session!.idToken;
  }

  Future<void> _persistSession(_FirebaseSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRefreshTokenKey, session.refreshToken);
    if (session.email != null) {
      await prefs.setString(_prefsEmailKey, session.email!);
    }
    if (session.displayName != null) {
      await prefs.setString(_prefsDisplayNameKey, session.displayName!);
    }
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRefreshTokenKey);
    await prefs.remove(_prefsEmailKey);
    await prefs.remove(_prefsDisplayNameKey);
  }

  Future<_FirebaseSession> _firebaseSignInWithGoogleIdToken(String googleIdToken) async {
    final apiKey = FirebaseRestConfig.apiKey;
    final response = await http.post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:signInWithIdp', {
        'key': apiKey,
      }),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'postBody': 'id_token=$googleIdToken&providerId=google.com',
        'requestUri': 'http://localhost',
        'returnSecureToken': true,
        'returnIdpCredential': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Firebaseサインインに失敗しました（${response.statusCode}）');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = json['idToken'] as String? ?? '';
    final refreshToken = json['refreshToken'] as String? ?? '';
    final uid = json['localId'] as String? ?? '';
    final expiresIn = int.tryParse(json['expiresIn']?.toString() ?? '') ?? 3600;

    if (idToken.isEmpty || refreshToken.isEmpty || uid.isEmpty) {
      throw Exception('Firebaseサインイン応答が不正です');
    }

    final claims = _decodeJwtClaims(googleIdToken);

    return _FirebaseSession(
      uid: uid,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      email: claims['email'] as String?,
      displayName: claims['name'] as String?,
    );
  }

  Future<_RefreshedToken> _refreshFirebaseToken(String refreshToken) async {
    final apiKey = FirebaseRestConfig.apiKey;
    final response = await http.post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('トークン更新に失敗しました（${response.statusCode}）');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String? ?? '';
    final newRefreshToken = json['refresh_token'] as String? ?? '';
    final uid = json['user_id'] as String? ?? '';
    final expiresIn = int.tryParse(json['expires_in']?.toString() ?? '') ?? 3600;
    if (idToken.isEmpty || newRefreshToken.isEmpty || uid.isEmpty) {
      throw Exception('トークン更新応答が不正です');
    }
    return _RefreshedToken(
      uid: uid,
      idToken: idToken,
      refreshToken: newRefreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<_Profile> _lookupFirebaseProfile(String idToken) async {
    final apiKey = FirebaseRestConfig.apiKey;
    final response = await http.post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:lookup', {'key': apiKey}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode != 200) {
      return const _Profile();
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final users = json['users'];
    if (users is List && users.isNotEmpty && users.first is Map) {
      final u = users.first as Map;
      return _Profile(
        email: u['email'] as String?,
        displayName: u['displayName'] as String?,
      );
    }
    return const _Profile();
  }

  Map<String, dynamic> _decodeJwtClaims(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return const {};
    try {
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      final json = jsonDecode(utf8.decode(bytes));
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }

  _PkcePair _createPkce() {
    final verifier = _randomString(64);
    final digest = sha256.convert(utf8.encode(verifier)).bytes;
    final challenge = base64UrlEncode(digest).replaceAll('=', '');
    return _PkcePair(codeVerifier: verifier, codeChallenge: challenge);
  }

  String _randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[rnd.nextInt(chars.length)]);
    }
    return buf.toString();
  }
}

class _PkcePair {
  final String codeVerifier;
  final String codeChallenge;

  _PkcePair({required this.codeVerifier, required this.codeChallenge});
}

class _RefreshedToken {
  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  _RefreshedToken({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });
}

class _Profile {
  final String? email;
  final String? displayName;

  const _Profile({this.email, this.displayName});
}
