import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Lista reativa de todas as contas ativas
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountsDao.watchAllAccounts();
});

// Saldo total consolidado (soma de todas as contas)
final totalBalanceProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  final accounts = await db.accountsDao.watchAllAccounts().first;

  double total = 0;
  for (final account in accounts) {
    total += account.initialBalance;
  }
  return total;
});