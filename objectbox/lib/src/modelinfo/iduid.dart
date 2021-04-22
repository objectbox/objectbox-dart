// ignore_for_file: public_member_api_docs

/// IdUid represents a compound of an ID, which is locally unique, i.e. inside
/// an entity, and a UID, which is globally unique, i.e. for the entire model.
///
/// It is serialized as two numerical values concatenated using a colon (`:`).
/// See the documentation for more information on
///  * [IDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#ids)
///  * [UIDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#uids)
class IdUid {
  late int _id, _uid;

  int get id => _id;

  set id(int id) {
    RangeError.checkValueInInterval(id, 0, ((1 << 63) - 1), 'id');
    _id = id;
  }

  int get uid => _uid;

  set uid(int uid) {
    RangeError.checkValueInInterval(uid, 0, ((1 << 63) - 1), 'uid');
    _uid = uid;
  }

  IdUid(int newId, int newUid) {
    id = newId;
    uid = newUid;
  }

  IdUid.fromString(String? str) {
    if (str == null || str == '' || str == '0:0') {
      _id = 0;
      _uid = 0;
      return;
    }

    final spl = str.split(':');
    if (spl.length != 2) {
      throw ArgumentError.value(str, 'str', 'IdUid has invalid format');
    }
    id = int.parse(spl[0]);
    uid = int.parse(spl[1]);
  }

  IdUid.empty()
      : _id = 0,
        _uid = 0;

  bool get isEmpty => _id == 0 && _uid == 0;

  @override
  String toString() => '$_id:$_uid';
}
