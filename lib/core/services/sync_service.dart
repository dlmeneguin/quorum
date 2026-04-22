import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'drive_backup_service.dart';
import 'google_auth_service.dart';
import 'merge_service.dart';

class SyncService {
  final AppDatabase db;
  final MergeService _merge;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  static const _lastSyncKey   = 'last_sync_timestamp';
  // Hash do último JSON que este dispositivo enviou ao Drive
  static const _lastUploadHashKey = 'last_upload_hash';
  static const _checkInterval = Duration(seconds: 30);

  SyncService(this.db) : _merge = MergeService(db);

  Future<void> checkAndPullOnStartup() async {
    _startPeriodicCheck();

    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) {
      debugPrint('[Sync] Não autenticado, pulando sync de startup.');
      return;
    }

    debugPrint('[Sync] Autenticado: $email. Verificando Drive...');
    await _checkAndSync();
  }

  Future<void> onUserConnected() async {
    debugPrint('[Sync] Usuário conectou. Verificando Drive...');
    try {
      final remoteTime = await DriveBackupService.getRemoteModifiedTime();
      if (remoteTime == null) {
        debugPrint('[Sync] Drive vazio. Upload inicial.');
        await _doUpload();
      } else {
        debugPrint('[Sync] Drive tem dados. Overwrite local.');
        await _doOverwrite();
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em onUserConnected: $e\n$st');
    }
  }

  void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), _doUpload);
    debugPrint('[Sync] Upload agendado em 10s.');
  }

  Future<void> forceUpload() async {
    _debounceTimer?.cancel();
    await _doUpload(force: true);
  }

  Future<void> deleteSyncData() async {
    try {
      _debounceTimer?.cancel();
      debugPrint('[Sync] Apagando dados de sync do Drive...');
      await DriveBackupService.deleteAllAndSignalReset();
      await _disconnectLocally();
      debugPrint('[Sync] Dados apagados e sinal de reset gravado.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em deleteSyncData: $e\n$st');
    }
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  Future<void> _checkAndSync() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) return;

    try {
      // ── Passo 1: verifica sinal de reset no Drive ──
      final resetAt = await DriveBackupService.getResetSignalTime();

      if (resetAt != null) {
        final prefs      = await SharedPreferences.getInstance();
        final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
        final lastSync   = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

        if (resetAt.isAfter(lastSync)) {
          debugPrint(
            '[Sync] Reset detectado (resetAt=$resetAt > lastSync=$lastSync). '
            'Desconectando dispositivo.',
          );
          await _disconnectLocally();
          return;
        } else {
          debugPrint('[Sync] Reset antigo (anterior ao último sync). Ignorando.');
        }
      }

      // ── Passo 2: compara hash local com hash remoto ──
      final remoteHash = await DriveBackupService.getRemoteHash();

      if (remoteHash == null) {
        // Drive vazio — faz upload
        debugPrint('[Sync] Drive vazio. Fazendo upload.');
        await _doUpload();
        return;
      }

      final prefs          = await SharedPreferences.getInstance();
      final lastUploadHash = prefs.getString(_lastUploadHashKey);

      if (remoteHash == lastUploadHash) {
        // O Drive contém exatamente o que este dispositivo enviou por último.
        // Nenhum outro dispositivo alterou o conteúdo — nada a fazer.
        debugPrint('[Sync] Hash remoto igual ao último upload. Já sincronizado.');
        return;
      }

      // ── Passo 3: conteúdo remoto é diferente — precisa de merge ──
      // (outro dispositivo subiu algo novo)
      debugPrint('[Sync] Hash remoto diferente. Fazendo merge.');
      await _doMerge();
    } catch (e, st) {
      debugPrint('[Sync] Erro em _checkAndSync: $e\n$st');
    }
  }

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) => _checkAndSync());
  }

  /// [force] = true ignora a comparação de hash e sempre sobe.
  /// Use apenas no `forceUpload()` chamado manualmente pelo usuário.
  Future<void> _doUpload({bool force = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final email = await GoogleAuthService.currentUserEmail();
      if (email == null) return;

      final json    = await _merge.exportToJson();
      final success = await DriveBackupService.upload(
        json,
        forceUpload: force,
      );

      if (success) {
        final hash  = DriveBackupService.computeHash(json);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setString(_lastUploadHashKey, hash);
        debugPrint('[Sync] Upload concluído. hash=$hash');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doUpload: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _doOverwrite() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) return;

      await _merge.overwriteFromJson(remoteJson);

      // Após overwrite, o estado local agora espelha o remoto.
      // Salva o hash do remoto como "último upload" para que o periódico
      // não ache que há diferença.
      final hash  = DriveBackupService.computeHash(remoteJson);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_lastUploadHashKey, hash);
      debugPrint('[Sync] Overwrite concluído. hash=$hash');
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doOverwrite: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _doMerge() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) return;

      final mergedJson = await _merge.mergeFromJson(remoteJson);

      // Compara o JSON mesclado com o remoto:
      // se forem idênticos (sem novidades locais), não faz upload.
      final mergedHash = DriveBackupService.computeHash(mergedJson);
      final remoteHash = DriveBackupService.computeHash(remoteJson);

      if (mergedHash == remoteHash) {
        // Merge não produziu diferenças — apenas atualiza o estado local.
        debugPrint('[Sync] Merge sem diferenças. Nenhum upload necessário.');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setString(_lastUploadHashKey, mergedHash);
        return;
      }

      // Há diferenças — sobe o JSON mesclado.
      final success = await DriveBackupService.upload(mergedJson);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setString(_lastUploadHashKey, mergedHash);
        debugPrint('[Sync] Merge + upload concluídos. hash=$mergedHash');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doMerge: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _disconnectLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_lastUploadHashKey);
    await GoogleAuthService.signOut();
    debugPrint('[Sync] Desconectado localmente.');
  }

  void dispose() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
  }
}