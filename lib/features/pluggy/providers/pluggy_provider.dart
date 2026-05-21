import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pluggy_service.dart';
import 'package:flutter/foundation.dart';

// Chaves de SharedPreferences
const prefPluggyEnabled = 'pluggy_enabled';
const prefPluggyClientId = 'pluggy_client_id';
const _prefClientSecretEnc = 'pluggy_client_secret_enc';
const prefPluggyItemId = 'pluggy_item_id';
const prefPluggyLastImport = 'pluggy_last_import';
const _prefPluggySeenIdsDate = 'pluggy_seen_ids_date';
const _prefPluggySeenIds = 'pluggy_seen_ids';

// Chave XOR para ofuscar o client_secret em repouso
const _xorKey = 'quorum_pluggy_2026';

String _xorEncrypt(String input) {
  final keyBytes = utf8.encode(_xorKey);
  final inputBytes = utf8.encode(input);
  final result = List<int>.generate(
    inputBytes.length,
    (i) => inputBytes[i] ^ keyBytes[i % keyBytes.length],
  );
  return base64.encode(result);
}

String _xorDecrypt(String encrypted) {
  try {
    final keyBytes = utf8.encode(_xorKey);
    final encryptedBytes = base64.decode(encrypted);
    final result = List<int>.generate(
      encryptedBytes.length,
      (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(result);
  } catch (_) {
    return '';
  }
}

class PluggyConfig {
  final bool enabled;
  final String clientId;
  final String clientSecret; // sempre descriptografado em memória
  final String itemId;
  final int lastImportMs;

  const PluggyConfig({
    required this.enabled,
    required this.clientId,
    required this.clientSecret,
    required this.itemId,
    required this.lastImportMs,
  });

  bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && itemId.isNotEmpty;

  PluggyConfig copyWith({
    bool? enabled,
    String? clientId,
    String? clientSecret,
    String? itemId,
    int? lastImportMs,
  }) =>
      PluggyConfig(
        enabled: enabled ?? this.enabled,
        clientId: clientId ?? this.clientId,
        clientSecret: clientSecret ?? this.clientSecret,
        itemId: itemId ?? this.itemId,
        lastImportMs: lastImportMs ?? this.lastImportMs,
      );

  /// Exporta para Map para incluir no payload de sync.
  /// O secret é SEMPRE criptografado antes de sair.
  Map<String, dynamic> toSyncMap() => {
        'pluggy_enabled': enabled,
        'pluggy_client_id': clientId,
        'pluggy_client_secret_enc': _xorEncrypt(clientSecret),
        'pluggy_item_id': itemId,
        'pluggy_last_import': lastImportMs,
      };

  /// Importa do payload de sync (secret vem criptografado).
  factory PluggyConfig.fromSyncMap(Map<String, dynamic> map) {
    final encSecret = map['pluggy_client_secret_enc'] as String? ?? '';
    return PluggyConfig(
      enabled: map['pluggy_enabled'] as bool? ?? false,
      clientId: map['pluggy_client_id'] as String? ?? '',
      clientSecret: encSecret.isEmpty ? '' : _xorDecrypt(encSecret),
      itemId: map['pluggy_item_id'] as String? ?? '',
      lastImportMs: map['pluggy_last_import'] as int? ?? 0,
    );
  }
}

class PluggyConfigNotifier extends AsyncNotifier<PluggyConfig> {
  @override
  Future<PluggyConfig> build() async => _load();

  Future<PluggyConfig> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final encSecret = prefs.getString(_prefClientSecretEnc) ?? '';
    return PluggyConfig(
      enabled: prefs.getBool(prefPluggyEnabled) ?? false,
      clientId: prefs.getString(prefPluggyClientId) ?? '',
      clientSecret: encSecret.isEmpty ? '' : _xorDecrypt(encSecret),
      itemId: prefs.getString(prefPluggyItemId) ?? '',
      lastImportMs: prefs.getInt(prefPluggyLastImport) ?? 0,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPluggyEnabled, value);
    // Recarrega o estado completo do disco para garantir consistência
    state = AsyncData(await _load());
  }

  Future<void> saveCredentials({
    required String clientId,
    required String clientSecret,
    required String itemId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefPluggyClientId, clientId);
    await prefs.setString(_prefClientSecretEnc, _xorEncrypt(clientSecret));
    await prefs.setString(prefPluggyItemId, itemId);
    state = AsyncData(await _load());
  }

  /// Aplica configuração vinda do sync remoto (secret vem criptografado no map).
  Future<void> applyFromSync(Map<String, dynamic> map) async {
    final config = PluggyConfig.fromSyncMap(map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPluggyEnabled, config.enabled);
    await prefs.setString(prefPluggyClientId, config.clientId);
    await prefs.setString(_prefClientSecretEnc, _xorEncrypt(config.clientSecret));
    await prefs.setString(prefPluggyItemId, config.itemId);
    if (config.lastImportMs > 0) {
      await prefs.setInt(prefPluggyLastImport, config.lastImportMs);
    }
    state = AsyncData(await _load());
  }

  /// Busca transações novas.
  /// Lê direto do SharedPreferences para não depender do estado async do provider.
  Future<List<Map<String, dynamic>>> fetchNewTransactions() async {
    final config = await _load();

    debugPrint('[Pluggy] fetchNewTransactions: enabled=${config.enabled}, configured=${config.isConfigured}');

    if (!config.enabled || !config.isConfigured) {
      debugPrint('[Pluggy] Pulando fetch: não habilitado ou não configurado.');
      return [];
    }

    debugPrint('[Pluggy] lastImportMs=${config.lastImportMs}');

    try {
      debugPrint('[Pluggy] Autenticando...');
      final apiKey = await PluggyService.authenticate(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
      );
      debugPrint('[Pluggy] Autenticado com sucesso.');

      final sinceMs = config.lastImportMs > 0
          ? config.lastImportMs
          : DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch;

      final sinceDate = DateTime.fromMillisecondsSinceEpoch(sinceMs);
      debugPrint('[Pluggy] Buscando transações desde: $sinceDate');

      final txs = await PluggyService.fetchTransactionsSince(
        apiKey: apiKey,
        itemId: config.itemId,
        sinceMs: sinceMs,
      );

      debugPrint('[Pluggy] Transações brutas encontradas: ${txs.length}');

      // Deduplica com base nos IDs salvos do último dia importado
      final prefs = await SharedPreferences.getInstance();
      final seenIdsDate = prefs.getString(_prefPluggySeenIdsDate) ?? '';
      final seenIds = prefs.getStringList(_prefPluggySeenIds)?.toSet() ?? <String>{};

      final filtered = txs.where((tx) {
        final id = tx['id'] as String?;
        if (id == null) return true;

        // Verifica se esta transação é do mesmo dia que os IDs salvos
        try {
          final d = DateTime.parse(tx['date'] as String? ?? '');
          final dateStr =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          if (dateStr == seenIdsDate && seenIds.contains(id)) {
            debugPrint('[Pluggy] Descartando transação já importada: $id');
            return false;
          }
        } catch (_) {}

        return true;
      }).toList();

      debugPrint('[Pluggy] Transações após deduplicação: ${filtered.length}');
      return filtered;
    } catch (e, st) {
      debugPrint('[Pluggy] Erro em fetchNewTransactions: $e\n$st');
      return [];
    }
  }
}

final pluggyConfigProvider =
    AsyncNotifierProvider<PluggyConfigNotifier, PluggyConfig>(
  PluggyConfigNotifier.new,
);