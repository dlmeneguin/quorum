import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pluggy_service.dart';

// Chaves de SharedPreferences
const prefPluggyEnabled = 'pluggy_enabled';
const prefPluggyClientId = 'pluggy_client_id';
const _prefClientSecretEnc = 'pluggy_client_secret_enc';
const prefPluggyItemId = 'pluggy_item_id';
const prefPluggyLastImport = 'pluggy_last_import';

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
    // Lê sempre direto do disco — evita problema de state.value ser null
    final config = await _load();

    if (!config.enabled || !config.isConfigured) return [];

    try {
      final apiKey = await PluggyService.authenticate(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
      );

      // Se nunca importou, pega os últimos 2 dias
      final sinceMs = config.lastImportMs > 0
          ? config.lastImportMs
          : DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch;

      return await PluggyService.fetchTransactionsSince(
        apiKey: apiKey,
        itemId: config.itemId,
        sinceMs: sinceMs,
      );
    } catch (e) {
      // Silencia erros de rede na inicialização — não deve travar o app
      return [];
    }
  }
}

final pluggyConfigProvider =
    AsyncNotifierProvider<PluggyConfigNotifier, PluggyConfig>(
  PluggyConfigNotifier.new,
);