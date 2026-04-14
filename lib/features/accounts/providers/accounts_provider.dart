import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/wealth_slice.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountsDao.watchAllAccounts();
});

// Calcula o saldo de uma conta a partir de transações e contribuições de metas
// Helper puro — usado tanto no provider quanto na validação
Future<double> computeAccountBalance(AppDatabase db, Account account) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  final allTransactions = await db.transactionsDao
      .watchTransactionsByAccount(account.id)
      .first;

  // Apenas transações com data <= agora (modelo "compromisso futuro"):
  // parcelas futuras não deduzem o saldo até a data delas chegar.
  final transactions = allTransactions
      .where((t) => t.date <= now && t.deletedAt == null)
      .toList();

  double balance = account.initialBalance;
  for (final t in transactions) {
    if (t.type == 'income') {
      balance += t.amount;
    } else if (t.type == 'expense') {
      balance -= t.amount;
    } else if (t.type == 'transfer') {
      final isOut = t.isTransferOut ?? true;
      if (isOut) {
        balance -= t.amount;
      } else {
        balance += t.amount;
      }
    }
  }

  final netGoalContributions =
      await db.goalsDao.getNetContributionsByAccount(account.id);
  balance -= netGoalContributions;

  return balance;
}

// Saldo reativo: recalcula apenas quando transações OU metas DESTA conta mudam
final accountBalanceProvider =
    StreamProvider.family<double, Account>((ref, account) {
  final db = ref.watch(databaseProvider);

  final transactionsStream =
      db.transactionsDao.watchTransactionsByAccount(account.id);
  final goalsStream = db.goalsDao.watchGoalsByAccount(account.id);

  return Rx.combineLatest2(
    transactionsStream,
    goalsStream,
    (transactions, goals) => null,
  ).asyncMap((_) => computeAccountBalance(db, account));
});

// Patrimônio total — combina streams de todas as fontes sem usar .first aninhado
final totalBalanceProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);

  final transactionsStream = db.transactionsDao
      .watchTransactionsByPeriod(DateTime(2000), DateTime(2100));
  final accountsStream = db.accountsDao.watchAllAccounts();
  final goalsStream = db.goalsDao.watchAllGoals();

  return Rx.combineLatest3(
    transactionsStream,
    accountsStream,
    goalsStream,
    (t, a, g) => null,
  ).asyncMap((_) async {
    final accounts = await db.accountsDao.watchAllAccounts().first;
    double total = 0;

    for (final account in accounts) {
      final freeBalance = await computeAccountBalance(db, account);
      total += freeBalance;
    }

    final allGoals = await db.goalsDao.watchAllGoals().first;
    for (final goal in allGoals) {
      if (goal.status == 'active' || goal.status == 'paused') {
        total += goal.currentAmount;
      }
    }

    return total;
  });
});

// Distribuição do patrimônio para o donut chart
final wealthDistributionProvider =
    StreamProvider<List<WealthSlice>>((ref) {
  final db = ref.watch(databaseProvider);

  final transactionsStream = db.transactionsDao
      .watchTransactionsByPeriod(DateTime(2000), DateTime(2100));
  final goalsStream = db.goalsDao.watchAllGoals();

  return Rx.combineLatest2(
    transactionsStream,
    goalsStream,
    (t, g) => null,
  ).asyncMap((_) async {
    final accounts = await db.accountsDao.watchAllAccounts().first;
    final allGoals = await db.goalsDao.watchAllGoals().first;
    final activeGoals = allGoals
        .where((g) => g.status == 'active' || g.status == 'paused')
        .toList();

    final slices = <WealthSlice>[];

    for (final account in accounts) {
      final freeBalance = await computeAccountBalance(db, account);
      if (freeBalance > 0) {
        slices.add(WealthSlice(
          label: account.name,
          value: freeBalance,
          color: account.color ?? 0xFF1A6B4A,
          isGoal: false,
        ));
      }
    }

    for (final goal in activeGoals) {
      if (goal.currentAmount > 0 && goal.accountId != null) {
        final linkedAccount =
            accounts.where((a) => a.id == goal.accountId).firstOrNull;
        final accountName = linkedAccount?.name ?? '';
        final label = accountName.isNotEmpty
            ? '${goal.name} ($accountName)'
            : goal.name;

        slices.add(WealthSlice(
          label: label,
          value: goal.currentAmount,
          color: goal.color ?? 0xFFF0A500,
          isGoal: true,
        ));
      }
    }

    return slices;
  });
});