import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budgets_table.dart'; // <- adicionar

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase>
    with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  Stream<List<Budget>> watchBudgetsByMonth(int year, int month) =>
      (select(budgets)
            ..where((b) =>
                b.year.equals(year) & b.month.equals(month)))
          .watch();

  Future<int> createBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<bool> updateBudget(BudgetsCompanion entry) =>
      update(budgets).replace(entry);

  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}