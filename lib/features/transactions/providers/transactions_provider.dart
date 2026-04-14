import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

// Transações do mês selecionado no dashboard
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedMonthProvider);

  final start = DateTime(selected.year, selected.month, 1);
  final end = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59);

  return db.transactionsDao.watchTransactionsByPeriod(start, end);
});

// Todas as transações (para busca global)
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.transactionsDao.watchTransactionsByPeriod(
    DateTime(2000),
    DateTime(2100),
  );
});

// Filtro de tipo selecionado na tela de transações
// 'all', 'income', 'expense'
final transactionTypeFilterProvider = StateProvider<String>((ref) => 'all');

// Transações filtradas por tipo
final filteredTransactionsProvider =
    Provider<AsyncValue<List<Transaction>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final filter = ref.watch(transactionTypeFilterProvider);

  return transactionsAsync.whenData((transactions) {
    if (filter == 'all') return transactions;
    return transactions.where((t) => t.type == filter).toList();
  });
});