import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/app_database.dart';
import 'core/services/sync_service.dart';
import 'core/services/sync_service_provider.dart';
import 'core/database/database_provider.dart';
import 'core/utils/app_logger.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o logger antes de qualquer serviço
  AppLogger.init();

  final db = AppDatabase();
  final syncService = SyncService(db);

  syncService.checkAndPullOnStartup();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(syncService),
      ],
      child: const App(),
    ),
  );
}