import 'dart:ffi';

import 'package:objectbox/src/native/bindings/bindings.dart';
import 'package:objectbox/src/native/bindings/data_visitor.dart';
import 'package:objectbox/src/native/bindings/helpers.dart';
import 'package:objectbox/src/store.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

/// Tests [visit] directly with a native query to cover cases the public query
/// API does not: a nested query run from within a callback (e.g. by an entity
/// constructor or setter), cancelling and throwing.
void main() {
  late TestEnv env;
  late Box<TestEntity> box;

  setUp(() {
    env = TestEnv('data_visitor');
    box = env.box;
    box.putMany([
      TestEntity(tString: 'a'),
      TestEntity(tString: 'b'),
      TestEntity(tString: 'c'),
    ]);
  });

  tearDown(() => env.closeAndDelete());

  /// Builds a native query matching all objects, caller must close it.
  Pointer<OBX_query> buildQueryAll() {
    final entityId =
        InternalStoreAccess.entityDef<TestEntity>(env.store).model.id.id;
    final builder = checkObxPtr(
      C.query_builder(InternalStoreAccess.cStore(env.store), entityId),
    );
    final query = checkObxPtr(C.query(builder));
    checkObx(C.qb_close(builder));
    return query;
  }

  // That a nested query works is also covered by the "query with nested" tests
  // in box_test.dart.
  test('nested query within callback', () {
    final query = buildQueryAll();
    try {
      var visited = 0;
      var nestedResults = 0;
      visit(query, (data, size) {
        visited++;
        final nestedQuery =
            box.query(TestEntity_.tString.notEquals('')).build();
        try {
          nestedResults += nestedQuery.find().length;
        } finally {
          nestedQuery.close();
        }
        return true;
      });
      expect(visited, 3);
      expect(nestedResults, 9);
    } finally {
      checkObx(C.query_close(query));
    }
  });

  // That visit cancels on return false is also covered by findFirst() tests
  // in query_test.dart.
  test('cancel visiting', () {
    final query = buildQueryAll();
    try {
      var visited = 0;
      visit(query, (data, size) {
        visited++;
        return false;
      });
      expect(visited, 1);
    } finally {
      checkObx(C.query_close(query));
    }
  });

  // That an exception is (only) propagated via an additional helper is also
  // covered by the "query with nested throwing query" test in box_test.dart.
  test('exception in callback cancels visiting', () {
    final query = buildQueryAll();
    try {
      var visited = 0;
      // The exception does not propagate (the native callback returns false),
      // so callers use ObjectVisitorError to get it out.
      visit(query, (data, size) {
        visited++;
        throw StateError('inside callback');
      });
      expect(visited, 1);
    } finally {
      checkObx(C.query_close(query));
    }
  });
}
