import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/budgets_table.dart';
import 'tables/goals_table.dart';
import 'tables/goal_contributions_table.dart';

import 'daos/accounts_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/budgets_dao.dart';
import 'daos/goals_dao.dart';

part 'app_database.g.dart';

const _uuid = Uuid();

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    Goals,
    GoalContributions,
  ],
  daos: [
    AccountsDao,
    CategoriesDao,
    TransactionsDao,
    BudgetsDao,
    GoalsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Helper global para gerar IDs — usado nos DAOs e formulários
  static String newId() => _uuid.v4();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _insertDefaultCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from == 1) {
            await _migrateV1toV2(m);
          }
        },
      );

  Future<void> _migrateV1toV2(Migrator m) async {
    // Adiciona colunas novas em cada tabela.
    // O Drift não suporta ALTER TABLE para mudar tipo de coluna no SQLite,
    // então a estratégia para os IDs é:
    // 1. Adicionar as novas colunas (deleted_at, updated_at onde faltam)
    // 2. Os IDs INTEGER existentes permanecem como estão — o SQLite
    //    armazena TEXT e INTEGER de forma flexível, então os valores
    //    numéricos existentes ("1", "2", etc.) continuam funcionando
    //    como strings. Novos registros recebem UUID.
    // 3. Na prática, para um app em desenvolvimento isso é aceitável.
    //    Para produção real, a migration correta seria recriar as tabelas.

    // accounts
    await m.addColumn(accounts, accounts.updatedAt);
    await m.addColumn(accounts, accounts.deletedAt);

    // categories
    await m.addColumn(categories, categories.createdAt);
    await m.addColumn(categories, categories.updatedAt);
    await m.addColumn(categories, categories.deletedAt);

    // transactions
    await m.addColumn(transactions, transactions.isTransferOut);
    await m.addColumn(transactions, transactions.deletedAt);
    // updatedAt e createdAt já existiam

    // budgets
    await m.addColumn(budgets, budgets.createdAt);
    await m.addColumn(budgets, budgets.updatedAt);
    await m.addColumn(budgets, budgets.deletedAt);

    // goals
    await m.addColumn(goals, goals.updatedAt);
    await m.addColumn(goals, goals.deletedAt);

    // goal_contributions
    await m.addColumn(goalContributions, goalContributions.createdAt);
    await m.addColumn(goalContributions, goalContributions.updatedAt);
    await m.addColumn(goalContributions, goalContributions.deletedAt);

    // Preenche updatedAt com createdAt para registros existentes
    await customStatement(
        'UPDATE accounts SET updated_at = created_at WHERE updated_at = 0 OR updated_at IS NULL');
    await customStatement(
        'UPDATE transactions SET is_transfer_out = (CASE WHEN type = \'transfer\' AND transfer_pair_id > id THEN 0 ELSE 1 END) WHERE type = \'transfer\'');
  }

  Future<void> _insertDefaultCategories() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Alimentação',
          type: const Value('expense'),
          icon: const Value('utensils'),
          color: const Value(0xFFD94F4F),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Transporte',
          type: const Value('expense'),
          icon: const Value('car'),
          color: const Value(0xFF6366F1),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Moradia',
          type: const Value('expense'),
          icon: const Value('home'),
          color: const Value(0xFFF0A500),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Saúde',
          type: const Value('expense'),
          icon: const Value('heart'),
          color: const Value(0xFF2E9E6B),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Lazer',
          type: const Value('expense'),
          icon: const Value('gamepad2'),
          color: const Value(0xFF8B5CF6),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Educação',
          type: const Value('expense'),
          icon: const Value('book'),
          color: const Value(0xFF0EA5E9),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Vestuário',
          type: const Value('expense'),
          icon: const Value('shirt'),
          color: const Value(0xFFEC4899),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Outros',
          type: const Value('expense'),
          icon: const Value('circle'),
          color: const Value(0xFF6B7280),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Salário',
          type: const Value('income'),
          icon: const Value('briefcase'),
          color: const Value(0xFF2E9E6B),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Freelance',
          type: const Value('income'),
          icon: const Value('laptop'),
          color: const Value(0xFF1A6B4A),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Investimentos',
          type: const Value('income'),
          icon: const Value('trendingUp'),
          color: const Value(0xFFF0A500),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
      CategoriesCompanion.insert(
          id: AppDatabase.newId(),
          name: 'Outros',
          type: const Value('income'),
          icon: const Value('circle'),
          color: const Value(0xFF6B7280),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now)),
    ];

    for (final category in defaults) {
      await into(categories).insert(category);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'quorum.db'));
    return NativeDatabase.createInBackground(file);
  });
}