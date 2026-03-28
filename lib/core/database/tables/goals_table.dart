import 'package:drift/drift.dart';
import 'accounts_table.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount =>
      real().withDefault(const Constant(0))();
  IntColumn get targetDate => integer().nullable()();
  IntColumn get accountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  // 'active', 'completed', 'paused'
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
}