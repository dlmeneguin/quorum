import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';
import '../tables/categories_table.dart';
import '../tables/accounts_table.dart';
import '../../models/category_expense.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories, Accounts])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Stream<List<Transaction>> watchTransactionsByPeriod(
      DateTime start, DateTime end) {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) =>
              t.date.isBetweenValues(startTs, endTs) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByAccount(
          String accountId) =>
      (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<void> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      update(transactions).replace(entry);

  Future<void> deleteTransaction(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  Future<double> getTotalIncomeInPeriod(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('income') &
          transactions.date.isBetweenValues(startTs, endTs) &
          transactions.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalExpenseInPeriod(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('expense') &
          transactions.date.isBetweenValues(startTs, endTs) &
          transactions.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalIncomeForAccount(
      String accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('income') &
          transactions.accountId.equals(accountId) &
          transactions.date.isBetweenValues(startTs, endTs) &
          transactions.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalExpenseForAccount(
      String accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('expense') &
          transactions.accountId.equals(accountId) &
          transactions.date.isBetweenValues(startTs, endTs) &
          transactions.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<List<CategoryExpense>> getExpensesByCategory(
      DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final rows = await (select(transactions).join([
      innerJoin(categories,
          categories.id.equalsExp(transactions.categoryId)),
    ])
          ..where(transactions.type.equals('expense') &
              transactions.date.isBetweenValues(startTs, endTs) &
              transactions.deletedAt.isNull()))
        .get();

    final Map<String, CategoryExpense> grouped = {};
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
    return grouped.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  Future<List<CategoryExpense>> getExpensesByCategoryForAccount(
      String accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;
    final rows = await (select(transactions).join([
      innerJoin(categories,
          categories.id.equalsExp(transactions.categoryId)),
    ])
          ..where(transactions.type.equals('expense') &
              transactions.accountId.equals(accountId) &
              transactions.date.isBetweenValues(startTs, endTs) &
              transactions.deletedAt.isNull()))
        .get();

    final Map<String, CategoryExpense> grouped = {};
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
    return grouped.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  Future<List<MonthlyBalance>> getMonthlyBalancesByAccount(
      String accountId, int monthCount) async {
    final accountsList = await (select(accounts)
          ..where((a) => a.id.equals(accountId)))
        .get();
    final initialBalance =
        accountsList.isEmpty ? 0.0 : accountsList.first.initialBalance;

    final now = DateTime.now();
    final result = <MonthlyBalance>[];

    for (int i = monthCount - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i);
      final endOfMonth = i == 0
          ? now
          : DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
      final endTs = endOfMonth.millisecondsSinceEpoch;

      final txList = await (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) &
                t.date.isSmallerOrEqualValue(endTs) &
                t.deletedAt.isNull()))
          .get();

      double balance = initialBalance;
      for (final t in txList) {
        if (t.type == 'income') {
          balance += t.amount;
        } else if (t.type == 'expense') {
          balance -= t.amount;
        } else if (t.type == 'transfer') {
          // Usa isTransferOut em vez de comparar IDs
          final isOut = t.isTransferOut ?? true;
          if (isOut) {
            balance -= t.amount;
          } else {
            balance += t.amount;
          }
        }
      }

      final netGoalContributions =
          await db.goalsDao.getNetContributionsByAccount(accountId);
      balance -= netGoalContributions;

      result.add(MonthlyBalance(
        month: DateTime(monthDate.year, monthDate.month),
        balance: balance,
      ));
    }
    return result;
  }

  Future<List<MonthlyBalance>> getMonthlyBalances(int monthCount) async {
    final accountsList = await (select(accounts)
          ..where((a) => a.isActive.equals(true) & a.deletedAt.isNull()))
        .get();
    final totalInitial =
        accountsList.fold(0.0, (sum, a) => sum + a.initialBalance);

    final now = DateTime.now();
    final result = <MonthlyBalance>[];

    for (int i = monthCount - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i);
      final endOfMonth = i == 0
          ? now
          : DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
      final endTs = endOfMonth.millisecondsSinceEpoch;

      final incomeQuery = selectOnly(transactions)
        ..addColumns([transactions.amount.sum()])
        ..where(transactions.type.equals('income') &
            transactions.date.isSmallerOrEqualValue(endTs) &
            transactions.deletedAt.isNull());
      final incomeResult = await incomeQuery.getSingle();
      final totalIncome =
          incomeResult.read(transactions.amount.sum()) ?? 0.0;

      final expenseQuery = selectOnly(transactions)
        ..addColumns([transactions.amount.sum()])
        ..where(transactions.type.equals('expense') &
            transactions.date.isSmallerOrEqualValue(endTs) &
            transactions.deletedAt.isNull());
      final expenseResult = await expenseQuery.getSingle();
      final totalExpense =
          expenseResult.read(transactions.amount.sum()) ?? 0.0;

      result.add(MonthlyBalance(
        month: DateTime(monthDate.year, monthDate.month),
        balance: totalInitial + totalIncome - totalExpense,
      ));
    }
    return result;
  }

  Future<Map<DateTime, List<Transaction>>>
      getUpcomingRecurrences() async {
    final now = DateTime.now();
    final startOfToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final installments = await (select(transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startOfToday) &
              t.installmentTotal.isNotNull() &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    final recurringTemplates = await (select(transactions)
          ..where((t) =>
              t.isRecurring.equals(true) &
              t.recurrenceParentId.isNull() &
              t.installmentTotal.isNull() &
              t.deletedAt.isNull()))
        .get();

    DateTime? lastInstallmentMonth;
    for (final t in installments) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      final m = DateTime(d.year, d.month);
      if (lastInstallmentMonth == null || m.isAfter(lastInstallmentMonth)) {
        lastInstallmentMonth = m;
      }
    }

    int monthsToShow = 6;
    if (lastInstallmentMonth != null) {
      final diff = (lastInstallmentMonth.year - now.year) * 12 +
          (lastInstallmentMonth.month - now.month) +
          1;
      if (diff > monthsToShow) monthsToShow = diff;
    }

    final Map<DateTime, List<Transaction>> grouped = {};

    for (int i = 0; i < monthsToShow; i++) {
      final monthStart = DateTime(now.year, now.month + i, 1);
      final monthEnd =
          DateTime(now.year, now.month + i + 1, 0, 23, 59, 59);
      final monthStartTs = monthStart.millisecondsSinceEpoch;
      final monthEndTs = monthEnd.millisecondsSinceEpoch;
      final monthKey = DateTime(monthStart.year, monthStart.month);

      final List<Transaction> monthItems = [];

      final monthInstallments = installments
          .where((t) => t.date >= monthStartTs && t.date <= monthEndTs)
          .toList();
      monthItems.addAll(monthInstallments);

      for (final template in recurringTemplates) {
        final originalDate =
            DateTime.fromMillisecondsSinceEpoch(template.date);
        final daysInMonth =
            DateTime(monthStart.year, monthStart.month + 1, 0).day;
        final day = originalDate.day.clamp(1, daysInMonth);
        final recurrenceDate =
            DateTime(monthStart.year, monthStart.month, day);
        final recurrenceDateTs = recurrenceDate.millisecondsSinceEpoch;
        final originMonth =
            DateTime(originalDate.year, originalDate.month);
        if (!monthKey.isAfter(originMonth)) continue;
        if (recurrenceDateTs >= startOfToday) {
          final virtualTransaction =
              template.copyWith(date: recurrenceDateTs);
          monthItems.add(virtualTransaction);
        }
      }

      monthItems.sort((a, b) => a.date.compareTo(b.date));
      if (monthItems.isNotEmpty) {
        grouped[monthKey] = monthItems;
      }
    }
    return grouped;
  }
}

class MonthlyBalance {
  final DateTime month;
  final double balance;
  const MonthlyBalance({required this.month, required this.balance});
}