import 'dart:convert';
import '../database/app_database.dart';
import 'package:drift/drift.dart' show Value;

class MergeService {
  final AppDatabase db;

  MergeService(this.db);

  // Serializa o banco local em JSON (reutiliza a lógica do BackupService)
  Future<String> exportToJson() async {
    final now = DateTime.now();

    final accounts = await db.accountsDao.watchAllAccounts().first;
    final allAccounts = await db.managers.accounts.get(); // inclui deletados
    final categories = await db.managers.categories.get();
    final transactions = await db.managers.transactions.get();
    final budgets = await db.managers.budgets.get();
    final goals = await db.managers.goals.get();
    final contributions = await db.managers.goalContributions.get();

    final payload = {
      'version': 2,
      'exportedAt': now.toIso8601String(),
      'accounts': allAccounts.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
      'goals': goals.map((e) => e.toJson()).toList(),
      'goalContributions': contributions.map((e) => e.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // Aplica merge do JSON remoto com o estado local
  // Retorna o JSON do estado merged (para fazer upload imediato)
  Future<String> mergeFromJson(String remoteJson) async {
    final remote = jsonDecode(remoteJson) as Map<String, dynamic>;

    await db.transaction(() async {
      await _mergeAccounts(remote['accounts'] as List);
      await _mergeCategories(remote['categories'] as List);
      await _mergeTransactions(remote['transactions'] as List);
      await _mergeBudgets(remote['budgets'] as List);
      await _mergeGoals(remote['goals'] as List);
      await _mergeContributions(remote['goalContributions'] as List);
      await _recalculateGoalAmounts();
      await _applyCascadeDeletes();
    });

    // Exporta o estado merged para retornar
    return exportToJson();
  }

  // ── Helpers de merge por tabela ──────────────────────────────────

  Future<void> _mergeAccounts(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.accounts)
            ..where((a) => a.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        // Não existe localmente — inserir
        await db.into(db.accounts).insert(
              AccountsCompanion.insert(
                id: Value(remoteId),
                name: raw['name'] as String,
                type: Value(raw['type'] as String? ?? 'checking'),
                initialBalance:
                    Value((raw['initialBalance'] as num?)?.toDouble() ?? 0),
                color: Value(raw['color'] as int?),
                icon: Value(raw['icon'] as String?),
                isActive: Value(raw['isActive'] as bool? ?? true),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        // Existe — último updatedAt vence
        final localUpdatedAt = existing.updatedAt;
        if (remoteUpdatedAt > localUpdatedAt) {
          await (db.update(db.accounts)
                ..where((a) => a.id.equals(remoteId)))
              .write(AccountsCompanion(
            name: Value(raw['name'] as String),
            type: Value(raw['type'] as String? ?? 'checking'),
            initialBalance:
                Value((raw['initialBalance'] as num?)?.toDouble() ?? 0),
            color: Value(raw['color'] as int?),
            icon: Value(raw['icon'] as String?),
            isActive: Value(raw['isActive'] as bool? ?? true),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
          ));
        }
      }
    }
  }

  Future<void> _mergeCategories(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.categories)
            ..where((c) => c.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: Value(remoteId),
                name: raw['name'] as String,
                type: Value(raw['type'] as String? ?? 'expense'),
                color: Value(raw['color'] as int?),
                icon: Value(raw['icon'] as String?),
                isDefault: Value(raw['isDefault'] as bool? ?? false),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.categories)
                ..where((c) => c.id.equals(remoteId)))
              .write(CategoriesCompanion(
            name: Value(raw['name'] as String),
            type: Value(raw['type'] as String? ?? 'expense'),
            color: Value(raw['color'] as int?),
            icon: Value(raw['icon'] as String?),
            isDefault: Value(raw['isDefault'] as bool? ?? false),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
          ));
        }
      }
    }
  }

  Future<void> _mergeTransactions(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.transactions)
            ..where((t) => t.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(remoteId),
                accountId: raw['accountId'] as String,
                categoryId: Value(raw['categoryId'] as String?),
                type: Value(raw['type'] as String? ?? 'expense'),
                amount: (raw['amount'] as num).toDouble(),
                date: raw['date'] as int,
                description: Value(raw['description'] as String?),
                notes: Value(raw['notes'] as String?),
                paymentMethod: Value(raw['paymentMethod'] as String?),
                isRecurring: Value(raw['isRecurring'] as bool? ?? false),
                recurrenceType: Value(raw['recurrenceType'] as String?),
                recurrenceParentId:
                    Value(raw['recurrenceParentId'] as String?),
                installmentTotal: Value(raw['installmentTotal'] as int?),
                installmentCurrent:
                    Value(raw['installmentCurrent'] as int?),
                installmentGroupId:
                    Value(raw['installmentGroupId'] as String?),
                transferPairId: Value(raw['transferPairId'] as String?),
                isTransferOut: Value(raw['isTransferOut'] as bool?),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.transactions)
                ..where((t) => t.id.equals(remoteId)))
              .write(TransactionsCompanion(
            accountId: Value(raw['accountId'] as String),
            categoryId: Value(raw['categoryId'] as String?),
            type: Value(raw['type'] as String? ?? 'expense'),
            amount: Value((raw['amount'] as num).toDouble()),
            date: Value(raw['date'] as int),
            description: Value(raw['description'] as String?),
            notes: Value(raw['notes'] as String?),
            paymentMethod: Value(raw['paymentMethod'] as String?),
            isRecurring: Value(raw['isRecurring'] as bool? ?? false),
            recurrenceType: Value(raw['recurrenceType'] as String?),
            recurrenceParentId:
                Value(raw['recurrenceParentId'] as String?),
            installmentTotal: Value(raw['installmentTotal'] as int?),
            installmentCurrent: Value(raw['installmentCurrent'] as int?),
            installmentGroupId:
                Value(raw['installmentGroupId'] as String?),
            transferPairId: Value(raw['transferPairId'] as String?),
            isTransferOut: Value(raw['isTransferOut'] as bool?),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
          ));
        }
      }
    }
  }

  Future<void> _mergeBudgets(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.budgets)
            ..where((b) => b.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.budgets).insert(
              BudgetsCompanion.insert(
                id: Value(remoteId),
                categoryId: raw['categoryId'] as String,
                year: raw['year'] as int,
                month: raw['month'] as int,
                limitAmount: (raw['limitAmount'] as num).toDouble(),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.budgets)
                ..where((b) => b.id.equals(remoteId)))
              .write(BudgetsCompanion(
            categoryId: Value(raw['categoryId'] as String),
            year: Value(raw['year'] as int),
            month: Value(raw['month'] as int),
            limitAmount: Value((raw['limitAmount'] as num).toDouble()),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
          ));
        }
      }
    }
  }

  Future<void> _mergeGoals(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.goals)
            ..where((g) => g.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.goals).insert(
              GoalsCompanion.insert(
                id: Value(remoteId),
                name: raw['name'] as String,
                targetAmount: (raw['targetAmount'] as num).toDouble(),
                // currentAmount NÃO vem do JSON — será recalculado
                targetDate: Value(raw['targetDate'] as int?),
                accountId: Value(raw['accountId'] as String?),
                color: Value(raw['color'] as int?),
                icon: Value(raw['icon'] as String?),
                status: Value(raw['status'] as String? ?? 'active'),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.goals)
                ..where((g) => g.id.equals(remoteId)))
              .write(GoalsCompanion(
            name: Value(raw['name'] as String),
            targetAmount: Value((raw['targetAmount'] as num).toDouble()),
            targetDate: Value(raw['targetDate'] as int?),
            accountId: Value(raw['accountId'] as String?),
            color: Value(raw['color'] as int?),
            icon: Value(raw['icon'] as String?),
            status: Value(raw['status'] as String? ?? 'active'),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
            // currentAmount deliberadamente omitido — recalculado depois
          ));
        }
      }
    }
  }

  Future<void> _mergeContributions(List remote) async {
    for (final raw in remote) {
      final remoteId = raw['id'] as String;
      final remoteUpdatedAt = raw['updatedAt'] as int? ?? 0;
      final remoteDeletedAt = raw['deletedAt'] as int?;

      final existing = await (db.select(db.goalContributions)
            ..where((c) => c.id.equals(remoteId)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.goalContributions).insert(
              GoalContributionsCompanion.insert(
                id: Value(remoteId),
                goalId: raw['goalId'] as String,
                amount: (raw['amount'] as num).toDouble(),
                date: raw['date'] as int,
                note: Value(raw['note'] as String?),
                createdAt: Value(raw['createdAt'] as int? ?? 0),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(remoteDeletedAt),
              ),
            );
      } else {
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.goalContributions)
                ..where((c) => c.id.equals(remoteId)))
              .write(GoalContributionsCompanion(
            amount: Value((raw['amount'] as num).toDouble()),
            date: Value(raw['date'] as int),
            note: Value(raw['note'] as String?),
            updatedAt: Value(remoteUpdatedAt),
            deletedAt: Value(remoteDeletedAt),
          ));
        }
      }
    }
  }

  // Recalcula currentAmount de todas as metas a partir das contribuições
  // Nunca confia no valor serializado — sempre recomputa
  Future<void> _recalculateGoalAmounts() async {
    final allGoals = await db.select(db.goals).get();

    for (final goal in allGoals) {
      final contributions = await (db.select(db.goalContributions)
            ..where((c) =>
                c.goalId.equals(goal.id) & c.deletedAt.isNull()))
          .get();

      final total =
          contributions.fold(0.0, (sum, c) => sum + c.amount);

      // Atualiza status se atingiu a meta
      final newStatus = total >= goal.targetAmount && goal.deletedAt == null
          ? 'completed'
          : goal.status == 'completed' && total < goal.targetAmount
              ? 'active'
              : goal.status;

      await (db.update(db.goals)..where((g) => g.id.equals(goal.id)))
          .write(GoalsCompanion(
        currentAmount: Value(total),
        status: Value(newStatus),
      ));
    }
  }

  // Propaga soft deletes em cascata após o merge
  // Ex: conta deletada → deleta transações e metas vinculadas
  Future<void> _applyCascadeDeletes() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Contas deletadas → transações e metas vinculadas
    final deletedAccounts = await (db.select(db.accounts)
          ..where((a) => a.deletedAt.isNotNull()))
        .get();

    for (final account in deletedAccounts) {
      // Transações
      await (db.update(db.transactions)
            ..where((t) =>
                t.accountId.equals(account.id) &
                t.deletedAt.isNull()))
          .write(TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));

      // Metas → e suas contribuições
      final linkedGoals = await (db.select(db.goals)
            ..where((g) =>
                g.accountId.equals(account.id) &
                g.deletedAt.isNull()))
          .get();

      for (final goal in linkedGoals) {
        await (db.update(db.goalContributions)
              ..where((c) =>
                  c.goalId.equals(goal.id) & c.deletedAt.isNull()))
            .write(GoalContributionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));

        await (db.update(db.goals)
              ..where((g) => g.id.equals(goal.id)))
            .write(GoalsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    }

    // Metas deletadas (diretamente) → contribuições vinculadas
    final deletedGoals = await (db.select(db.goals)
          ..where((g) => g.deletedAt.isNotNull()))
        .get();

    for (final goal in deletedGoals) {
      await (db.update(db.goalContributions)
            ..where((c) =>
                c.goalId.equals(goal.id) & c.deletedAt.isNull()))
          .write(GoalContributionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    }

    // Contribuições órfãs (meta não existe ou foi deletada)
    final allContributions =
        await db.select(db.goalContributions).get();
    for (final contribution in allContributions) {
      if (contribution.deletedAt != null) continue;
      final goal = await (db.select(db.goals)
            ..where((g) => g.id.equals(contribution.goalId)))
          .getSingleOrNull();
      if (goal == null || goal.deletedAt != null) {
        await (db.update(db.goalContributions)
              ..where((c) => c.id.equals(contribution.id)))
            .write(GoalContributionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    }
  }
}