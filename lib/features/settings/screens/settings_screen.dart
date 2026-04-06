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
import '../../pluggy/providers/pluggy_provider.dart';
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
                  _PluggySection(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seção Pluggy ──

class _PluggySection extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _PluggySection({
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  ConsumerState<_PluggySection> createState() => _PluggySectionState();
}

class _PluggySectionState extends ConsumerState<_PluggySection> {
  Future<void> _openConfigDialog({required bool turnOnAfter}) async {
    final notifier = ref.read(pluggyConfigProvider.notifier);
    final config = ref.read(pluggyConfigProvider).value;

    final clientIdCtrl =
        TextEditingController(text: config?.clientId ?? '');
    final clientSecretCtrl =
        TextEditingController(text: config?.clientSecret ?? '');
    final itemIdCtrl =
        TextEditingController(text: config?.itemId ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final tp = isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight;
          final ts = isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight;

          bool canSave() =>
              clientIdCtrl.text.trim().isNotEmpty &&
              clientSecretCtrl.text.trim().isNotEmpty &&
              itemIdCtrl.text.trim().isNotEmpty;

          return AlertDialog(
            title: Text('Configurar Pluggy',
                style: AppTextStyles.sectionTitle(tp)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Obtenha as credenciais em dashboard.pluggy.ai',
                    style: AppTextStyles.label(ts),
                  ),
                  const SizedBox(height: 16),
                  _DialogField(
                    label: 'Client ID',
                    controller: clientIdCtrl,
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    label: 'Client Secret',
                    controller: clientSecretCtrl,
                    obscure: true,
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    label: 'Item ID',
                    controller: itemIdCtrl,
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O Item ID é obtido no Demo da sua Application\n'
                    '(menu ⋮ → "Copiar Item ID")',
                    style: AppTextStyles.label(ts),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: canSave()
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      await notifier.saveCredentials(
        clientId: clientIdCtrl.text.trim(),
        clientSecret: clientSecretCtrl.text.trim(),
        itemId: itemIdCtrl.text.trim(),
      );
      if (turnOnAfter) {
        await notifier.setEnabled(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(pluggyConfigProvider);

    return configAsync.when(
      data: (config) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho + switch
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Color(0xFF6366F1), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Importação automática',
                          style: AppTextStyles.bodyBold(widget.textPrimary)),
                      Text(
                        config.isConfigured
                            ? 'Pluggy configurado'
                            : 'Configure para ativar',
                        style: AppTextStyles.label(widget.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.enabled && config.isConfigured,
                  activeColor: AppColors.primary,
                  onChanged: (value) async {
                    final notifier =
                        ref.read(pluggyConfigProvider.notifier);
                    if (value) {
                      // Quer ligar
                      if (!config.isConfigured) {
                        // Abre diálogo de configuração e liga após salvar
                        await _openConfigDialog(turnOnAfter: true);
                      } else {
                        await notifier.setEnabled(true);
                      }
                    } else {
                      await notifier.setEnabled(false);
                    }
                  },
                ),
              ],
            ),

            // Botão de editar credenciais
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openConfigDialog(turnOnAfter: false),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  config.isConfigured
                      ? 'Editar credenciais'
                      : 'Configurar credenciais',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            // Botão de teste (debug)
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PluggyTestScreen(),
                  ),
                ),
                icon: const Icon(Icons.bug_report_outlined, size: 16,
                    color: Color(0xFF6366F1)),
                label: const Text('Tela de testes (debug)',
                    style: TextStyle(color: Color(0xFF6366F1))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final ValueChanged<String> onChanged;

  const _DialogField({
    required this.label,
    required this.controller,
    this.obscure = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
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
  String? _currentUserEmail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (mounted) {
      setState(() {
        _currentUserEmail = email;
        _loading = false;
      });
    }
  }

  Future<void> _signIn() async {
    final email = await GoogleAuthService.signIn();
    if (email != null) {
      setState(() => _currentUserEmail = email);
      await ref.read(syncServiceProvider).onUserConnected();
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
    if (mounted) setState(() => _currentUserEmail = null);
  }

  Future<void> _syncNow() async {
    final email = await GoogleAuthService.currentUserEmail();
    if (email == null) {
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

  Future<void> _deleteSyncData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar dados de sincronização'),
        content: const Text(
          'Isso irá apagar o backup do Google Drive e sinalizar todos os dispositivos para desconectar. '
          'Seus dados locais não serão afetados.\n\nTem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apagando dados de sincronização...'),
          duration: Duration(seconds: 30),
        ),
      );
    }
    await ref.read(syncServiceProvider).deleteSyncData();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _currentUserEmail = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados de sincronização apagados.'),
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
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final isConnected = _currentUserEmail != null;

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
                child: Icon(Icons.sync,
                    color: isConnected
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                    size: 20),
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
                          ? _currentUserEmail!
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
                      side: const BorderSide(color: AppColors.danger)),
                  child: Text('Desconectar',
                      style:
                          AppTextStyles.bodyBold(AppColors.danger)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteSyncData,
                icon: const Icon(Icons.delete_forever_outlined,
                    size: 18, color: AppColors.danger),
                label: Text('Apagar dados de sincronização',
                    style: AppTextStyles.bodyBold(AppColors.danger)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Conectar com Google'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}