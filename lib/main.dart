import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/app_database.dart';
import 'core/services/sync_service.dart';
import 'core/services/sync_service_provider.dart';
import 'core/database/database_provider.dart';
import 'features/pluggy/providers/pluggy_provider.dart';
import 'features/pluggy/screens/pluggy_import_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('pt_BR', null);

  final db = AppDatabase();
  final syncService = SyncService(db);

  syncService.checkAndPullOnStartup();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(syncService),
      ],
      child: const _AppWithPluggyCheck(),
    ),
  );
}

/// Wrapper que verifica novas transações do Pluggy após o app carregar
class _AppWithPluggyCheck extends ConsumerStatefulWidget {
  const _AppWithPluggyCheck();

  @override
  ConsumerState<_AppWithPluggyCheck> createState() =>
      _AppWithPluggyCheckState();
}

class _AppWithPluggyCheckState extends ConsumerState<_AppWithPluggyCheck> {
  bool _pluggyChecked = false;

  @override
  void initState() {
    super.initState();
    // Aguarda o primeiro frame antes de verificar — garante que o Navigator está pronto
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPluggy());
  }

  Future<void> _checkPluggy() async {
    if (_pluggyChecked) return;
    _pluggyChecked = true;

    // Pequeno delay para garantir que o app carregou visualmente
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final notifier = ref.read(pluggyConfigProvider.notifier);
    final txs = await notifier.fetchNewTransactions();

    if (txs.isEmpty || !mounted) return;

    // Navega para a tela de revisão
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PluggyImportScreen(transactions: txs),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const App();
}