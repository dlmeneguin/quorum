import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/daos/transactions_dao.dart';
import '../../../core/models/category_expense.dart';
import '../../dashboard/providers/dashboard_provider.dart';

// Mês selecionado na tela de detalhe — independente do dashboard
final accountDetailMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Resumo do mês para uma conta específica
final accountMonthSummaryProvider =
    StreamProvider.family<MonthSummary, Account>((ref, account) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(accountDetailMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao
      .watchTransactionsByAccount(account.id)
      .asyncMap((_) async {
    final income = await db.transactionsDao
        .getTotalIncomeForAccount(account.id, start, end);
    final expense = await db.transactionsDao
        .getTotalExpenseForAccount(account.id, start, end);

    return MonthSummary(
      income: income,
      expense: expense,
      balance: income - expense,
    );
  });
});

// Gastos por categoria para uma conta específica
final accountExpensesByCategoryProvider =
    StreamProvider.family<List<CategoryExpense>, Account>((ref, account) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(accountDetailMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao
      .watchTransactionsByAccount(account.id)
      .asyncMap((_) => db.transactionsDao
          .getExpensesByCategoryForAccount(account.id, start, end));
});

// Histórico de saldo mensal para uma conta específica
final accountBalanceHistoryProvider =
    StreamProvider.family<List<MonthlyBalance>, Account>((ref, account) {
  final db = ref.watch(databaseProvider);

  return db.transactionsDao
      .watchTransactionsByAccount(account.id)
      .asyncMap((_) =>
          db.transactionsDao.getMonthlyBalancesByAccount(account.id, 6));
});

// Transações do mês selecionado para uma conta específica
final accountTransactionsProvider =
    StreamProvider.family<List<Transaction>, Account>((ref, account) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(accountDetailMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao.watchTransactionsByPeriod(start, end).map(
        (list) => list.where((t) => t.accountId == account.id).toList(),
      );
});

// Metas ativas/pausadas vinculadas a uma conta específica
final accountGoalsProvider =
    StreamProvider.family<List<Goal>, Account>((ref, account) {
  final db = ref.watch(databaseProvider);
  return db.goalsDao.watchGoalsByAccount(account.id).map(
        (goals) => goals
            .where((g) => g.status == 'active' || g.status == 'paused')
            .toList(),
      );
});