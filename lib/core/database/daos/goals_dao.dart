import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/goals_table.dart';             // <- adicionar
import '../tables/goal_contributions_table.dart'; // <- adicionar

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

  Future<int> createGoal(GoalsCompanion entry) =>
      into(goals).insert(entry);

  Future<bool> updateGoal(GoalsCompanion entry) =>
      update(goals).replace(entry);

  Future<int> addContribution(GoalContributionsCompanion entry) =>
      into(goalContributions).insert(entry);

  Stream<List<GoalContribution>> watchContributionsByGoal(
          int goalId) =>
      (select(goalContributions)
            ..where((c) => c.goalId.equals(goalId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .watch();
}