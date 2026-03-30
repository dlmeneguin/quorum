import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountsDao.watchAllAccounts();
});

// Saldo real de uma conta
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
      } else if (t.type == 'transfer') {
        // Saída: transferPairId > id (aponta para o lançamento de entrada,
        // que foi criado depois e tem ID maior)
        // Entrada: transferPairId < id (aponta para o lançamento de saída,
        // que foi criado antes e tem ID menor)
        if (t.transferPairId != null) {
          if (t.transferPairId! > t.id) {
            // Este é o lançamento de saída
            balance -= t.amount;
          } else {
            // Este é o lançamento de entrada
            balance += t.amount;
          }
        }
      }
    }
    return balance;
  });
});

// Patrimônio total consolidado
final totalBalanceProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);

  return db.transactionsDao
      .watchTransactionsByPeriod(
        DateTime(2000),
        DateTime(2100),
      )
      .asyncMap((_) async {
    final accounts = await db.accountsDao.watchAllAccounts().first;
    double total = 0;
    for (final account in accounts) {
      final transactions = await db.transactionsDao
          .watchTransactionsByAccount(account.id)
          .first;
      double balance = account.initialBalance;
      for (final t in transactions) {
        if (t.type == 'income') {
          balance += t.amount;
        } else if (t.type == 'expense') {
          balance -= t.amount;
        } else if (t.type == 'transfer') {
          if (t.transferPairId != null) {
            if (t.transferPairId! > t.id) {
              balance -= t.amount;
            } else {
              balance += t.amount;
            }
          }
        }
      }
      total += balance;
    }
    return total;
  });
});