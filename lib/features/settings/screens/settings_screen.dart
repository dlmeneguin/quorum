import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import 'categories_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/backup_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Text(
                'Configurações',
                style: AppTextStyles.splineSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Aparência ──
                  Text('Aparência',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _ThemeSelector(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24),
          
                  // ── Personalização ──
                  Text('Personalização',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.category_outlined,
                    label: 'Categorias',
                    subtitle: 'Gerencie suas categorias de transação',
                    color: AppColors.primary,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoriesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
          
                  // ── Dados ──
                  Text('Dados', style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.upload_outlined,
                    label: 'Exportar backup',
                    subtitle: 'Salvar todos os dados em arquivo JSON',
                    color: AppColors.success,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () async {
                      final service =
                          BackupService(ref.read(databaseProvider));
                      await service.exportBackup(context);
                    },
                  ),
                  //sincronização
                  const SizedBox(height: 24),
                  Text('Sincronização', style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _SyncSection(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.download_outlined,
                    label: 'Importar backup',
                    subtitle: 'Restaurar dados de um arquivo JSON',
                    color: AppColors.accent,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () async {
                      final service =
                          BackupService(ref.read(databaseProvider));
                      final message = await service.importBackup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: message.contains('sucesso')
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _ThemeSelector({
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    final options = [
      (AppThemeMode.light, Icons.light_mode_outlined, 'Claro'),
      (AppThemeMode.dark, Icons.dark_mode_outlined, 'Escuro'),
      (AppThemeMode.system, Icons.brightness_auto_outlined, 'Sistema'),
      (AppThemeMode.snoopy, Icons.favorite_outline_rounded, 'Alberto'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: options.map((option) {
          final (mode, icon, label) = option;
          final isSelected = currentMode == mode;
          final isSnoopy = mode == AppThemeMode.snoopy;
          final activeColor = isSnoopy
              ? AppColors.snoopyPrimary
              : AppColors.primary;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(themeModeProvider.notifier).state = mode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isSnoopy
                          ? AppColors.snoopyPrimary
                          : AppColors.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: AppTextStyles.dmSans(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color:
                            isSelected ? Colors.white : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodyBold(textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.label(textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SyncSection extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SyncSection({
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GoogleSignInAccount?>(
      future: GoogleAuthService.currentUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isConnected = user != null;

        return Container(
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.sync,
                      color: isConnected
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? 'Sincronização ativa'
                              : 'Sincronização desativada',
                          style: AppTextStyles.bodyBold(textPrimary),
                        ),
                        Text(
                          isConnected
                              ? user.email
                              : 'Conecte sua conta Google',
                          style: AppTextStyles.label(textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isConnected) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(syncServiceProvider)
                              .forceUpload();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backup enviado ao Google Drive'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Text('Sincronizar agora'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await GoogleAuthService.signOut();
                        if (context.mounted) {
                          setState(() {}); // força rebuild
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      child: Text(
                        'Desconectar',
                        style: AppTextStyles.bodyBold(AppColors.danger),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final user = await GoogleAuthService.signIn();
                          if (user != null) {
                            // Primeiro sync após conectar
                            await ref
                                .read(syncServiceProvider)
                                .checkAndPullOnStartup();
                          }
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Conectar com Google'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  // No botão de logout:
  onPressed: () async {
    await GoogleAuthService.signOut();
    setState(() {}); // agora funciona
  }
  // No botão de conectar, após signIn:
  setState(() {}); // força rebuild para mostrar estado conectado
}