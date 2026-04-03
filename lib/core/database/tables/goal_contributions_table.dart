import 'package:drift/drift.dart';
import 'goals_table.dart';

class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  RealColumn get amount => real()();
  IntColumn get date => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}