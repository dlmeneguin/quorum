import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class BudgetWithSpending {
  final Budget budget;
  final String categoryName;
  final int categoryColor;
  final double spent;

  const BudgetWithSpending({
    required this.budget,
    required this.categoryName,
    required this.categoryColor,
    required this.spent,
  });

  double get percentage =>
      budget.limitAmount > 0 ? spent / budget.limitAmount : 0;

  bool get isWarning => percentage >= 0.8 && percentage < 1.0;
  bool get isOver => percentage >= 1.0;
}

final budgetWithSpendingProvider =
    StreamProvider<List<BudgetWithSpending>>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  // Reage a mudanças nos orçamentos E nas transações do período
  final budgetsStream =
      db.budgetsDao.watchBudgetsByMonth(selected.year, selected.month);

  return budgetsStream.asyncMap((budgets) async {
    if (budgets.isEmpty) return [];

    // Busca gastos reais por categoria no período
    final expenses =
        await db.transactionsDao.getExpensesByCategory(start, end);

    // Monta mapa categoryId → totalGasto usando os nomes como chave de cruzamento
    // Como getExpensesByCategory retorna categoryName, precisamos buscar
    // as categorias para cruzar pelo id
    final allCategories =
        await db.categoriesDao.watchAllCategories().first;
    final categoryMap = {for (final c in allCategories) c.id: c};

    final expenseByName = {for (final e in expenses) e.categoryName: e.total};

    return budgets.map((budget) {
      final category = categoryMap[budget.categoryId];
      final categoryName = category?.name ?? 'Categoria removida';
      final categoryColor = category?.color ?? 0xFF6B7280;
      final spent = expenseByName[categoryName] ?? 0.0;

      return BudgetWithSpending(
        budget: budget,
        categoryName: categoryName,
        categoryColor: categoryColor,
        spent: spent,
      );
    }).toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
  });
});