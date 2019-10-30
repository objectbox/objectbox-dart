import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv env;
  Box box;

  setUp(() {
    env = TestEnv("query");
    box = env.box;
  });

  test(".null and .notNull", () {
    box.putMany([
      TestEntity.initDoubleAndBoolean(0.1, true),
      TestEntity.initDoubleAndBoolean(0.3, false),
      TestEntity.initText("one"),
      TestEntity.initText("two"),
    ] as List<TestEntity>);

    final b = TestEntity_.b;
    final t = TestEntity_.text;

    final qbNull = box.query(b.isNull()).build();
    final qbNotNull = box.query(b.notNull()).build();
    final qtNull = box.query(t.isNull()).build();
    final qtNotNull = box.query(t.notNull()).build();
    final qdNull = box.query(t.isNull()).build();
    final qdNotNull = box.query(t.notNull()).build();

    [qbNull, qbNotNull, qtNull, qtNotNull, qdNull, qdNotNull].forEach((q) {
      expect(q.count(), 2);
      q.close();
    });
  });

  test(".count doubles and booleans", () {
    box.putMany([
      TestEntity.initDoubleAndBoolean(0.1, true),
      TestEntity.initDoubleAndBoolean(0.3, false),
      TestEntity.initDoubleAndBoolean(0.5, true),
      TestEntity.initDoubleAndBoolean(0.7, false),
      TestEntity.initDoubleAndBoolean(0.9, true)
    ] as List<TestEntity>);

    final d = TestEntity_.d;
    final b = TestEntity_.b;

    // #43 final anyQuery0 = (d.between(0.79, 0.81) & ((b == false) as Condition)) | (d.between(0.69, 0.71) & ((b == false) as Condition));
    final anyQuery0 = (d.between(0.79, 0.81) & b.equals(false) | (d.between(0.69, 0.71) & b.equals(false)));
    final anyQuery1 = (d.between(0.79, 0.81).and(b.equals(false))).or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery2 = d.between(0.79, 0.81).and(b.equals(false)).or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery3 = d.between(0.79, 0.81).and(b.equals(false)).or(d.between(0.69, 0.71)).and(b.equals(false));

    // #43 final allQuery0 = d.between(0.09, 0.11) & ((b == true) as Condition);
    final allQuery0 = d.between(0.09, 0.11) & b.equals(true);

    final q0 = box.query(b.equals(false)).build();
    final qany0 = box.query(anyQuery0).build();
    final qany1 = box.query(anyQuery1).build();
    final qany2 = box.query(anyQuery2).build();
    final qany3 = box.query(anyQuery3).build();

    final qall0 = box.query(allQuery0).build();

    expect(q0.count(), 2);
    expect(qany0.count(), 1);
    expect(qany1.count(), 1);
    expect(qany2.count(), 1);
    expect(qany3.count(), 1);
    expect(qall0.count(), 1);

    [q0, qany0, qany1, qany2, qany3, qall0].forEach((q) => q.close());
  });

  test(".count matches of `greater` and `less`", () {
    box.putMany([
      TestEntity.initIntegerAndText(1336, "mord"),
      TestEntity.initIntegerAndText(1337, "more"),
      TestEntity.initIntegerAndText(1338, "morf"),
      TestEntity.initDoubleAndBoolean(0.0, false),
      TestEntity.initDoubleAndBoolean(0.1, true),
      TestEntity.initDoubleAndBoolean(0.2, true),
      TestEntity.initDoubleAndBoolean(0.3, false),
    ] as List<TestEntity>);

    final d = TestEntity_.d;
    final b = TestEntity_.b;
    final t = TestEntity_.text;
    final n = TestEntity_.number;

    final q0 = box.query(d.greaterThan(0.1)).build();
    final q1 = box.query(b.equals(false)).build();
    final q2 = box.query(t.greaterThan("more")).build();
    final q3 = box.query(t.lessThan("more")).build();
    final q4 = box.query(d.lessThan(0.3)).build();
    final q5 = box.query(n.lessThan(1337)).build();
    final q6 = box.query(n.greaterThan(1337)).build();

    expect(q0.count(), 2);
    expect(q1.count(), 2);
    expect(q2.count(), 1);
    expect(q3.count(), 1);
    expect(q4.count(), 3);
    expect(q5.count(), 1);
    expect(q6.count(), 1);

    [q0, q1, q2, q3, q4, q5, q6].forEach((q) => q.close());
  });

  test(".count matches of `in`, `contains`", () {
    box.put(TestEntity.initIntegerAndText(1337, "meh"));
    box.put(TestEntity.initIntegerAndText(1, "bleh"));
    box.put(TestEntity.initIntegerAndText(1337, "bleh"));
    box.put(TestEntity.initIntegerAndText(1337, "blh"));

    final text = TestEntity_.text;
    final number = TestEntity_.number;

    final qs0 = box.query(text.inside(["meh"])).build();
    final qs1 = box.query(text.inside(["bleh"])).build();
    final qs2 = box.query(text.inside(["meh", "bleh"])).build();
    final qs3 = box.query(text.contains("eh")).build();

    final qn0 = box.query(number.inside([1])).build();
    final qn1 = box.query(number.inside([1337])).build();
    final qn2 = box.query(number.inside([1, 1337])).build();

    expect(qs0.count(), 1);
    expect(qs1.count(), 2);
    expect(qs2.count(), 3);
    expect(qs3.count(), 3);
    expect(qn0.count(), 1);
    expect(qn1.count(), 3);
    expect(qn2.count(), 4);

    [qs0, qs1, qs2, qs3, qn0, qn1, qn2].forEach((q) => q.close());
  });

  test(".findIds returns List<int>", () {
    box.put(TestEntity.initId(0, "meh"));
    box.put(TestEntity.initId(0, "bleh"));
    box.put(TestEntity.initId(0, "bleh"));
    box.put(TestEntity.initId(0, "helb"));
    box.put(TestEntity.initId(0, "helb"));
    box.put(TestEntity.initId(0, "bleh"));
    box.put(TestEntity.initId(0, "blh"));

    final text = TestEntity_.text;

    final q0 = box.query(text.notNull()).build();
    final result0 = q0.findIds();

    final q2 = box.query(text.equals("blh")).build();
    final result2 = q2.findIds();

    final q3 = box.query(text.equals("can't find this")).build();
    final result3 = q3.findIds();

    expect(result0.length, 7);
    expect(result2.length, 1);
    expect(result3.length, 0);

    q0.close();
    q2.close();
    q3.close();
  });

  test(".find returns List<TestEntity>", () {
    box.put(TestEntity.initInteger(0));
    box.put(TestEntity.initText("test"));
    box.put(TestEntity.initText("test"));

    final text = TestEntity_.text;

    var q = box.query(text.notNull()).build();
    expect(q.find().length, 2);
    q.close();

    q = box.query(text.isNull()).build();
    expect(q.find(offset: 0, limit: 1).length, 1);
    q.close();
  });

  test(".findFirst returns TestEntity", () {
    box.put(TestEntity.initInteger(0));
    box.put(TestEntity.initText("test1t"));
    box.put(TestEntity.initText("test"));

    final text = TestEntity_.text;
    final number = TestEntity_.number;

    final c = text.startsWith("t") & text.endsWith("t");

    var q = box.query(c).build();

    expect(q.findFirst().text, "test1t");
    q.close();

    q = box.query(number.notNull()).build();
    expect(q.findFirst().number, 0);
    q.close();
  });

  test(".count items after grouping with and/or", () {
    box.put(TestEntity.initText("Hello"));
    box.put(TestEntity.initText("Goodbye"));
    box.put(TestEntity.initText("World"));

    box.put(TestEntity.initInteger(1337));
    box.put(TestEntity.initInteger(80085));

    box.put(TestEntity.initIntegerAndText(-1337, "meh"));
    box.put(TestEntity.initIntegerAndText(-1332 + -5, "bleh"));
    box.put(TestEntity.initIntegerAndText(1337, "Goodbye"));

    final text = TestEntity_.text;
    final number = TestEntity_.number;

    // #43 Condition cond1 = ((text == "Hello") as Condition) | ((number == 1337) as Condition);
    Condition cond1 = text.equals("Hello") | number.equals(1337);
    Condition cond2 = text.equals("Hello") | number.equals(1337);
    Condition cond3 = text.equals("What?").and(text.equals("Hello")).or(text.equals("World"));
    Condition cond4 = text
        .equals("Goodbye")
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals("Cruel"))
        .or(text.equals("World"));
    Condition cond5 = text.equals("bleh") & number.equals(-1337);
    // #43 Condition cond6 = ((text == "Hello") as Condition) & ((number == 1337) as Condition);
    Condition cond6 = text.equals("Hello") & number.equals(1337);

    // #43 final selfInference1 = (text == "Hello") & (number == 1337);
    // #43 final selfInference2 = (text == "Hello") | (number == 1337);

    final q1 = box.query(cond1).build();
    final q2 = box.query(cond2).build();
    final q3 = box.query(cond3).build();
    final q4 = box.query(cond4).build();
    final q5 = box.query(cond5).build();
    final q6 = box.query(cond6).build();
    // #43 final q7 = box.query(selfInference1 as Condition).build();
    // #43 final q8 = box.query(selfInference2 as Condition).build();

    expect(q1.count(), 3);
    expect(q2.count(), 3);
    expect(q3.count(), 1);
    expect(q4.count(), 3);
    expect(q5.count(), 1);
    expect(q6.count(), 0);
    // #43 expect(q7.count(), 0);
    // #43 expect(q8.count(), 3);

    // #43 [q1, q2, q3, q4, q5, q6, q7, q8].forEach((q) => q.close());
    [q1, q2, q3, q4, q5, q6].forEach((q) => q.close());
  });

  test(".describe query", () {
    final text = TestEntity_.text;
    final number = TestEntity_.number;
    Condition c = text
        .equals("Goodbye")
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals("Cruel"))
        .or(text.equals("World"));
    final q = box.query(c).build();
    // 5 partial conditions, + 1 'and' + 1 'any' = 7 conditions
    expect(q.describe(), "Query for entity TestEntity with 7 conditions with properties number, text");
    q.close();

    for (int j = 1; j < 20; j++) {
      var tc = text.equals("Hello");
      for (int i = 0; i < j; i++) {
        tc = tc.or(text.endsWith("lo"));
      }
      final q = box.query(tc).build();
      expect(q.describe(), '''Query for entity TestEntity with ${j + 2} conditions with properties text''');
      q.close();
    }

    for (int j = 1; j < 20; j++) {
      var tc = text.equals("Hello");
      for (int i = 0; i < j; i++) {
        tc = tc.and(text.startsWith("lo"));
      }
      final q = box.query(tc).build();
      expect(q.describe(), '''Query for entity TestEntity with ${j + 2} conditions with properties text''');
      q.close();
    }
  });

  test("query condition grouping", () {
    final n = TestEntity_.id;
    final b = TestEntity_.b;

    final check = (Condition condition, String text) {
      final q = box.query(condition).build();
      expect(q.describeParameters(), text);
      q.close();
    };

    check((n.equals(0) & b.equals(false)) | (n.equals(1) & b.equals(true)),
        '((id == 0\n AND b == 0)\n OR (id == 1\n AND b == 1))');
    check(n.equals(0) & b.equals(false) | n.equals(1) & b.equals(true),
        '((id == 0\n AND b == 0)\n OR (id == 1\n AND b == 1))');
    check((n.equals(0) & b.equals(false)) | (n.equals(1) | b.equals(true)),
        '((id == 0\n AND b == 0)\n OR (id == 1\n OR b == 1))');
    check((n.equals(0) & b.equals(false)) | n.equals(1) | b.equals(true),
        '((id == 0\n AND b == 0)\n OR id == 1\n OR b == 1)');
    check(n.equals(0) | b.equals(false) & n.equals(1) | b.equals(true),
        '(id == 0\n OR (b == 0\n AND id == 1)\n OR b == 1)');
  });

  test(".describeParameters query", () {
    final text = TestEntity_.text;
    final number = TestEntity_.number;
    Condition c = text
        .equals("Goodbye")
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals("Cruel"))
        .or(text.equals("World"));
    final q = box.query(c).build();
    final expectedString = [
      '''((text ==(i) "Goodbye"''',
      ''' AND number == 1337)''',
      ''' OR number == 1337''',
      ''' OR text ==(i) "Cruel"''',
      ''' OR text ==(i) "World")'''
    ].join("\n");
    expect(q.describeParameters(), expectedString);
    q.close();

    for (int j = 1; j < 20; j++) {
      var tc = text.equals("Goodbye");
      var expected = ['''text ==(i) "Goodbye"'''];
      for (int i = 0; i < j; i++) {
        tc = tc.and(text.endsWith("ye"));
        expected.add(''' AND text ends with(i) "ye"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }

    for (int j = 1; j < 20; j++) {
      var tc = text.equals("Goodbye");
      var expected = ['''text ==(i) "Goodbye"'''];
      for (int i = 0; i < j; i++) {
        tc = tc.or(text.startsWith("Good"));
        expected.add(''' OR text starts with(i) "Good"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }
  });

  test(".order queryBuilder", () {
    box.put(TestEntity.initText("World"));
    box.put(TestEntity.initText("Hello"));
    box.put(TestEntity.initText("HELLO"));
    box.put(TestEntity.initText("World"));
    box.put(TestEntity.initText("Goodbye"));
    box.put(TestEntity.initText("Cruel"));
    box.put(TestEntity.initInteger(1337));

    final text = TestEntity_.text;

    final condition = text.notNull();

    final query = box.query(condition).order(text).build();

    final queryWithFlags = box.query(condition).order(text, flags: Order.descending | Order.caseSensitive).build();

    final result1 = query.find().map((e) => e.text).toList();
    final result2 = queryWithFlags.find().map((e) => e.text).toList();

    expect("Cruel", result1[0]);
    expect("World", result2[0]);
    expect("Hello", result1[2]);
    expect("Hello", result2[2]);
    expect("HELLO", result1[3]);
    expect("HELLO", result2[3]);

    query.close();
    queryWithFlags.close();
  });

  tearDown(() {
    env.close();
  });
}
