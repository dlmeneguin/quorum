import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get type => text().withDefault(const Constant('expense'))();
  RealColumn get amount => real()();
  IntColumn get date => integer()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();

  // Recorrência
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceType => text().nullable()();
  TextColumn get recurrenceParentId => text().nullable()();

  // Parcelamento
  IntColumn get installmentTotal => integer().nullable()();
  IntColumn get installmentCurrent => integer().nullable()();
  TextColumn get installmentGroupId => text().nullable()();

  // Transferência
  TextColumn get transferPairId => text().nullable()();
  BoolColumn get isTransferOut => boolean().nullable()();

  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}