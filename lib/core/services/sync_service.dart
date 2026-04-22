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

  /// Chamado quando o usuário clica em "Conectar com Google".
  /// Sempre faz overwrite se o Drive tiver dados — o usuário está
  /// se conectando "do zero" neste dispositivo.
  Future<void> onUserConnected() async {
    debugPrint('[Sync] Usuário conectou. Verificando Drive...');

    try {
      final remoteTime = await DriveBackupService.getRemoteModifiedTime();

      if (remoteTime == null) {
        // Drive vazio — este dispositivo envia os dados locais
        debugPrint('[Sync] Drive vazio. Upload inicial.');
        await _doUpload();
      } else {
        // Drive tem dados — overwrite completo nos dados locais
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
    debugPrint('[Sync] Upload agendado em 30s.');
  }

  Future<void> forceUpload() async {
    _debounceTimer?.cancel();
    await _doUpload();
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

  /// Lógica central de sync periódico e startup.
  /// Verifica o sinal de reset ANTES de decidir merge ou upload.
  Future<void> _checkAndSync() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) return;

    try {
      // ── Passo 1: verifica sinal de reset no Drive ──
      final resetAt = await DriveBackupService.getResetSignalTime();

      if (resetAt != null) {
        final prefs     = await SharedPreferences.getInstance();
        final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
        final lastSync  = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

        if (resetAt.isAfter(lastSync)) {
          // O reset aconteceu DEPOIS da última sincronização deste dispositivo.
          // Este dispositivo estava inativo quando o reset ocorreu.
          // Deve desconectar — o usuário precisará reconectar manualmente.
          debugPrint(
            '[Sync] Reset detectado (resetAt=$resetAt > lastSync=$lastSync). '
            'Desconectando dispositivo.',
          );
          await _disconnectLocally();
          return;
        } else {
          // O reset é mais antigo que o último sync — este dispositivo já
          // estava sincronizado após o reset (provavelmente foi quem causou).
          debugPrint('[Sync] Reset antigo (anterior ao último sync). Ignorando.');
        }
      }

      // ── Passo 2: sync normal ──
      final remoteTime = await DriveBackupService.getRemoteModifiedTime();

      if (remoteTime == null) {
        // Drive vazio — faz upload
        debugPrint('[Sync] Drive vazio. Fazendo upload.');
        await _doUpload();
        return;
      }

      final prefs      = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
      final lastSync   = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

      if (remoteTime.isAfter(lastSync)) {
        debugPrint('[Sync] Drive mais recente. Merge.');
        await _doMerge();
      } else {
        debugPrint('[Sync] Local já atualizado.');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _checkAndSync: $e\n$st');
    }
  }

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) => _checkAndSync());
  }

  Future<void> _doUpload() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final email = await GoogleAuthService.currentUserEmail();
      if (email == null) return;

      final json    = await _merge.exportToJson();
      final success = await DriveBackupService.upload(json);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[Sync] Upload concluído.');
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[Sync] Overwrite concluído.');
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
      await DriveBackupService.upload(mergedJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[Sync] Merge + upload concluídos.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doMerge: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _disconnectLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    await GoogleAuthService.signOut();
    debugPrint('[Sync] Desconectado localmente.');
  }

  void dispose() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
  }
}