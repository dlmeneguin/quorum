import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  // Busca todas as contas ativas
  Stream<List<Account>> watchAllAccounts() =>
      (select(accounts)
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  // Busca uma conta por ID
  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  // Cria uma nova conta
  Future<int> createAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  // Atualiza uma conta
  Future<bool> updateAccount(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  // Desativa uma conta (soft delete)
  Future<void> deactivateAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id)))
          .write(const AccountsCompanion(isActive: Value(false)));
}