import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../../shared/theme/app_colors.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<void> exportBackup(BuildContext context) async {
    final now = DateTime.now();

    final accounts =
        await db.accountsDao.watchAllAccounts().first;
    final categories =
        await db.categoriesDao.watchAllCategories().first;
    final transactions = await db.transactionsDao
        .watchTransactionsByPeriod(DateTime(2000), DateTime(2100))
        .first;
    final budgets = await db.managers.budgets.get();
    final goals = await db.goalsDao.watchAllGoals().first;
    final contributions = await db.managers.goalContributions.get();

    final payload = {
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
      'goals': goals.map((e) => e.toJson()).toList(),
      'goalContributions':
          contributions.map((e) => e.toJson()).toList(),
    };

    final jsonString =
        const JsonEncoder.withIndent('  ').convert(payload);

    final fileName =
        'quorum_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';

    if (Platform.isWindows) {
      // No Windows: abre diálogo "Salvar como" nativo
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar backup do Quórum',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath == null) return; // usuário cancelou

      final file = File(savePath);
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup salvo em $savePath'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      // No Android e outros: compartilha via share sheet
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );
    }
  }

  Future<String> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return 'Importação cancelada.';
    }

    try {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> payload = jsonDecode(jsonString);

      final version = payload['version'] as int? ?? 0;
      if (version != 1) {
        return 'Formato de backup incompatível (versão $version).';
      }

      await db.transaction(() async {
        // Limpa na ordem reversa de FK
        await db.managers.goalContributions.delete();
        await db.managers.goals.delete();
        await db.managers.budgets.delete();
        await db.managers.transactions.delete();
        await db.managers.categories.delete();
        await db.managers.accounts.delete();

        // Reinsere preservando IDs originais
        for (final raw in (payload['accounts'] as List)) {
          await db.into(db.accounts).insert(
                AccountsCompanion.insert(
                  id: raw['id'].toString(),
                  name: raw['name'] as String,
                  type: Value(raw['type'] as String),
                  initialBalance: Value(
                      (raw['initialBalance'] as num).toDouble()),
                  color: Value(raw['color'] as int?),
                  icon: Value(raw['icon'] as String?),
                  isActive: Value(raw['isActive'] as bool? ?? true),
                  createdAt: Value(raw['createdAt'] as int? ?? 0),
                ),
              );
        }

        for (final raw in (payload['categories'] as List)) {
          await db.into(db.categories).insert(
                CategoriesCompanion.insert(
                  id: raw['id'].toString(),
                  name: raw['name'] as String,
                  type: Value(raw['type'] as String? ?? 'expense'),
                  color: Value(raw['color'] as int?),
                  icon: Value(raw['icon'] as String?),
                  isDefault:
                      Value(raw['isDefault'] as bool? ?? false),
                ),
              );
        }

        for (final raw in (payload['transactions'] as List)) {
          await db.into(db.transactions).insert(
                TransactionsCompanion.insert(
                  id: raw['id'].toString(),
                  accountId: raw['accountId'] as String,
                  categoryId: Value(raw['categoryId'] as String?),
                  type: Value(raw['type'] as String),
                  amount: (raw['amount'] as num).toDouble(),
                  date: raw['date'] as int,
                  description: Value(raw['description'] as String?),
                  notes: Value(raw['notes'] as String?),
                  paymentMethod:
                      Value(raw['paymentMethod'] as String?),
                  isRecurring:
                      Value(raw['isRecurring'] as bool? ?? false),
                  recurrenceType:
                      Value(raw['recurrenceType'] as String?),
                  recurrenceParentId: Value(raw['recurrenceParentId'] as String?),
                  installmentTotal:
                      Value(raw['installmentTotal'] as int?),
                  installmentCurrent:
                      Value(raw['installmentCurrent'] as int?),
                  installmentGroupId:
                      Value(raw['installmentGroupId'] as String?),
                  transferPairId: Value(raw['transferPairId'] as String?),
                  createdAt: Value(raw['createdAt'] as int? ?? 0),
                  updatedAt: Value(raw['updatedAt'] as int? ?? 0),
                ),
              );
        }

        for (final raw in (payload['budgets'] as List)) {
          await db.into(db.budgets).insert(
                BudgetsCompanion.insert(
                  id: raw['id'].toString(),
                  categoryId: raw['categoryId'].toString(),
                  year: raw['year'] as int,
                  month: raw['month'] as int,
                  limitAmount:
                      (raw['limitAmount'] as num).toDouble(),
                ),
              );
        }

        for (final raw in (payload['goals'] as List)) {
          await db.into(db.goals).insert(
                GoalsCompanion.insert(
                  id: raw['id'].toString(),
                  name: raw['name'] as String,
                  targetAmount:
                      (raw['targetAmount'] as num).toDouble(),
                  currentAmount: Value(
                      (raw['currentAmount'] as num? ?? 0).toDouble()),
                  targetDate: Value(raw['targetDate'] as int?),
                  accountId: Value(raw['accountId'] as String?),
                  color: Value(raw['color'] as int?),
                  icon: Value(raw['icon'] as String?),
                  status:
                      Value(raw['status'] as String? ?? 'active'),
                  createdAt: Value(raw['createdAt'] as int? ?? 0),
                ),
              );
        }

        for (final raw in (payload['goalContributions'] as List)) {
          await db.into(db.goalContributions).insert(
                GoalContributionsCompanion.insert(
                  id: raw['id'].toString(),
                  goalId: raw['goalId'].toString(),
                  amount: (raw['amount'] as num).toDouble(),
                  date: raw['date'] as int,
                  note: Value(raw['note'] as String?),
                ),
              );
        }
      });

      return 'Backup importado com sucesso!';
    } catch (e) {
      return 'Erro ao importar: $e';
    }
  }
}