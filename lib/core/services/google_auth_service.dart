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

const _prefAccessToken  = 'gauth_access_token';
const _prefRefreshToken = 'gauth_refresh_token';
const _prefTokenExpiry  = 'gauth_token_expiry';
const _prefUserEmail    = 'gauth_user_email';

class GoogleAuthService {
  // ── Android ──────────────────────────────────────────────────────────────
  static final _googleSignIn = GoogleSignIn(scopes: [_driveScope]);

  // ── Credenciais do .env ───────────────────────────────────────────────────
  static String get _clientId     => dotenv.env['GOOGLE_CLIENT_ID']     ?? '';
  static String get _clientSecret => dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';

  // ── Interface pública unificada ───────────────────────────────────────────

  static Future<String?> currentUserEmail() async {
    if (Platform.isWindows) {
      final prefs        = await SharedPreferences.getInstance();
      final email        = prefs.getString(_prefUserEmail);
      final hasRefresh   = prefs.getString(_prefRefreshToken) != null;
      final expiryMs     = prefs.getInt(_prefTokenExpiry) ?? 0;
      final notExpired   = DateTime.now().millisecondsSinceEpoch < expiryMs;
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

  // ── Windows ───────────────────────────────────────────────────────────────

  static Future<String?> _signInWindows() async {
    try {
      final clientId = ClientId(_clientId, _clientSecret);
      
      // Use clientViaUserConsent em vez de obtainAccessCredentials
      // Ele gerencia o servidor localhost e o response_type automaticamente
      final authClient = await clientViaUserConsent(
        clientId, 
        [_driveScope], 
        (url) async {
          debugPrint('[Auth] Abrindo browser: $url');
          await Process.run('cmd', ['/c', 'start', '', url]);
        }
      );
  
      final credentials = authClient.credentials;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccessToken, credentials.accessToken.data);
      await prefs.setInt(
        _prefTokenExpiry,
        credentials.accessToken.expiry.millisecondsSinceEpoch,
      );
      if (credentials.refreshToken != null) {
        await prefs.setString(_prefRefreshToken, credentials.refreshToken!);
      }

      final email = await _fetchEmail(credentials);
      if (email != null) await prefs.setString(_prefUserEmail, email);

      debugPrint('[Auth] Login Windows OK: $email');
      return email;
    } catch (e, st) {
      debugPrint('[Auth] Erro signInWindows: $e\n$st');
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApiWindows() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final accessData  = prefs.getString(_prefAccessToken);
      final refreshTok  = prefs.getString(_prefRefreshToken);
      final expiryMs    = prefs.getInt(_prefTokenExpiry) ?? 0;

      if (accessData == null && refreshTok == null) {
        debugPrint('[Auth] Windows: sem tokens salvos.');
        return null;
      }

      final expiry   = DateTime.fromMillisecondsSinceEpoch(expiryMs).toUtc();
      final clientId = ClientId(_clientId, _clientSecret);

      var credentials = AccessCredentials(
        AccessToken('Bearer', accessData ?? '', expiry),
        refreshTok,
        [_driveScope],
      );

      // Renova access token se expirado e houver refresh token
      if (DateTime.now().toUtc().isAfter(expiry) && refreshTok != null) {
        debugPrint('[Auth] Windows: renovando token...');
        final baseClient = http.Client();
        credentials = await refreshCredentials(clientId, credentials, baseClient);
        baseClient.close();
        await prefs.setString(_prefAccessToken, credentials.accessToken.data);
        await prefs.setInt(
          _prefTokenExpiry,
          credentials.accessToken.expiry.millisecondsSinceEpoch,
        );
      }

      final authClient = authenticatedClient(http.Client(), credentials);
      return drive.DriveApi(authClient);
    } catch (e, st) {
      debugPrint('[Auth] Erro _getDriveApiWindows: $e\n$st');
      return null;
    }
  }

  static Future<String?> _fetchEmail(AccessCredentials credentials) async {
    try {
      final client   = authenticatedClient(http.Client(), credentials);
      final response = await client.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      );
      client.close();
      if (response.statusCode == 200) {
        final match =
            RegExp(r'"email"\s*:\s*"([^"]+)"').firstMatch(response.body);
        return match?.group(1);
      }
    } catch (e) {
      debugPrint('[Auth] Erro ao buscar email: $e');
    }
    return null;
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