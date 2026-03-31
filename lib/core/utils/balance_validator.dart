import '../database/app_database.dart';
import '../../features/accounts/providers/accounts_provider.dart';

class BalanceValidator {
  /// Retorna null se OK, ou uma mensagem de erro se saldo insuficiente.
  static Future<String?> checkSufficientBalance({
    required AppDatabase db,
    required int accountId,
    required double amount,
  }) async {
    final accounts = await db.accountsDao.watchAllAccounts().first;
    final account =
        accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return 'Conta não encontrada';

    final available = await computeAccountBalance(db, account);
    if (amount > available) {
      return 'Saldo insuficiente. Disponível: R\$ ${available.toStringAsFixed(2).replaceAll('.', ',')}';
    }
    return null;
  }
}