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

  // Todas as transações de um período
  Stream<List<Transaction>> watchTransactionsByPeriod(
      DateTime start, DateTime end) {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    return (select(transactions)
          ..where((t) => t.date.isBetweenValues(startTs, endTs))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  // Transações de uma conta específica
  Stream<List<Transaction>> watchTransactionsByAccount(int accountId) =>
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
  Future<double> getTotalIncomeInPeriod(DateTime start, DateTime end) async {
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
  Future<double> getTotalExpenseInPeriod(DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('expense') &
          transactions.date.isBetweenValues(startTs, endTs));

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  // Soma de receitas de uma conta específica no período
  Future<double> getTotalIncomeForAccount(
      int accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('income') &
          transactions.accountId.equals(accountId) &
          transactions.date.isBetweenValues(startTs, endTs));

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  // Soma de despesas de uma conta específica no período
  Future<double> getTotalExpenseForAccount(
      int accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equals('expense') &
          transactions.accountId.equals(accountId) &
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

  // Gastos agrupados por categoria no período, filtrado por conta
  Future<List<CategoryExpense>> getExpensesByCategoryForAccount(
      int accountId, DateTime start, DateTime end) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final rows = await (select(transactions).join([
      innerJoin(
        categories,
        categories.id.equalsExp(transactions.categoryId),
      ),
    ])
          ..where(transactions.type.equals('expense') &
              transactions.accountId.equals(accountId) &
              transactions.date.isBetweenValues(startTs, endTs)))
        .get();

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

  // Saldo mensal acumulado dos últimos N meses, filtrado por conta
  Future<List<MonthlyBalance>> getMonthlyBalancesByAccount(
      int accountId, int monthCount) async {
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

      // Busca todas as transações da conta até este momento
      final txList = await (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) &
                t.date.isSmallerOrEqualValue(endTs)))
          .get();

      double balance = initialBalance;
      for (final t in txList) {
        if (t.type == 'income') {
          balance += t.amount;
        } else if (t.type == 'expense') {
          balance -= t.amount;
        } else if (t.type == 'transfer') {
          if (t.transferPairId != null) {
            if (t.transferPairId! > t.id) {
              balance -= t.amount; // saída
            } else {
              balance += t.amount; // entrada
            }
          }
        }
      }

      // Descontar contribuições líquidas de metas vinculadas
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

  // Saldo total acumulado até o fim de cada mês (para o line chart)
  // Retorna uma lista de [DateTime (primeiro dia do mês), double (saldo)]
  Future<List<MonthlyBalance>> getMonthlyBalances(int monthCount) async {
    // Soma de todos os saldos iniciais das contas ativas
    final accountsList = await (select(accounts)
          ..where((a) => a.isActive.equals(true)))
        .get();
    final totalInitial =
        accountsList.fold(0.0, (sum, a) => sum + a.initialBalance);

    final now = DateTime.now();
    final result = <MonthlyBalance>[];

    for (int i = monthCount - 1; i >= 0; i--) {
      // Fim do mês que estamos calculando
      final monthDate = DateTime(now.year, now.month - i);
      final endOfMonth = i == 0
          ? now // mês atual: usa o momento presente
          : DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

      final endTs = endOfMonth.millisecondsSinceEpoch;

      // Soma todas as receitas até esse momento
      final incomeQuery = selectOnly(transactions)
        ..addColumns([transactions.amount.sum()])
        ..where(transactions.type.equals('income') &
            transactions.date.isSmallerOrEqualValue(endTs));
      final incomeResult = await incomeQuery.getSingle();
      final totalIncome = incomeResult.read(transactions.amount.sum()) ?? 0.0;

      // Soma todas as despesas até esse momento
      final expenseQuery = selectOnly(transactions)
        ..addColumns([transactions.amount.sum()])
        ..where(transactions.type.equals('expense') &
            transactions.date.isSmallerOrEqualValue(endTs));
      final expenseResult = await expenseQuery.getSingle();
      final totalExpense =
          expenseResult.read(transactions.amount.sum()) ?? 0.0;

      final balance = totalInitial + totalIncome - totalExpense;
      result.add(MonthlyBalance(
        month: DateTime(monthDate.year, monthDate.month),
        balance: balance,
      ));
    }

    return result;
  }

// Transações recorrentes e parceladas futuras, agrupadas por mês.
  // Regra de meses a exibir:
  //   - mínimo sempre 6 meses
  //   - se houver parcelas, estende até o mês da última parcela
  //   - recorrentes preenchem TODOS os meses do range resultante
  Future<Map<DateTime, List<Transaction>>> getUpcomingRecurrences() async {
    final now = DateTime.now();
    final startOfToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // --- Parcelas futuras (lógica inalterada) ---
    final installments = await (select(transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startOfToday) &
              t.installmentTotal.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    // --- Templates recorrentes ---
    // Busca apenas os lançamentos "raiz" recorrentes (sem pai),
    // independente da data — podem ter sido criados no passado.
    final recurringTemplates = await (select(transactions)
          ..where((t) =>
              t.isRecurring.equals(true) &
              t.recurrenceParentId.isNull() &
              t.installmentTotal.isNull()))
        .get();

    // Descobre o mês mais distante com parcela para definir o range
    DateTime? lastInstallmentMonth;
    for (final t in installments) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      final m = DateTime(d.year, d.month);
      if (lastInstallmentMonth == null || m.isAfter(lastInstallmentMonth)) {
        lastInstallmentMonth = m;
      }
    }

    // Mínimo 6 meses, ou até o mês da última parcela
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

      // Adiciona parcelas que caem neste mês
      final monthInstallments = installments
          .where((t) => t.date >= monthStartTs && t.date <= monthEndTs)
          .toList();
      monthItems.addAll(monthInstallments);

      // Expande cada template recorrente para este mês
      for (final template in recurringTemplates) {
        final originalDate =
            DateTime.fromMillisecondsSinceEpoch(template.date);

        // O dia do mês da recorrência (ex: criada no dia 5, aparece no dia 5)
        // Ajusta para o último dia do mês se necessário (ex: dia 31 em fevereiro)
        final daysInMonth =
            DateTime(monthStart.year, monthStart.month + 1, 0).day;
        final day = originalDate.day.clamp(1, daysInMonth);

        final recurrenceDate =
            DateTime(monthStart.year, monthStart.month, day);
        final recurrenceDateTs = recurrenceDate.millisecondsSinceEpoch;

        // Só aparece a partir do mês seguinte à criação
        // (o mês de criação já aparece na tela de transações normalmente)
        final originMonth =
            DateTime(originalDate.year, originalDate.month);
        if (!monthKey.isAfter(originMonth)) continue;

        // Só aparece se ainda não foi excluída manualmente
        // (verificação futura — por ora, todo template ativo aparece)
        if (recurrenceDateTs >= startOfToday) {
          // Cria uma instância virtual do template para este mês
          final virtualTransaction = template.copyWith(
            date: recurrenceDateTs,
          );
          monthItems.add(virtualTransaction);
        }
      }

      // Ordena por data dentro do mês
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