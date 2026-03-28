import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId =>
      integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  // 'income', 'expense', 'transfer'
  TextColumn get type => text().withDefault(const Constant('expense'))();
  RealColumn get amount => real()();
  IntColumn get date => integer()(); // timestamp Unix
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();

  // Recorrência
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  // 'monthly', 'weekly', 'yearly'
  TextColumn get recurrenceType => text().nullable()();
  IntColumn get recurrenceParentId => integer().nullable()();

  // Parcelamento
  IntColumn get installmentTotal => integer().nullable()();
  IntColumn get installmentCurrent => integer().nullable()();
  TextColumn get installmentGroupId => text().nullable()();

  // Transferência
  IntColumn get transferPairId => integer().nullable()();

  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
}