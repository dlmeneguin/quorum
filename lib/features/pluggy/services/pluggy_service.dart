import 'dart:convert';
import 'package:http/http.dart' as http;

class PluggyService {
  static const _baseUrl = 'https://api.pluggy.ai';

  static Future<String> authenticate({
    required String clientId,
    required String clientSecret,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'clientId': clientId, 'clientSecret': clientSecret}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apiKey = data['apiKey'] as String?;
      if (apiKey == null) throw Exception('apiKey não encontrado: ${response.body}');
      return apiKey;
    }
    throw Exception('Falha na autenticação (${response.statusCode}): ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> fetchAccounts({
    required String apiKey,
    required String itemId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/accounts?itemId=$itemId'),
      headers: {'X-API-KEY': apiKey},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }
    throw Exception('Falha ao buscar contas (${response.statusCode}): ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> fetchTransactions({
    required String apiKey,
    required String accountId,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/transactions?accountId=$accountId&pageSize=$pageSize');
    final response = await http.get(uri, headers: {'X-API-KEY': apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }
    throw Exception('Falha ao buscar transações (${response.statusCode}): ${response.body}');
  }

  /// Busca transações de todas as contas de um item a partir de uma data.
  /// [since] é o timestamp em ms da última importação.
  static Future<List<Map<String, dynamic>>> fetchTransactionsSince({
    required String apiKey,
    required String itemId,
    required int sinceMs,
  }) async {
    // Converte para ISO 8601 (formato que a Pluggy aceita no parâmetro 'from')
    final sinceDate = DateTime.fromMillisecondsSinceEpoch(sinceMs).toUtc();
    final fromStr =
        '${sinceDate.year}-${sinceDate.month.toString().padLeft(2, '0')}-${sinceDate.day.toString().padLeft(2, '0')}';

    // 1. Busca todas as contas do item
    final accounts = await fetchAccounts(apiKey: apiKey, itemId: itemId);

    final allTxs = <Map<String, dynamic>>[];

    // 2. Para cada conta, busca transações desde a data
    for (final account in accounts) {
      final accountId = account['id'] as String? ?? '';
      if (accountId.isEmpty) continue;

      final uri = Uri.parse(
        '$_baseUrl/transactions?accountId=$accountId&from=$fromStr&pageSize=100',
      );
      final response = await http.get(uri, headers: {'X-API-KEY': apiKey});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results =
            (data['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        // Enriquece cada transação com o nome da conta para exibição
        for (final tx in results) {
          allTxs.add({
            ...tx,
            '_accountName': account['name'] ?? '',
            '_accountType': account['type'] ?? 'BANK',
          });
        }
      }
      // Ignora erros por conta individual — continua as outras
    }

    // 3. Filtra apenas transações estritamente após o timestamp de última importação
    // (a API filtra por dia, aqui filtramos por ms exato)
    final filtered = allTxs.where((tx) {
      final dateStr = tx['date'] as String?;
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr);
        return date.millisecondsSinceEpoch > sinceMs;
      } catch (_) {
        return false;
      }
    }).toList();

    // 4. Ordena por data asc (mais antigas primeiro)
    filtered.sort((a, b) {
      final da = DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime(2000);
      return da.compareTo(db);
    });

    return filtered;
  }

  static Future<Map<String, dynamic>?> fetchIdentity({
    required String apiKey,
    required String itemId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/identity?itemId=$itemId'),
      headers: {'X-API-KEY': apiKey},
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 404) return null;
    throw Exception('Falha ao buscar identidade (${response.statusCode}): ${response.body}');
  }
}