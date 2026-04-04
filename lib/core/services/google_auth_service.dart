import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _driveScope = drive.DriveApi.driveAppdataScope;
const _emailScope = 'https://www.googleapis.com/auth/userinfo.email';

const _prefAccessToken  = 'gauth_access_token';
const _prefRefreshToken = 'gauth_refresh_token';
const _prefTokenExpiry  = 'gauth_token_expiry';
const _prefUserEmail    = 'gauth_user_email';

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(scopes: [_driveScope]);

  static String get _clientId     => dotenv.env['GOOGLE_CLIENT_ID']     ?? '';
  static String get _clientSecret => dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';

  static Future<String?> currentUserEmail() async {
    if (Platform.isWindows) {
      final prefs      = await SharedPreferences.getInstance();
      final email      = prefs.getString(_prefUserEmail);
      final hasRefresh = prefs.getString(_prefRefreshToken) != null;
      final expiryMs   = prefs.getInt(_prefTokenExpiry) ?? 0;
      final notExpired = DateTime.now().millisecondsSinceEpoch < expiryMs;
      if (email != null && (hasRefresh || notExpired)) return email;
      return null;
    } else {
      final account =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      return account?.email;
    }
  }

  static Future<String?> signIn() async {
    if (Platform.isWindows) return _signInWindows();
    return _signInAndroid();
  }

  static Future<void> signOut() async {
    if (Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefAccessToken);
      await prefs.remove(_prefRefreshToken);
      await prefs.remove(_prefTokenExpiry);
      await prefs.remove(_prefUserEmail);
    } else {
      await _googleSignIn.signOut();
    }
  }

  static Future<drive.DriveApi?> getDriveApi() async {
    if (Platform.isWindows) return _getDriveApiWindows();
    return _getDriveApiAndroid();
  }

  // ── Windows — fluxo OAuth manual com servidor local ───────────────────────

  static Future<String?> _signInWindows() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      debugPrint('[Auth] Redirect URI: $redirectUri');

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': '$_driveScope $_emailScope',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      debugPrint('[Auth] Abrindo browser: $authUrl');
      await Process.run(
        'powershell',
        ['-Command', 'Start-Process "${authUrl.toString()}"'],
      );

      debugPrint('[Auth] Aguardando callback...');
      final request = await server.first;
      debugPrint('[Auth] Callback recebido: ${request.uri}');

      final code  = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

      debugPrint('[Auth] code presente: ${code != null}');
      debugPrint('[Auth] error: $error');

      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write('''
          <html><body style="font-family:sans-serif;text-align:center;padding-top:60px">
            <h2>${error != null ? '❌ Erro na autenticação' : '✅ Autenticação concluída!'}</h2>
            <p>${error != null ? 'Ocorreu um erro: $error' : 'Pode fechar esta aba e voltar ao Quórum.'}</p>
          </body></html>
        ''');
      await request.response.close();
      await server.close();

      if (error != null || code == null) {
        debugPrint('[Auth] Abortando: error=$error, code nulo=${code == null}');
        return null;
      }

      debugPrint('[Auth] Trocando code por tokens...');
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      debugPrint('[Auth] Token status: ${tokenResponse.statusCode}');
      debugPrint('[Auth] Token body: ${tokenResponse.body}');

      if (tokenResponse.statusCode != 200) {
        debugPrint('[Auth] Falha na troca de tokens');
        return null;
      }

      final tokenData    = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final accessToken  = tokenData['access_token']  as String?;
      final refreshToken = tokenData['refresh_token'] as String?;
      final expiresIn    = tokenData['expires_in']    as int? ?? 3600;

      debugPrint('[Auth] accessToken presente: ${accessToken != null}');
      debugPrint('[Auth] refreshToken presente: ${refreshToken != null}');

      if (accessToken == null) {
        debugPrint('[Auth] access_token ausente');
        return null;
      }

      final expiryMs = DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccessToken, accessToken);
      await prefs.setInt(_prefTokenExpiry, expiryMs);
      if (refreshToken != null) {
        await prefs.setString(_prefRefreshToken, refreshToken);
      }

      debugPrint('[Auth] Buscando email...');
      final email = await _fetchEmailFromToken(accessToken);
      debugPrint('[Auth] Email obtido: $email');
      
      // Usa o email se disponível, senão usa um placeholder
      // O login não deve falhar só porque o email não veio
      final userEmail = email ?? 'usuario@google.com';
      await prefs.setString(_prefUserEmail, userEmail);
      
      debugPrint('[Auth] Login Windows OK: $userEmail');
      return userEmail;
    } catch (e, st) {
      debugPrint('[Auth] EXCEÇÃO: $e\n$st');
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApiWindows() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final accessData = prefs.getString(_prefAccessToken);
      final refreshTok = prefs.getString(_prefRefreshToken);
      final expiryMs   = prefs.getInt(_prefTokenExpiry) ?? 0;

      if (accessData == null && refreshTok == null) {
        debugPrint('[Auth] Windows: sem tokens salvos.');
        return null;
      }

      final expiry   = DateTime.fromMillisecondsSinceEpoch(expiryMs).toUtc();
      final clientId = ClientId(_clientId, _clientSecret);
      final isExpired = DateTime.now().toUtc().isAfter(expiry);

      String currentAccessToken = accessData ?? '';

      if (isExpired && refreshTok != null) {
        debugPrint('[Auth] Windows: renovando token via refresh...');
        final refreshed = await _refreshAccessToken(refreshTok);
        if (refreshed == null) {
          debugPrint('[Auth] Falha ao renovar token.');
          return null;
        }
        currentAccessToken = refreshed['access_token'] as String;
        final newExpiresIn = refreshed['expires_in'] as int? ?? 3600;
        final newExpiryMs = DateTime.now()
            .add(Duration(seconds: newExpiresIn))
            .millisecondsSinceEpoch;
        await prefs.setString(_prefAccessToken, currentAccessToken);
        await prefs.setInt(_prefTokenExpiry, newExpiryMs);
      }

      final newExpiry = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt(_prefTokenExpiry) ?? expiryMs,
      ).toUtc();

      final credentials = AccessCredentials(
        AccessToken('Bearer', currentAccessToken, newExpiry),
        refreshTok,
        [_driveScope, _emailScope],
      );

      final authClient = authenticatedClient(http.Client(), credentials);
      return drive.DriveApi(authClient);
    } catch (e, st) {
      debugPrint('[Auth] Erro _getDriveApiWindows: $e\n$st');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _refreshAccessToken(
      String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'refresh_token': refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[Auth] Erro ao renovar: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[Auth] Exceção em _refreshAccessToken: $e');
      return null;
    }
  }

  static Future<String?> _fetchEmailFromToken(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      debugPrint('[Auth] userinfo status: ${response.statusCode}');
      debugPrint('[Auth] userinfo body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['email'] as String?;
      }
    } catch (e) {
      debugPrint('[Auth] Erro ao buscar email: $e');
    }
    return null;
  }

  // Mantido por compatibilidade, não usado no Windows novo fluxo
  static Future<String?> _fetchEmail(AccessCredentials credentials) async {
    return _fetchEmailFromToken(credentials.accessToken.data);
  }

  // ── Android ───────────────────────────────────────────────────────────────

  static Future<String?> _signInAndroid() async {
    try {
      final account = await _googleSignIn.signIn();
      return account?.email;
    } catch (e, st) {
      debugPrint('[Auth] Erro signInAndroid: $e\n$st');
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApiAndroid() async {
    try {
      var account =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return null;

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return null;

      return drive.DriveApi(httpClient);
    } catch (e, st) {
      debugPrint('[Auth] Erro _getDriveApiAndroid: $e\n$st');
      return null;
    }
  }
}