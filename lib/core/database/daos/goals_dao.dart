import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/goals_table.dart';
import '../tables/goal_contributions_table.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals, GoalContributions])
class GoalsDao extends DatabaseAccessor<AppDatabase>
    with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Stream<List<Goal>> watchActiveGoals() =>
      (select(goals)
            ..where((g) => g.status.equals('active'))
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .watch();

  Stream<List<Goal>> watchAllGoals() =>
      (select(goals)
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .watch();

  Future<int> createGoal(GoalsCompanion entry) =>
      into(goals).insert(entry);

  Future<bool> updateGoal(GoalsCompanion entry) =>
      update(goals).replace(entry);

  Future<int> deleteGoal(int id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();

  Future<int> addContribution(GoalContributionsCompanion entry) =>
      into(goalContributions).insert(entry);

  Stream<List<GoalContribution>> watchContributionsByGoal(int goalId) =>
      (select(goalContributions)
            ..where((c) => c.goalId.equals(goalId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .watch();

  // Retorna o total líquido de contribuições para metas vinculadas
  // a uma conta específica. Positivo = saiu da conta, negativo = voltou.
  // Usado para calcular o saldo real da conta.
  Future<double> getNetContributionsByAccount(int accountId) async {
    // Busca todas as metas vinculadas à conta
    final linkedGoals = await (select(goals)
          ..where((g) => g.accountId.equals(accountId)))
        .get();

    if (linkedGoals.isEmpty) return 0.0;

    double total = 0.0;
    for (final goal in linkedGoals) {
      final contributions = await (select(goalContributions)
            ..where((c) => c.goalId.equals(goal.id)))
          .get();
      for (final c in contributions) {
        total += c.amount; // positivo = contribuição, negativo = retirada
      }
    }
    return total;
  }

  // Stream da versão acima para reatividade
  Stream<double> watchNetContributionsByAccount(int accountId) {
    return watchAllGoals().asyncMap((_) =>
        getNetContributionsByAccount(accountId));
  }
}