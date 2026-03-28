import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';
import '../tables/categories_table.dart';
import '../../models/category_expense.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  // Todas as transações de um período
  Stream<List<Transaction>> watchTransactionsByPeriod(
      DateTime start, DateTime end) {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    return (select(transactions)
          ..where((t) =>
              t.date.isBetweenValues(startTs, endTs))
          ..orderBy(
              [(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  // Transações de uma conta específica
  Stream<List<Transaction>> watchTransactionsByAccount(
      int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<int> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      update(transactions).replace(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // Soma de receitas no período
  Future<double> getTotalIncomeInPeriod(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('income') &
          transactions.date.isBetweenValues(startTs, endTs));

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  // Soma de despesas no período
  Future<double> getTotalExpenseInPeriod(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('expense') &
          transactions.date.isBetweenValues(startTs, endTs));

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }
  // Gastos agrupados por categoria no período
  Future<List<CategoryExpense>> getExpensesByCategory(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final rows = await (select(transactions).join([
      innerJoin(
        categories,
        categories.id.equalsExp(transactions.categoryId),
      ),
    ])
          ..where(transactions.type.equals('expense') &
              transactions.date.isBetweenValues(startTs, endTs)))
        .get();

    // Agrupa por categoria
    final Map<int, CategoryExpense> grouped = {};
    for (final row in rows) {
      final transaction = row.readTable(transactions);
      final category = row.readTable(categories);
      final existing = grouped[category.id];
      if (existing != null) {
        grouped[category.id] = CategoryExpense(
          categoryName: category.name,
          categoryColor: category.color ?? 0xFF6B7280,
          total: existing.total + transaction.amount,
        );
      } else {
        grouped[category.id] = CategoryExpense(
          categoryName: category.name,
          categoryColor: category.color ?? 0xFF6B7280,
          total: transaction.amount,
        );
      }
    }

    final result = grouped.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }
}