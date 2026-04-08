import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/sync_service_provider.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FactoryResetScreen extends ConsumerStatefulWidget {
  const FactoryResetScreen({super.key});

  @override
  ConsumerState<FactoryResetScreen> createState() =>
      _FactoryResetScreenState();
}

class _FactoryResetScreenState extends ConsumerState<FactoryResetScreen> {
  bool _isResetting = false;
  bool _backupDone = false;

  Future<void> _exportBackup() async {
    final service = BackupService(ref.read(databaseProvider));
    await service.exportBackup(context);
    if (mounted) {
      setState(() => _backupDone = true);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            const Text('Confirmação final'),
          ],
        ),
        content: const Text(
          'Todos os dados serão apagados permanentemente.\n\n'
          'Esta ação não pode ser desfeita. Tem certeza absoluta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doReset();
  }

  Future<void> _doReset() async {
    setState(() => _isResetting = true);

    try {
      final db = ref.read(databaseProvider);
      final syncService = ref.read(syncServiceProvider);

      // 1. Cancela timers de sync para evitar uploads durante o reset
      syncService.dispose();

      // 2. Sinaliza todos os outros dispositivos via Drive (se conectado)
      final email = await GoogleAuthService.currentUserEmail();
      if (email != null) {
        await syncService.deleteSyncData();
      }

      // 3. Apaga todos os dados locais na ordem correta (respeita FKs)
      await db.transaction(() async {
        await db.managers.goalContributions.delete();
        await db.managers.goals.delete();
        await db.managers.budgets.delete();
        await db.managers.transactions.delete();
        await db.managers.categories.delete();
        await db.managers.accounts.delete();
      });

      // 4. Reinicia as categorias padrão
      await db.resetToDefaults();

      // 5. Limpa SharedPreferences relevantes (mantém apenas tema)
      final prefs = await SharedPreferences.getInstance();
      final themeMode = prefs.getString('app_theme_mode');
      await prefs.clear();
      if (themeMode != null) {
        await prefs.setString('app_theme_mode', themeMode);
      }

      // 6. Desautentica do Google
      await GoogleAuthService.signOut();

      if (mounted) {
        // Volta para a raiz do app com uma mensagem de sucesso
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados apagados. O app foi reiniciado.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResetting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar dados: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apagar todos os dados',
          style: AppTextStyles.sectionTitle(textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isResetting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.danger),
                  const SizedBox(height: 20),
                  Text(
                    'Apagando dados...',
                    style: AppTextStyles.body(textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aviso principal
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.danger.withOpacity(0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_forever_outlined,
                                color: AppColors.danger,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ação irreversível',
                                style:
                                    AppTextStyles.bodyBold(AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Isso irá apagar permanentemente:',
                          style: AppTextStyles.bodyBold(textPrimary),
                        ),
                        const SizedBox(height: 8),
                        ...const [
                          'Todas as contas e saldos',
                          'Todas as transações',
                          'Todos os orçamentos',
                          'Todas as metas e contribuições',
                          'Todas as categorias personalizadas',
                          'Dados de sincronização no Google Drive',
                        ].map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: AppTextStyles.body(textSecondary)),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: AppTextStyles.body(textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sugestão de backup
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _backupDone
                                  ? Icons.check_circle_outline
                                  : Icons.backup_outlined,
                              color: _backupDone
                                  ? AppColors.success
                                  : AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _backupDone
                                    ? 'Backup exportado!'
                                    : 'Recomendamos fazer um backup antes',
                                style: AppTextStyles.bodyBold(
                                  _backupDone
                                      ? AppColors.success
                                      : textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_backupDone) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Salve seus dados em um arquivo JSON para poder restaurá-los depois.',
                            style: AppTextStyles.label(textSecondary),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _exportBackup,
                              icon: const Icon(Icons.upload_outlined,
                                  size: 16),
                              label: const Text('Exportar backup agora'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botão de reset
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _confirmReset,
                      icon: const Icon(Icons.delete_forever_outlined,
                          size: 20),
                      label: const Text('Apagar todos os dados'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      'O app voltará ao estado de fábrica',
                      style: AppTextStyles.label(textSecondary),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}