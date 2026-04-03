import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

// Escopo mínimo — apenas arquivos criados pelo próprio app
const _driveScope = drive.DriveApi.driveAppdataScope;

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [_driveScope],
  );

  // Retorna o usuário atual se já autenticado, null caso contrário
  static Future<GoogleSignInAccount?> currentUser() async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  // Fluxo de login interativo — abre browser no Windows, seletor no Android
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // Retorna um cliente HTTP autenticado pronto para uso com googleapis
  static Future<drive.DriveApi?> getDriveApi() async {
    var user = await currentUser();
    user ??= await signIn();
    if (user == null) return null;

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    return drive.DriveApi(httpClient);
  }
}