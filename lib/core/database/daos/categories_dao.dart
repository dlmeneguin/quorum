import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Stream<List<Category>> watchAllCategories() =>
      (select(categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Stream<List<Category>> watchCategoriesByType(String type) =>
      (select(categories)
            ..where((c) => c.type.equals(type) & c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<void> createCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Future<void> deleteCategory(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}