import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  @override
  int get schemaVersion => 1;

  // Categorias padrão inseridas na primeira execução
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _insertDefaultCategories();
        },
      );

  Future<void> _insertDefaultCategories() async {
    final defaults = [
      // Despesas
      CategoriesCompanion.insert(
          name: 'Alimentação',
          type: const Value('expense'),
          icon: const Value('utensils'),
          color: const Value(0xFFD94F4F),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Transporte',
          type: const Value('expense'),
          icon: const Value('car'),
          color: const Value(0xFF6366F1),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Moradia',
          type: const Value('expense'),
          icon: const Value('home'),
          color: const Value(0xFFF0A500),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Saúde',
          type: const Value('expense'),
          icon: const Value('heart'),
          color: const Value(0xFF2E9E6B),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Lazer',
          type: const Value('expense'),
          icon: const Value('gamepad2'),
          color: const Value(0xFF8B5CF6),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Educação',
          type: const Value('expense'),
          icon: const Value('book'),
          color: const Value(0xFF0EA5E9),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Vestuário',
          type: const Value('expense'),
          icon: const Value('shirt'),
          color: const Value(0xFFEC4899),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Outros',
          type: const Value('expense'),
          icon: const Value('circle'),
          color: const Value(0xFF6B7280),
          isDefault: const Value(true)),
      // Receitas
      CategoriesCompanion.insert(
          name: 'Salário',
          type: const Value('income'),
          icon: const Value('briefcase'),
          color: const Value(0xFF2E9E6B),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Freelance',
          type: const Value('income'),
          icon: const Value('laptop'),
          color: const Value(0xFF1A6B4A),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Investimentos',
          type: const Value('income'),
          icon: const Value('trendingUp'),
          color: const Value(0xFFF0A500),
          isDefault: const Value(true)),
      CategoriesCompanion.insert(
          name: 'Outros',
          type: const Value('income'),
          icon: const Value('circle'),
          color: const Value(0xFF6B7280),
          isDefault: const Value(true)),
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