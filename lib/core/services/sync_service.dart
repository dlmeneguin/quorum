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
  bool _isSyncing = false;

  static const _lastSyncKey = 'last_sync_timestamp';

  SyncService(this.db) : _merge = MergeService(db);

  Future<void> checkAndPullOnStartup() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) {
      debugPrint('[Sync] Usuário não autenticado, pulando sync de startup.');
      return;
    }

    debugPrint('[Sync] Usuário autenticado: $email. Verificando Drive...');

    try {
      final remoteTime = await DriveBackupService.getRemoteModifiedTime();
      if (remoteTime == null) {
        debugPrint('[Sync] Nenhum arquivo no Drive. Fazendo primeiro upload.');
        await _doUpload();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

      debugPrint('[Sync] Drive modificado em: $remoteTime. Último sync local: $lastSync.');

      if (remoteTime.isAfter(lastSync)) {
        debugPrint('[Sync] Drive mais recente. Iniciando merge.');
        await _doMerge();
      } else {
        debugPrint('[Sync] Local já está atualizado.');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em checkAndPullOnStartup: $e\n$st');
    }
  }

  void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[Sync] Debounce disparado. Iniciando upload.');
      _doUpload();
    });
    debugPrint('[Sync] Upload agendado em 30s.');
  }

  Future<void> forceUpload() async {
    _debounceTimer?.cancel();
    debugPrint('[Sync] forceUpload chamado.');
    await _doUpload();
  }

  Future<void> _doUpload() async {
    if (_isSyncing) {
      debugPrint('[Sync] Já sincronizando, ignorando.');
      return;
    }
    _isSyncing = true;

    try {
      final email = await GoogleAuthService.currentUserEmail();
      if (email == null) {
        debugPrint('[Sync] _doUpload: usuário não autenticado.');
        return;
      }

      debugPrint('[Sync] Exportando JSON...');
      final json = await _merge.exportToJson();
      debugPrint('[Sync] JSON exportado (${json.length} bytes). Fazendo upload...');

      final success = await DriveBackupService.upload(json);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[Sync] Upload concluído com sucesso.');
      } else {
        debugPrint('[Sync] Upload falhou (DriveBackupService.upload retornou false).');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doUpload: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _doMerge() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('[Sync] Baixando JSON do Drive...');
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) {
        debugPrint('[Sync] Download retornou null.');
        return;
      }

      debugPrint('[Sync] Merge iniciado...');
      final mergedJson = await _merge.mergeFromJson(remoteJson);

      debugPrint('[Sync] Merge concluído. Fazendo upload do estado merged...');
      await DriveBackupService.upload(mergedJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[Sync] Sync completo.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doMerge: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}