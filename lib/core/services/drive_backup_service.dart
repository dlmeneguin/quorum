import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveBackupService {
  static const _fileName      = 'quorum_sync.json';
  static const _resetFileName = 'quorum_reset_signal.json';
  static const _mimeType      = 'application/json';
  static const _spaces        = 'appDataFolder';

  // Tempo que o sinal de reset permanece no Drive.
  // Suficiente para todos os dispositivos verem, mesmo os inativos por dias.
  static const _resetSignalTtl = Duration(days: 30);

  // ── Upload / Download principal ───────────────────────────────────────────

  static Future<bool> upload(String jsonContent) async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return false;

      final encoded    = utf8.encode(jsonContent);
      final existingId = await _getFileId(api, _fileName);

      final media = drive.Media(
        Stream.value(encoded),
        encoded.length,
        contentType: _mimeType,
      );

      if (existingId != null) {
        await api.files.update(drive.File(), existingId, uploadMedia: media);
      } else {
        final file = drive.File()
          ..name    = _fileName
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

  /// Retorna o timestamp do reset se existir um sinal válido (dentro do TTL),
  /// ou null se não houver sinal ou se ele já expirou.
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

      // Se o sinal expirou (TTL), ignora — dispositivo ficou inativo demais
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

  /// Apaga o arquivo de sync principal e grava o sinal de reset com timestamp.
  /// O sinal NÃO é apagado por quem o processa — fica no Drive pelo TTL.
  static Future<void> deleteAllAndSignalReset() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return;

      // Apaga o arquivo de sync principal
      final syncId = await _getFileId(api, _fileName);
      if (syncId != null) {
        await api.files.delete(syncId);
        debugPrint('[Drive] Arquivo de sync apagado.');
      }

      // Grava (ou sobrescreve) o sinal de reset com o timestamp atual
      await _writeResetSignal(api);

      debugPrint('[Drive] Sinal de reset gravado com timestamp.');
    } catch (e, st) {
      debugPrint('[Drive] Erro em deleteAllAndSignalReset: $e\n$st');
    }
  }

  static Future<void> _writeResetSignal(drive.DriveApi api) async {
    final content = utf8.encode(
      jsonEncode({'resetAt': DateTime.now().toUtc().toIso8601String()}),
    );
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