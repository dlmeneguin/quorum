import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/category_expense.dart';

// Mês/ano atualmente selecionado no dashboard
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Resumo financeiro do mês — StreamProvider para reagir a mudanças
final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  // Observa o stream de transações e recalcula o resumo a cada mudança
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

// Gastos por categoria — StreamProvider para reagir a mudanças
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