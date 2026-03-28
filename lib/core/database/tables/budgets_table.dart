import 'package:drift/drift.dart';
import 'categories_table.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id)();
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1-12
  RealColumn get limitAmount => real()();
}