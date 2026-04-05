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

  static const _lastSyncKey = 'last_sync_timestamp';
  static const _checkInterval = Duration(seconds: 30);

  SyncService(this.db) : _merge = MergeService(db);

  /// Chamado na inicialização do app.
  /// Inicia o timer periódico e faz sync normal (merge) se já autenticado.
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

  /// Chamado APENAS quando o usuário clica em "Conectar com Google".
  /// Drive vence completamente se tiver dados — overwrite local.
  /// Se Drive estiver vazio, faz upload dos dados locais.
  Future<void> onUserConnected() async {
    debugPrint('[Sync] Usuário acabou de conectar. Verificando Drive...');

    try {
      final hasReset = await DriveBackupService.hasResetSignal();
      if (hasReset) {
        await DriveBackupService.deleteResetSignal();
      }

      final remoteTime = await DriveBackupService.getRemoteModifiedTime();

      if (remoteTime == null) {
        // Drive vazio — este é o primeiro dispositivo
        debugPrint('[Sync] Drive vazio. Fazendo upload inicial dos dados locais.');
        await _doUpload();
      } else {
        // Drive tem dados — overwrite completo nos dados locais
        debugPrint('[Sync] Drive tem dados. Aplicando overwrite nos dados locais.');
        await _doOverwrite();
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em onUserConnected: $e\n$st');
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

  Future<void> deleteSyncData() async {
    try {
      debugPrint('[Sync] Apagando dados de sync do Drive...');
      await DriveBackupService.deleteAllAndSignalReset();
      await _disconnectLocally();
      debugPrint('[Sync] Dados apagados e sinal enviado.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em deleteSyncData: $e\n$st');
    }
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  /// Sync normal — usado pelo startup e pelo timer periódico.
  /// Compara timestamps e faz merge se Drive for mais recente.
  Future<void> _checkAndSync() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) return;

    try {
      final hasReset = await DriveBackupService.hasResetSignal();
      if (hasReset) {
        debugPrint('[Sync] Sinal de reset detectado. Desconectando...');
        await _handleResetSignal();
        return;
      }

      final remoteTime = await DriveBackupService.getRemoteModifiedTime();

      if (remoteTime == null) {
        // Drive vazio — faz upload dos dados locais
        debugPrint('[Sync] Drive vazio. Fazendo upload.');
        await _doUpload();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

      debugPrint('[Sync] Drive: $remoteTime | Último sync local: $lastSync');

      if (remoteTime.isAfter(lastSync)) {
        // Drive tem dados mais recentes — merge
        debugPrint('[Sync] Drive mais recente. Iniciando merge.');
        await _doMerge();
      } else {
        debugPrint('[Sync] Local já está atualizado.');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _checkAndSync: $e\n$st');
    }
  }

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) async {
      debugPrint('[Sync] Checagem periódica.');
      await _checkAndSync();
    });
    debugPrint('[Sync] Timer periódico iniciado (${_checkInterval.inMinutes}min).');
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
        debugPrint('[Sync] _doUpload: não autenticado.');
        return;
      }

      final json = await _merge.exportToJson();
      debugPrint('[Sync] Fazendo upload (${json.length} bytes)...');

      final success = await DriveBackupService.upload(json);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[Sync] Upload concluído.');
      } else {
        debugPrint('[Sync] Upload falhou.');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doUpload: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  /// Overwrite completo — Drive vence, dados locais são substituídos.
  /// Usado apenas no fluxo de conexão explícita do usuário.
  Future<void> _doOverwrite() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) {
        debugPrint('[Sync] _doOverwrite: download retornou null.');
        return;
      }

      debugPrint('[Sync] Aplicando overwrite completo...');
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

  /// Merge — last updatedAt wins por registro.
  /// Usado pelo sync periódico e startup.
  Future<void> _doMerge() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) {
        debugPrint('[Sync] _doMerge: download retornou null.');
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

  Future<void> _handleResetSignal() async {
    try {
      await DriveBackupService.deleteResetSignal();
      await _disconnectLocally();
      debugPrint('[Sync] Reset processado.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em _handleResetSignal: $e\n$st');
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