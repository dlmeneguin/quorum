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
            ..where((g) =>
                g.status.equals('active') & g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .watch();

  Stream<List<Goal>> watchAllGoals() =>
      (select(goals)
            ..where((g) => g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .watch();

  Stream<List<Goal>> watchGoalsByAccount(String accountId) =>
      (select(goals)
            ..where((g) =>
                g.accountId.equals(accountId) & g.deletedAt.isNull()))
          .watch();

  Future<void> createGoal(GoalsCompanion entry) =>
      into(goals).insert(entry);

  Future<bool> updateGoal(GoalsCompanion entry) =>
      update(goals).replace(entry);

  Future<void> deleteGoal(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      // Soft delete nas contribuições
      await (update(goalContributions)
            ..where((c) =>
                c.goalId.equals(id) & c.deletedAt.isNull()))
          .write(GoalContributionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      // Soft delete na meta
      await (update(goals)..where((g) => g.id.equals(id)))
          .write(GoalsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }

  Future<void> addContribution(GoalContributionsCompanion entry) =>
      into(goalContributions).insert(entry);

  Stream<List<GoalContribution>> watchContributionsByGoal(
          String goalId) =>
      (select(goalContributions)
            ..where((c) =>
                c.goalId.equals(goalId) & c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .watch();

  Future<double> getNetContributionsByAccount(String accountId) async {
    final linkedGoals = await (select(goals)
          ..where((g) =>
              g.accountId.equals(accountId) & g.deletedAt.isNull()))
        .get();

    if (linkedGoals.isEmpty) return 0.0;

    double total = 0.0;
    for (final goal in linkedGoals) {
      final contributions = await (select(goalContributions)
            ..where((c) =>
                c.goalId.equals(goal.id) & c.deletedAt.isNull()))
          .get();
      for (final c in contributions) {
        total += c.amount;
      }
    }
    return total;
  }

  Stream<double> watchNetContributionsByAccount(String accountId) {
    return watchAllGoals().asyncMap(
        (_) => getNetContributionsByAccount(accountId));
  }
}