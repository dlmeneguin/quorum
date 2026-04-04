import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveBackupService {
  static const _fileName        = 'quorum_sync.json';
  static const _resetFileName   = 'quorum_reset_signal.json';
  static const _mimeType        = 'application/json';
  static const _spaces          = 'appDataFolder';

  // ── Upload / Download principal ───────────────────────────────────────────

  static Future<bool> upload(String jsonContent) async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) {
        debugPrint('[Drive] upload: getDriveApi retornou null.');
        return false;
      }

      final encoded     = utf8.encode(jsonContent);
      final existingId  = await _getFileId(api, _fileName);

      final media = drive.Media(
        Stream.value(encoded),
        encoded.length,
        contentType: _mimeType,
      );

      if (existingId != null) {
        debugPrint('[Drive] Atualizando arquivo existente: $existingId');
        await api.files.update(drive.File(), existingId, uploadMedia: media);
      } else {
        debugPrint('[Drive] Criando novo arquivo no Drive.');
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
      if (api == null) {
        debugPrint('[Drive] download: getDriveApi retornou null.');
        return null;
      }

      final fileId = await _getFileId(api, _fileName);
      if (fileId == null) {
        debugPrint('[Drive] download: arquivo não encontrado.');
        return null;
      }

      debugPrint('[Drive] Baixando arquivo: $fileId');
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes   = await response.stream.toList();
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

  /// Retorna true se existe um arquivo de sinal de reset no Drive.
  static Future<bool> hasResetSignal() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return false;
      final id = await _getFileId(api, _resetFileName);
      return id != null;
    } catch (e) {
      debugPrint('[Drive] Erro em hasResetSignal: $e');
      return false;
    }
  }

  /// Apaga o arquivo de sync principal e cria o sinal de reset.
  /// Chamado quando o usuário quer apagar os dados de sync de todos os dispositivos.
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

      // Cria o sinal de reset
      final resetContent = utf8.encode(
        jsonEncode({'resetAt': DateTime.now().toIso8601String()}),
      );
      final media = drive.Media(
        Stream.value(resetContent),
        resetContent.length,
        contentType: _mimeType,
      );

      // Verifica se já existe sinal anterior e sobrescreve
      final existingResetId = await _getFileId(api, _resetFileName);
      if (existingResetId != null) {
        await api.files.update(drive.File(), existingResetId, uploadMedia: media);
      } else {
        final file = drive.File()
          ..name    = _resetFileName
          ..parents = [_spaces];
        await api.files.create(file, uploadMedia: media);
      }

      debugPrint('[Drive] Sinal de reset criado.');
    } catch (e, st) {
      debugPrint('[Drive] Erro em deleteAllAndSignalReset: $e\n$st');
    }
  }

  /// Apaga apenas o arquivo de sinal de reset.
  /// Chamado após um dispositivo processar o reset.
  static Future<void> deleteResetSignal() async {
    try {
      final api = await GoogleAuthService.getDriveApi();
      if (api == null) return;
      final id = await _getFileId(api, _resetFileName);
      if (id != null) {
        await api.files.delete(id);
        debugPrint('[Drive] Sinal de reset apagado do Drive.');
      }
    } catch (e, st) {
      debugPrint('[Drive] Erro em deleteResetSignal: $e\n$st');
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
      final id = list.files?.firstOrNull?.id;
      debugPrint('[Drive] _getFileId($fileName): $id');
      return id;
    } catch (e, st) {
      debugPrint('[Drive] Erro em _getFileId($fileName): $e\n$st');
      return null;
    }
  }
}