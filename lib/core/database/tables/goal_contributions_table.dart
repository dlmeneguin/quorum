import 'package:drift/drift.dart';
import 'goals_table.dart';

class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId =>
      integer().references(Goals, #id)();
  RealColumn get amount => real()();
  IntColumn get date => integer()(); // timestamp Unix
  TextColumn get note => text().nullable()();
}