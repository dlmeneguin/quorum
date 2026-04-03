import 'dart:async';
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

  // Chave para guardar o timestamp do último upload local
  static const _lastSyncKey = 'last_sync_timestamp';

  SyncService(this.db) : _merge = MergeService(db);

  // Chamado na inicialização do app — verifica se o Drive tem dados mais novos
  Future<void> checkAndPullOnStartup() async {
    final user = await GoogleAuthService.currentUser();
    if (user == null) return; // não autenticado, pula

    try {
      final remoteTime = await DriveBackupService.getRemoteModifiedTime();
      if (remoteTime == null) {
        // Nenhum arquivo no Drive ainda — faz o primeiro upload
        await _doUpload();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

      if (remoteTime.isAfter(lastSync)) {
        // Drive tem dados mais novos — baixar e fazer merge
        await _doMerge();
      }
    } catch (_) {
      // Falha silenciosa — o app funciona offline normalmente
    }
  }

  // Agenda um upload com debounce de 30 segundos
  // Chamado após qualquer operação de escrita no banco
  void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), () {
      _doUpload();
    });
  }

  // Upload imediato (sem debounce) — para uso em logout ou fechamento do app
  Future<void> forceUpload() async {
    _debounceTimer?.cancel();
    await _doUpload();
  }

  Future<void> _doUpload() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = await GoogleAuthService.currentUser();
      if (user == null) return;

      final json = await _merge.exportToJson();
      final success = await DriveBackupService.upload(json);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            _lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {
      // Falha silenciosa
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

      // Merge retorna o JSON do estado merged
      final mergedJson = await _merge.mergeFromJson(remoteJson);

      // Faz upload do estado merged imediatamente
      await DriveBackupService.upload(mergedJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Falha silenciosa
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}