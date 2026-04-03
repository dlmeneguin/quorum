import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.goalsDao.watchAllGoals();
});

final goalByIdProvider =
    StreamProvider.family<Goal?, String>((ref, goalId) {
  final db = ref.watch(databaseProvider);
  return db.goalsDao
      .watchAllGoals()
      .map((goals) => goals.where((g) => g.id == goalId).firstOrNull);
});

final contributionsProvider =
    StreamProvider.family<List<GoalContribution>, String>((ref, goalId) {
  final db = ref.watch(databaseProvider);
  return db.goalsDao.watchContributionsByGoal(goalId);
});

DateTime? projectCompletionDate(
    double currentAmount,
    double targetAmount,
    List<GoalContribution> contributions) {
  if (currentAmount >= targetAmount) return null;
  if (contributions.isEmpty) return null;

  // Calcula o fluxo líquido por mês (contribuições - retiradas)
  final Map<String, double> netByMonth = {};
  for (final c in contributions) {
    final date = DateTime.fromMillisecondsSinceEpoch(c.date);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    netByMonth[key] = (netByMonth[key] ?? 0) + c.amount;
  }

  if (netByMonth.isEmpty) return null;

  // Considera apenas meses com fluxo líquido positivo para a média
  // Meses com retirada líquida não contribuem para a projeção de avanço
  final positiveMonths =
      netByMonth.values.where((v) => v > 0).toList();

  if (positiveMonths.isEmpty) return null;

  final monthlyAverage =
      positiveMonths.reduce((a, b) => a + b) / positiveMonths.length;

  if (monthlyAverage <= 0) return null;

  final remaining = targetAmount - currentAmount;
  final monthsNeeded = (remaining / monthlyAverage).ceil();

  final now = DateTime.now();
  return DateTime(now.year, now.month + monthsNeeded);
}

// Contribuição: move dinheiro da conta para a meta
Future<void> addContributionAndUpdate({
  required AppDatabase db,
  required Goal goal,
  required double amount,
  required DateTime date,
  String? note,
}) async {
  assert(amount > 0, 'Contribuição deve ser positiva');

  await db.goalsDao.addContribution(
    GoalContributionsCompanion.insert(
      id: Value(AppDatabase.newId()),
      goalId: goal.id,
      amount: amount, // positivo = saiu da conta, entrou na meta
      date: date.millisecondsSinceEpoch,
      note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
    ),
  );

  final newAmount = goal.currentAmount + amount;
  final newStatus =
      newAmount >= goal.targetAmount ? 'completed' : goal.status;

  await db.goalsDao.updateGoal(GoalsCompanion(
    id: Value(goal.id),
    name: Value(goal.name),
    targetAmount: Value(goal.targetAmount),
    currentAmount: Value(newAmount),
    status: Value(newStatus),
    targetDate: Value(goal.targetDate),
    accountId: Value(goal.accountId),
    color: Value(goal.color),
    icon: Value(goal.icon),
    createdAt: Value(goal.createdAt),
  ));
}

// Retirada: move dinheiro da meta de volta para a conta
Future<void> withdrawFromGoal({
  required AppDatabase db,
  required Goal goal,
  required double amount,
  required DateTime date,
  String? note,
}) async {
  assert(amount > 0, 'Informe o valor a retirar');
  assert(amount <= goal.currentAmount, 'Saldo insuficiente na meta');

  await db.goalsDao.addContribution(
    GoalContributionsCompanion.insert(
      id: Value(AppDatabase.newId()),
      goalId: goal.id,
      amount: -amount, // negativo = saiu da meta, voltou para a conta
      date: date.millisecondsSinceEpoch,
      note: Value(note?.trim().isEmpty == true
          ? 'Retirada'
          : note?.trim()),
    ),
  );

  final newAmount = goal.currentAmount - amount;
  // Se estava concluída e retirou, volta para ativa
  final newStatus =
      newAmount < goal.targetAmount && goal.status == 'completed'
          ? 'active'
          : goal.status;

  await db.goalsDao.updateGoal(GoalsCompanion(
    id: Value(goal.id),
    name: Value(goal.name),
    targetAmount: Value(goal.targetAmount),
    currentAmount: Value(newAmount),
    status: Value(newStatus),
    targetDate: Value(goal.targetDate),
    accountId: Value(goal.accountId),
    color: Value(goal.color),
    icon: Value(goal.icon),
    createdAt: Value(goal.createdAt),
  ));
}