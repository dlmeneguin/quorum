import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/transactions_dao.dart';
import '../../../core/models/category_expense.dart';

// Mês/ano atualmente selecionado no dashboard
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Resumo financeiro do mês
final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao
      .watchTransactionsByPeriod(start, end)
      .asyncMap((_) async {
    final income =
        await db.transactionsDao.getTotalIncomeInPeriod(start, end);
    final expense =
        await db.transactionsDao.getTotalExpenseInPeriod(start, end);

    return MonthSummary(
      income: income,
      expense: expense,
      balance: income - expense,
    );
  });
});

// Gastos por categoria
final expensesByCategoryProvider =
    StreamProvider<List<CategoryExpense>>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao
      .watchTransactionsByPeriod(start, end)
      .asyncMap((_) =>
          db.transactionsDao.getExpensesByCategory(start, end));
});

// Saldo histórico mensal para o line chart (últimos 6 meses)
final balanceHistoryProvider =
    StreamProvider<List<MonthlyBalance>>((ref) {
  final db = ref.watch(databaseProvider);

  // Precisa escutar TANTO transações QUANTO contas, pois o saldo
  // histórico depende do initial_balance de cada conta. Sem isso,
  // criar/editar uma conta (sem transações) não atualiza o gráfico.
  final transactionsStream = db.transactionsDao
      .watchTransactionsByPeriod(DateTime(2000), DateTime(2100));
  final accountsStream = db.accountsDao.watchAllAccounts();

  return Rx.combineLatest2(
    transactionsStream,
    accountsStream,
    (t, a) => null,
  ).asyncMap((_) => db.transactionsDao.getMonthlyBalances(6));
});

// Próximas recorrências e parcelas agrupadas por mês
final upcomingRecurrencesProvider =
    StreamProvider<Map<DateTime, List<Transaction>>>((ref) {
  final db = ref.watch(databaseProvider);

  return db.transactionsDao
      .watchTransactionsByPeriod(
        DateTime.now(),
        DateTime(2100),
      )
      .asyncMap((_) =>
          db.transactionsDao.getUpcomingRecurrences());
});

class MonthSummary {
  final double income;
  final double expense;
  final double balance;

  const MonthSummary({
    required this.income,
    required this.expense,
    required this.balance,
  });
}