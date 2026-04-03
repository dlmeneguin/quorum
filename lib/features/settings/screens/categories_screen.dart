import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/database/database_provider.dart';
import '../providers/categories_provider.dart';
import 'category_form_screen.dart';
import '../../../core/services/sync_service_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
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
        title: Text('Categorias',
            style: AppTextStyles.sectionTitle(textPrimary)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 48, color: textSecondary),
                  const SizedBox(height: 16),
                  Text('Nenhuma categoria',
                      style: AppTextStyles.body(textSecondary)),
                ],
              ),
            );
          }

          // Separa por tipo
          final expenses =
              categories.where((c) => c.type == 'expense').toList();
          final incomes =
              categories.where((c) => c.type == 'income').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            children: [
              if (expenses.isNotEmpty) ...[
                _SectionHeader('Despesas', AppColors.danger, textSecondary),
                const SizedBox(height: 8),
                ...expenses.map((c) => _CategoryTile(
                      category: c,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CategoryFormScreen(category: c),
                        ),
                      ),
                      onDelete: c.isDefault
                          ? null
                          : () => _confirmDelete(context, ref, c.id),
                    )),
                const SizedBox(height: 20),
              ],
              if (incomes.isNotEmpty) ...[
                _SectionHeader('Receitas', AppColors.success, textSecondary),
                const SizedBox(height: 8),
                ...incomes.map((c) => _CategoryTile(
                      category: c,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CategoryFormScreen(category: c),
                        ),
                      ),
                      onDelete: c.isDefault
                          ? null
                          : () => _confirmDelete(context, ref, c.id),
                    )),
              ],
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: const Text(
            'Tem certeza? Transações vinculadas perderão a categoria.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.categoriesDao.deleteCategory(id);
      ref.read(syncServiceProvider).scheduleUpload();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final Color textSecondary;

  const _SectionHeader(this.title, this.color, this.textSecondary);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: AppTextStyles.label(textSecondary)),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final category;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.category,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color != null
        ? Color(category.color!)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.circle, color: color, size: 16),
        ),
        title: Text(category.name,
            style: AppTextStyles.bodyBold(textPrimary)),
        subtitle: category.isDefault
            ? Text('Padrão',
                style: AppTextStyles.label(textSecondary))
            : null,
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: textSecondary),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete' && onDelete != null) onDelete!();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            if (onDelete != null)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Excluir',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}