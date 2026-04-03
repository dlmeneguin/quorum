import 'dart:convert';
import 'package:http/http.dart' as http;

class PluggyService {
  static const _baseUrl = 'https://api.pluggy.ai';

  // Autentica com client_id + client_secret e retorna o apiKey (válido 2h)
  static Future<String> authenticate({
    required String clientId,
    required String clientSecret,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientId': clientId,
        'clientSecret': clientSecret,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apiKey = data['apiKey'] as String?;
      if (apiKey == null) {
        throw Exception('apiKey não encontrado na resposta: ${response.body}');
      }
      return apiKey;
    } else {
      throw Exception(
        'Falha na autenticação (${response.statusCode}): ${response.body}',
      );
    }
  }

  // Busca as contas vinculadas a um itemId
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
      final results = data['results'] as List<dynamic>? ?? [];
      return results.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Falha ao buscar contas (${response.statusCode}): ${response.body}',
      );
    }
  }

  // Busca as transações de uma conta específica (últimas 500)
  static Future<List<Map<String, dynamic>>> fetchTransactions({
    required String apiKey,
    required String accountId,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/transactions?accountId=$accountId&pageSize=$pageSize',
    );
    final response = await http.get(
      uri,
      headers: {'X-API-KEY': apiKey},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Falha ao buscar transações (${response.statusCode}): ${response.body}',
      );
    }
  }

  // Busca dados de identidade do titular
  static Future<Map<String, dynamic>?> fetchIdentity({
    required String apiKey,
    required String itemId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/identity?itemId=$itemId'),
      headers: {'X-API-KEY': apiKey},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null; // Identity pode não estar disponível para todos os conectores
    } else {
      throw Exception(
        'Falha ao buscar identidade (${response.statusCode}): ${response.body}',
      );
    }
  }
}