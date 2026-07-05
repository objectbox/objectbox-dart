// ignore_for_file: public_member_api_docs

/// IdUid represents a compound of an ID, which is locally unique, i.e. inside
/// an entity, and a UID, which is globally unique, i.e. for the entire model.
///
/// It is serialized as two numerical values concatenated using a colon (`:`).
/// See the documentation for more information on
///  * [IDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#ids)
///  * [UIDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#uids)
class IdUid {
  final int id, uid;

  const IdUid(this.id, this.uid);

  factory IdUid.fromString(String? str) {
    if (str == null || str == '' || str == '0:0') {
      return const IdUid.empty();
    }

    final spl = str.split(':');
    if (spl.length != 2) {
      throw ArgumentError.value(str, 'str', 'IdUid has invalid format');
    }
    return IdUid(_parse('id', spl[0]), _parse('uid', spl[1]));
  }

  const IdUid.empty()
      : id = 0,
        uid = 0;

  bool get isEmpty => id == 0 && uid == 0;

  @override
  String toString() => '$id:$uid';

  static int _parse(String name, String part) {
    final value = int.parse(part);
    // Note: only the lower bound is checked. The former upper bound of
    // (1 << 63) - 1 is redundant on the VM, where int.parse already rejects
    // anything that does not fit a signed 64-bit integer, and it cannot be
    // expressed when compiling to JavaScript, where bit-shifts use 32-bit
    // semantics (it wrapped to a negative value making all IDs invalid).
    if (value < 0) {
      throw RangeError.value(value, name, 'must not be negative');
    }
    return value;
  }
}
