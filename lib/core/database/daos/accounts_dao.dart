import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  Stream<List<Account>> watchAllAccounts() =>
      (select(accounts)
            ..where((a) => a.isActive.equals(true) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<Account?> getAccountById(String id) =>
      (select(accounts)
            ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> createAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  Future<void> deactivateAccount(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(
      isActive: const Value(false),
      updatedAt: Value(now),
    ));
  }

  Future<({int transactions, int goals})> getAccountDependencyCounts(
      String accountId) async {
    final txCount = await (selectOnly(db.transactions)
          ..addColumns([db.transactions.id.count()])
          ..where(db.transactions.accountId.equals(accountId) &
              db.transactions.deletedAt.isNull()))
        .getSingle()
        .then((r) => r.read(db.transactions.id.count()) ?? 0);

    final goalCount = await (selectOnly(db.goals)
          ..addColumns([db.goals.id.count()])
          ..where(db.goals.accountId.equals(accountId) &
              db.goals.deletedAt.isNull()))
        .getSingle()
        .then((r) => r.read(db.goals.id.count()) ?? 0);

    return (transactions: txCount, goals: goalCount);
  }

  // Soft delete em cascata
  Future<void> deleteAccountCascade(String accountId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      // 1. Busca metas vinculadas
      final goalsToDelete = await (select(db.goals)
            ..where((g) =>
                g.accountId.equals(accountId) & g.deletedAt.isNull()))
          .get();

      // 2. Soft delete nas contribuições de cada meta
      for (final goal in goalsToDelete) {
        await (update(db.goalContributions)
              ..where((c) =>
                  c.goalId.equals(goal.id) & c.deletedAt.isNull()))
            .write(GoalContributionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      }

      // 3. Soft delete nas metas
      await (update(db.goals)
            ..where((g) =>
                g.accountId.equals(accountId) & g.deletedAt.isNull()))
          .write(GoalsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));

      // 4. Soft delete nas transações
      await (update(db.transactions)
            ..where((t) =>
                t.accountId.equals(accountId) & t.deletedAt.isNull()))
          .write(TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));

      // 5. Soft delete na conta
      await (update(accounts)..where((a) => a.id.equals(accountId)))
          .write(AccountsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }
}