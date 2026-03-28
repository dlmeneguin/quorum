import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/category_expense.dart';

// Mês/ano atualmente selecionado no dashboard
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Resumo financeiro do mês selecionado
final monthSummaryProvider = FutureProvider<MonthSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  final income = await db.transactionsDao.getTotalIncomeInPeriod(start, end);
  final expense = await db.transactionsDao.getTotalExpenseInPeriod(start, end);

  return MonthSummary(
    income: income,
    expense: expense,
    balance: income - expense,
  );
});

// Gastos agrupados por categoria no mês
final expensesByCategoryProvider =
    FutureProvider<List<CategoryExpense>>((ref) async {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end =
      DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao.getExpensesByCategory(start, end);
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
