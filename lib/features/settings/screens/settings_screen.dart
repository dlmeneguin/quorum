import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import 'categories_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/sync_service_provider.dart';
import '../providers/theme_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../pluggy/screens/pluggy_test_screen.dart';

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

                  // ── Sincronização ──
                  Text('Sincronização',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _SyncSection(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24),

                  // ── Open Finance (Pluggy) ──
                  Text('Open Finance',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.account_balance_rounded,
                    label: 'Importar dados bancários',
                    subtitle: 'Conecte via Pluggy / MeuPluggy (Open Finance)',
                    color: const Color(0xFF6366F1),
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PluggyTestScreen(),
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

// ── Seletor de tema ──

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

// ── Item de configuração ──

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

// ── Seção de sincronização ──

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
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  GoogleSignInAccount? _currentUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await GoogleAuthService.currentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _loading = false;
      });
    }
  }

  Future<void> _signIn() async {
    final user = await GoogleAuthService.signIn();
    if (user != null) {
      setState(() => _currentUser = user);
      // Aguarda o frame antes de checar sync para garantir que o token propagou
      await Future.delayed(const Duration(milliseconds: 500));
      await ref.read(syncServiceProvider).checkAndPullOnStartup();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login cancelado ou falhou'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await GoogleAuthService.signOut();
    if (mounted) {
      setState(() => _currentUser = null);
    }
  }

  Future<void> _syncNow() async {
    // Verifica autenticação antes de tentar
    final user = await GoogleAuthService.currentUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faça login no Google para sincronizar'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronizando...'),
          duration: Duration(seconds: 30),
        ),
      );
    }

    await ref.read(syncServiceProvider).forceUpload();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup enviado ao Google Drive'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isConnected = _currentUser != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.borderColor),
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
                      style: AppTextStyles.bodyBold(widget.textPrimary),
                    ),
                    Text(
                      isConnected
                          ? _currentUser!.email
                          : 'Conecte sua conta Google',
                      style: AppTextStyles.label(widget.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isConnected) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _syncNow,
                    child: const Text('Sincronizar agora'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: Text(
                    'Desconectar',
                    style: AppTextStyles.bodyBold(AppColors.danger),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Conectar com Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}