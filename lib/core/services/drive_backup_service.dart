import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveBackupService {
  static const _fileName = 'quorum_sync.json';
  static const _mimeType = 'application/json';
  static const _spaces = 'appDataFolder';

  // Faz upload do JSON para o Drive, substituindo o arquivo existente
  static Future<bool> upload(String jsonContent) async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return false;

      final existingId = await _getFileId(api);
      final media = drive.Media(
        Stream.value(utf8.encode(jsonContent)),
        utf8.encode(jsonContent).length,
        contentType: _mimeType,
      );

      if (existingId != null) {
        // Atualiza o arquivo existente
        await api.files.update(
          drive.File(),
          existingId,
          uploadMedia: media,
        );
      } else {
        // Cria o arquivo pela primeira vez
        final file = drive.File()
          ..name = _fileName
          ..parents = [_spaces];
        await api.files.create(
          file,
          uploadMedia: media,
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Baixa o JSON do Drive. Retorna null se não existir ou em erro.
  static Future<String?> download() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return null;

      final fileId = await _getFileId(api);
      if (fileId == null) return null;

      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.toList();
      final content = bytes.expand((b) => b).toList();
      return utf8.decode(content);
    } catch (e) {
      return null;
    }
  }

  // Retorna o timestamp de modificação do arquivo no Drive, ou null se não existir
  static Future<DateTime?> getRemoteModifiedTime() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return null;

      final fileId = await _getFileId(api);
      if (fileId == null) return null;

      final file = await api.files.get(
        fileId,
        $fields: 'modifiedTime',
      ) as drive.File;

      return file.modifiedTime;
    } catch (e) {
      return null;
    }
  }

  // Busca o ID do arquivo de sync no Drive (necessário para update)
  static Future<String?> _getFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: _spaces,
      q: "name = '$_fileName'",
      $fields: 'files(id)',
    );
    return list.files?.firstOrNull?.id;
  }
}