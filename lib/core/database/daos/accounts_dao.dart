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
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  Future<int> createAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  // Soft delete — mantido para uso futuro
  Future<void> deactivateAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id)))
          .write(const AccountsCompanion(isActive: Value(false)));

  // Retorna quantas transações e metas serão perdidas na exclusão
  Future<({int transactions, int goals})> getAccountDependencyCounts(
      int accountId) async {
    final txCount = await (selectOnly(db.transactions)
          ..addColumns([db.transactions.id.count()])
          ..where(db.transactions.accountId.equals(accountId)))
        .getSingle()
        .then((r) => r.read(db.transactions.id.count()) ?? 0);

    final goalCount = await (selectOnly(db.goals)
          ..addColumns([db.goals.id.count()])
          ..where(db.goals.accountId.equals(accountId)))
        .getSingle()
        .then((r) => r.read(db.goals.id.count()) ?? 0);

    return (transactions: txCount, goals: goalCount);
  }

  // Hard delete em cascata: contributions → goals → transactions → account
  Future<void> deleteAccountCascade(int accountId) async {
    await db.transaction(() async {
      // 1. Busca metas vinculadas para poder deletar as contributions
      final goalsToDelete = await (select(db.goals)
            ..where((g) => g.accountId.equals(accountId)))
          .get();

      // 2. Deleta goal_contributions de cada meta vinculada
      for (final goal in goalsToDelete) {
        await (delete(db.goalContributions)
              ..where((c) => c.goalId.equals(goal.id)))
            .go();
      }

      // 3. Deleta as metas vinculadas
      await (delete(db.goals)
            ..where((g) => g.accountId.equals(accountId)))
          .go();

      // 4. Deleta todas as transações da conta
      await (delete(db.transactions)
            ..where((t) => t.accountId.equals(accountId)))
          .go();

      // 5. Deleta a conta em si
      await (delete(accounts)
            ..where((a) => a.id.equals(accountId)))
          .go();
    });
  }
}