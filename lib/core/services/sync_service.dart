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
  // Intervalo de checagem periódica — 5 minutos
  static const _checkInterval = Duration(minutes: 5);

  SyncService(this.db) : _merge = MergeService(db);

  /// Chamado na inicialização do app.
  /// Também inicia o timer periódico de checagem.
  Future<void> checkAndPullOnStartup() async {
    // Inicia o timer periódico independentemente de estar autenticado
    _startPeriodicCheck();

    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) {
      debugPrint('[Sync] Usuário não autenticado, pulando sync de startup.');
      return;
    }

    debugPrint('[Sync] Usuário autenticado: $email. Verificando Drive...');
    await _checkAndSync();
  }

  /// Checagem periódica — chamada pelo timer a cada _checkInterval.
  Future<void> _checkAndSync() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) return;

    try {
      // Verifica se existe sinal de reset no Drive
      final hasReset = await DriveBackupService.hasResetSignal();
      if (hasReset) {
        debugPrint('[Sync] Sinal de reset detectado. Desconectando...');
        await _handleResetSignal();
        return;
      }

      final remoteTime = await DriveBackupService.getRemoteModifiedTime();
      if (remoteTime == null) {
        // Drive vazio — este é o dispositivo principal, faz upload
        debugPrint('[Sync] Drive vazio. Fazendo primeiro upload.');
        await _doUpload();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;

      if (lastSyncMs == 0) {
        // Nunca sincronizou neste dispositivo — Drive vence completamente
        debugPrint('[Sync] Primeiro sync neste dispositivo. Aplicando overwrite do Drive.');
        await _doOverwrite();
        return;
      }

      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      debugPrint('[Sync] Drive modificado em: $remoteTime. Último sync: $lastSync.');

      if (remoteTime.isAfter(lastSync)) {
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
      debugPrint('[Sync] Checagem periódica disparada.');
      await _checkAndSync();
    });
    debugPrint('[Sync] Timer periódico iniciado (intervalo: $_checkInterval).');
  }

  /// Agenda upload com debounce de 30s após qualquer escrita local.
  void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[Sync] Debounce disparado. Iniciando upload.');
      _doUpload();
    });
    debugPrint('[Sync] Upload agendado em 30s.');
  }

  /// Upload imediato — para uso no botão "Sincronizar agora".
  Future<void> forceUpload() async {
    _debounceTimer?.cancel();
    debugPrint('[Sync] forceUpload chamado.');
    await _doUpload();
  }

  /// Apaga todos os dados de sync do Drive e cria sinal de reset.
  /// Depois desconecta localmente.
  Future<void> deleteSyncData() async {
    try {
      debugPrint('[Sync] Apagando dados de sync do Drive...');
      await DriveBackupService.deleteAllAndSignalReset();
      await _disconnectLocally();
      debugPrint('[Sync] Dados de sync apagados e sinal enviado.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em deleteSyncData: $e\n$st');
    }
  }

  // ── Privados ──────────────────────────────────────────────────────────────

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
        debugPrint('[Sync] Upload falhou.');
      }
    } catch (e, st) {
      debugPrint('[Sync] Erro em _doUpload: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  /// Overwrite: Drive vence completamente. Apaga tudo local e importa do Drive.
  Future<void> _doOverwrite() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final remoteJson = await DriveBackupService.download();
      if (remoteJson == null) {
        debugPrint('[Sync] _doOverwrite: download retornou null.');
        return;
      }

      debugPrint('[Sync] Aplicando overwrite completo do Drive...');
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

  Future<void> _handleResetSignal() async {
    try {
      // Apaga o sinal do Drive para não processar de novo
      await DriveBackupService.deleteResetSignal();
      await _disconnectLocally();
      debugPrint('[Sync] Reset processado com sucesso.');
    } catch (e, st) {
      debugPrint('[Sync] Erro em _handleResetSignal: $e\n$st');
    }
  }

  Future<void> _disconnectLocally() async {
    // Limpa o timestamp local para que na próxima conexão
    // o dispositivo saiba que precisa de overwrite
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    // Desconecta da conta Google
    await GoogleAuthService.signOut();
    debugPrint('[Sync] Desconectado localmente.');
  }

  void dispose() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
  }
}