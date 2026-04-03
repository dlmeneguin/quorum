import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/app_database.dart';
import 'core/services/sync_service.dart';
import 'app.dart';
import 'core/services/sync_service_provider.dart';
import 'core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  final db = AppDatabase();
  final syncService = SyncService(db);

  // Verifica sync na startup sem bloquear a UI
  syncService.checkAndPullOnStartup();

  runApp(
    ProviderScope(
      overrides: [
        // Sobrescreve o databaseProvider para usar a instância já criada
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(syncService),
      ],
      child: const App(),
    ),
  );
}