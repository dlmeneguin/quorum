import 'package:flutter/foundation.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPluggy());
  }

  Future<void> _checkPluggy() async {
    if (_pluggyChecked) return;
    _pluggyChecked = true;

    // Delay para o app carregar visualmente
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    try {
      final notifier = ref.read(pluggyConfigProvider.notifier);
      debugPrint('[Pluggy] Verificando novas transações...');

      final txs = await notifier.fetchNewTransactions();

      debugPrint('[Pluggy] Transações encontradas: ${txs.length}');

      if (txs.isEmpty || !mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PluggyImportScreen(transactions: txs),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      debugPrint('[Pluggy] Erro na verificação inicial: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const App();
}