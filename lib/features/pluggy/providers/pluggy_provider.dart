import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pluggy_service.dart';

const prefPluggyEnabled = 'pluggy_enabled';
const prefPluggyClientId = 'pluggy_client_id';
const prefPluggyClientSecret = 'pluggy_client_secret';
const prefPluggyItemId = 'pluggy_item_id';
const prefPluggyLastImport = 'pluggy_last_import';

class PluggyConfig {
  final bool enabled;
  final String clientId;
  final String clientSecret;
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
}

class PluggyConfigNotifier extends AsyncNotifier<PluggyConfig> {
  @override
  Future<PluggyConfig> build() async => _load();

  Future<PluggyConfig> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return PluggyConfig(
      enabled: prefs.getBool(prefPluggyEnabled) ?? false,
      clientId: prefs.getString(prefPluggyClientId) ?? '',
      clientSecret: prefs.getString(prefPluggyClientSecret) ?? '',
      itemId: prefs.getString(prefPluggyItemId) ?? '',
      lastImportMs: prefs.getInt(prefPluggyLastImport) ?? 0,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPluggyEnabled, value);
    state = AsyncData((state.value ?? await _load()).let((c) => PluggyConfig(
          enabled: value,
          clientId: c.clientId,
          clientSecret: c.clientSecret,
          itemId: c.itemId,
          lastImportMs: c.lastImportMs,
        )));
  }

  Future<void> saveCredentials({
    required String clientId,
    required String clientSecret,
    required String itemId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefPluggyClientId, clientId);
    await prefs.setString(prefPluggyClientSecret, clientSecret);
    await prefs.setString(prefPluggyItemId, itemId);
    state = AsyncData(PluggyConfig(
      enabled: state.value?.enabled ?? false,
      clientId: clientId,
      clientSecret: clientSecret,
      itemId: itemId,
      lastImportMs: state.value?.lastImportMs ?? 0,
    ));
  }

  /// Busca transações novas. Retorna lista vazia se não configurado ou desabilitado.
  Future<List<Map<String, dynamic>>> fetchNewTransactions() async {
    final config = state.value;
    if (config == null || !config.enabled || !config.isConfigured) return [];

    try {
      final apiKey = await PluggyService.authenticate(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
      );

      // Se nunca importou, pega os últimos 30 dias
      final sinceMs = config.lastImportMs > 0
          ? config.lastImportMs
          : DateTime.now()
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch;

      return await PluggyService.fetchTransactionsSince(
        apiKey: apiKey,
        itemId: config.itemId,
        sinceMs: sinceMs,
      );
    } catch (_) {
      return [];
    }
  }
}

// Extensão auxiliar para o let
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

final pluggyConfigProvider =
    AsyncNotifierProvider<PluggyConfigNotifier, PluggyConfig>(
  PluggyConfigNotifier.new,
);