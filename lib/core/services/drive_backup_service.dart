import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveBackupService {
  static const _fileName = 'quorum_sync.json';
  static const _mimeType = 'application/json';
  static const _spaces = 'appDataFolder';

  static Future<bool> upload(String jsonContent) async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) {
        debugPrint('[Drive] upload: getDriveApi retornou null.');
        return false;
      }

      final encoded = utf8.encode(jsonContent);
      final existingId = await _getFileId(api);

      final media = drive.Media(
        Stream.value(encoded),
        encoded.length,
        contentType: _mimeType,
      );

      if (existingId != null) {
        debugPrint('[Drive] Atualizando arquivo existente: $existingId');
        await api.files.update(
          drive.File(),
          existingId,
          uploadMedia: media,
        );
      } else {
        debugPrint('[Drive] Criando novo arquivo no Drive.');
        final file = drive.File()
          ..name = _fileName
          ..parents = [_spaces];
        await api.files.create(file, uploadMedia: media);
      }

      debugPrint('[Drive] Upload concluído.');
      return true;
    } catch (e, st) {
      debugPrint('[Drive] Erro em upload: $e\n$st');
      return false;
    }
  }

  static Future<String?> download() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) {
        debugPrint('[Drive] download: getDriveApi retornou null.');
        return null;
      }

      final fileId = await _getFileId(api);
      if (fileId == null) {
        debugPrint('[Drive] download: arquivo não encontrado no Drive.');
        return null;
      }

      debugPrint('[Drive] Baixando arquivo: $fileId');
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.toList();
      final content = bytes.expand((b) => b).toList();
      debugPrint('[Drive] Download concluído (${content.length} bytes).');
      return utf8.decode(content);
    } catch (e, st) {
      debugPrint('[Drive] Erro em download: $e\n$st');
      return null;
    }
  }

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
    } catch (e, st) {
      debugPrint('[Drive] Erro em getRemoteModifiedTime: $e\n$st');
      return null;
    }
  }

  static Future<String?> _getFileId(drive.DriveApi api) async {
    try {
      final list = await api.files.list(
        spaces: _spaces,
        q: "name = '$_fileName'",
        $fields: 'files(id)',
      );
      final id = list.files?.firstOrNull?.id;
      debugPrint('[Drive] _getFileId: $id');
      return id;
    } catch (e, st) {
      debugPrint('[Drive] Erro em _getFileId: $e\n$st');
      return null;
    }
  }
}