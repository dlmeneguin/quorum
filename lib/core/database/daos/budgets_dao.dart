import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budgets_table.dart';

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase>
    with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  Stream<List<Budget>> watchBudgetsByMonth(int year, int month) =>
      (select(budgets)
            ..where((b) =>
                b.year.equals(year) &
                b.month.equals(month) &
                b.deletedAt.isNull()))
          .watch();

  Future<void> createBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<bool> updateBudget(BudgetsCompanion entry) =>
      update(budgets).replace(entry);

  Future<void> deleteBudget(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(budgets)..where((b) => b.id.equals(id)))
        .write(BudgetsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}