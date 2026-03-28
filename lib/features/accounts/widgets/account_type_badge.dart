import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

class AccountTypeBadge extends StatelessWidget {
  final String type;

  const AccountTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'checking' => ('Conta Corrente', const Color(0xFF6366F1)),
      'savings' => ('Poupança', AppColors.success),
      'cash' => ('Carteira', AppColors.accent),
      'credit' => ('Cartão de Crédito', AppColors.danger),
      _ => ('Outro', AppColors.textSecondaryLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(color),
      ),
    );
  }
}