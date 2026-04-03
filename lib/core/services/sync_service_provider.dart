import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service.dart';

// Será sobrescrito no main com a instância real
final syncServiceProvider = Provider<SyncService>((ref) {
  throw UnimplementedError('syncServiceProvider não foi inicializado');
});