import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveBackupService {
  static const _fileName      = 'quorum_sync.json';
  static const _resetFileName = 'quorum_reset_signal.json';
  static const _mimeType      = 'application/json';
  static const _spaces        = 'appDataFolder';

  // Chave usada em appProperties para guardar o hash do conteúdo
  static const _hashPropKey   = 'content_sha256';

  static const _resetSignalTtl = Duration(days: 30);

  // ── Hash ─────────────────────────────────────────────────────────────────

  /// Calcula SHA-256 do conteúdo JSON como hex string.
  static String computeHash(String jsonContent) {
    final bytes = utf8.encode(jsonContent);
    return sha256.convert(bytes).toString();
  }

  /// Busca o hash armazenado nos metadados (appProperties) do arquivo no Drive.
  /// Retorna null se o arquivo não existir ou não tiver hash.
  static Future<String?> getRemoteHash() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return null;

      final fileId = await _getFileId(api, _fileName);
      if (fileId == null) return null;

      final file = await api.files.get(
        fileId,
        $fields: 'appProperties',
      ) as drive.File;

      return file.appProperties?[_hashPropKey];
    } catch (e, st) {
      debugPrint('[Drive] Erro em getRemoteHash: $e\n$st');
      return null;
    }
  }

  // ── Upload / Download principal ───────────────────────────────────────────

  /// Faz upload do JSON para o Drive.
  /// Se [forceUpload] for false (padrão), compara o hash local com o remoto
  /// e pula o upload se o conteúdo for idêntico.
  /// Retorna true se o upload foi realizado ou o conteúdo já era igual.
  static Future<bool> upload(
    String jsonContent, {
    bool forceUpload = false,
  }) async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return false;

      final localHash = computeHash(jsonContent);

      // ── Verificação de hash: evita upload desnecessário ──
      if (!forceUpload) {
        final existingId = await _getFileId(api, _fileName);
        if (existingId != null) {
          final remoteFile = await api.files.get(
            existingId,
            $fields: 'appProperties',
          ) as drive.File;
          final remoteHash = remoteFile.appProperties?[_hashPropKey];

          if (remoteHash != null && remoteHash == localHash) {
            debugPrint('[Drive] Hash idêntico ao remoto. Upload ignorado.');
            return true;
          }
        }
      }

      // ── Realiza o upload ──
      final encoded = utf8.encode(jsonContent) as Uint8List;
      final existingId = await _getFileId(api, _fileName);

      final media = drive.Media(
        Stream.value(encoded),
        encoded.length,
        contentType: _mimeType,
      );

      // Metadados com o hash do conteúdo
      final fileMeta = drive.File()
        ..appProperties = {_hashPropKey: localHash};

      if (existingId != null) {
        await api.files.update(
          fileMeta,
          existingId,
          uploadMedia: media,
        );
      } else {
        fileMeta.name    = _fileName;
        fileMeta.parents = [_spaces];
        await api.files.create(fileMeta, uploadMedia: media);
      }

      debugPrint('[Drive] Upload concluído. hash=$localHash');
      return true;
    } catch (e, st) {
      debugPrint('[Drive] Erro em upload: $e\n$st');
      return false;
    }
  }

  static Future<String?> download() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return null;

      final fileId = await _getFileId(api, _fileName);
      if (fileId == null) return null;

      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes   = await response.stream.toList();
      final content = bytes.expand((b) => b).toList();
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

      final fileId = await _getFileId(api, _fileName);
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

  // ── Reset signal ──────────────────────────────────────────────────────────

  static Future<DateTime?> getResetSignalTime() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return null;

      final fileId = await _getFileId(api, _resetFileName);
      if (fileId == null) return null;

      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes   = await response.stream.toList();
      final content = utf8.decode(bytes.expand((b) => b).toList());
      final data    = jsonDecode(content) as Map<String, dynamic>;

      final resetAtStr = data['resetAt'] as String?;
      if (resetAtStr == null) return null;

      final resetAt = DateTime.parse(resetAtStr);

      if (DateTime.now().difference(resetAt) > _resetSignalTtl) {
        debugPrint('[Drive] Sinal de reset expirado (>30 dias), ignorando.');
        return null;
      }

      return resetAt;
    } catch (e) {
      debugPrint('[Drive] Erro em getResetSignalTime: $e');
      return null;
    }
  }

  static Future<void> deleteAllAndSignalReset() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return;

      final syncId = await _getFileId(api, _fileName);
      if (syncId != null) {
        await api.files.delete(syncId);
        debugPrint('[Drive] Arquivo de sync apagado.');
      }

      await _writeResetSignal(api);
      debugPrint('[Drive] Sinal de reset gravado com timestamp.');
    } catch (e, st) {
      debugPrint('[Drive] Erro em deleteAllAndSignalReset: $e\n$st');
    }
  }

  static Future<void> _writeResetSignal(drive.DriveApi api) async {
    final content = utf8.encode(
      jsonEncode({'resetAt': DateTime.now().toUtc().toIso8601String()}),
    ) as Uint8List;
    final media = drive.Media(
      Stream.value(content),
      content.length,
      contentType: _mimeType,
    );

    final existingId = await _getFileId(api, _resetFileName);
    if (existingId != null) {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      final file = drive.File()
        ..name    = _resetFileName
        ..parents = [_spaces];
      await api.files.create(file, uploadMedia: media);
    }
  }

  // ── Helper interno ────────────────────────────────────────────────────────

  static Future<String?> _getFileId(drive.DriveApi api, String fileName) async {
    try {
      final list = await api.files.list(
        spaces: _spaces,
        q: "name = '$fileName'",
        $fields: 'files(id)',
      );
      return list.files?.firstOrNull?.id;
    } catch (e, st) {
      debugPrint('[Drive] Erro em _getFileId($fileName): $e\n$st');
      return null;
    }
  }
}