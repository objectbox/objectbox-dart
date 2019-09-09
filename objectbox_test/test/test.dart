import "dart:io";
import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
part "test.g.dart";

@Entity(id: 1, uid: 1)
class TestEntity {
    @Id(id: 1, uid: 1001)
    int id;

    @Property(id: 2, uid: 1002)
    String text;

    TestEntity();
    TestEntity.construct(this.text);
}

main() {
    Store store;
    Box box;

    setUp(() {
        store = Store([[TestEntity, TestEntity_OBXDefs]]);
        box = Box<TestEntity>(store);
    });

    group("box", () {
        test(".put() returns a valid id", () {
            int putId = box.put(TestEntity.construct("Hello"));
            expect(putId, greaterThan(0));
        });

        test(".get() returns the correct instance", () {
            int putId = box.put(TestEntity.construct("Hello"));
            final TestEntity inst = box.get(putId);
            expect(inst.id, equals(putId));
            expect(inst.text, equals("Hello"));
        });

        test(".put() and box.get() keep Unicode characters", () {
            final text = "😄你好";
            final TestEntity inst = box.get(box.put(TestEntity.construct(text)));
            expect(inst.text, equals(text));
        });

        // TODO: test box.putMany, box.getMany, box.getAll
    });

    tearDown(() {
        store.close();
        new Directory("objectbox").delete(recursive: true);
    });
}
