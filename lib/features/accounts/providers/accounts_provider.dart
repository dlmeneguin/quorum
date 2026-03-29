import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Lista reativa de todas as contas ativas
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountsDao.watchAllAccounts();
});

// Saldo real de uma conta: initialBalance + receitas - despesas
final accountBalanceProvider =
    StreamProvider.family<double, Account>((ref, account) {
  final db = ref.watch(databaseProvider);

  return db.transactionsDao
      .watchTransactionsByAccount(account.id)
      .map((transactions) {
    double balance = account.initialBalance;
    for (final t in transactions) {
      if (t.type == 'income') {
        balance += t.amount;
      } else if (t.type == 'expense') {
        balance -= t.amount;
      }
      // transferências não afetam o saldo aqui pois já geram dois lançamentos
    }
    return balance;
  });
});

// Patrimônio total consolidado (soma dos saldos reais de todas as contas)
final totalBalanceProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);

  return db.accountsDao.watchAllAccounts().asyncMap((accounts) async {
    double total = 0;
    for (final account in accounts) {
      final transactions = await db.transactionsDao
          .watchTransactionsByAccount(account.id)
          .first;
      double balance = account.initialBalance;
      for (final t in transactions) {
        if (t.type == 'income') balance += t.amount;
        if (t.type == 'expense') balance -= t.amount;
      }
      total += balance;
    }
    return total;
  });
});