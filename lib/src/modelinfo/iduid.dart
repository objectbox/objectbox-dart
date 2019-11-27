/// IdUid represents a compound of an ID, which is locally unique, i.e. inside an entity, and a UID, which is globally
/// unique, i.e. for the entire model. It is serialized as two numerical values concatenated using a colon (`:`).
/// See the documentation for more information on
///  * [IDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#ids)
///  * [UIDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#uids)
class IdUid {
  int _id, _uid;

  IdUid(int newId, int newUid) {
    id = newId;
    uid = newUid;
  }

  IdUid.fromString(String str) {
    if (str == null || str == "" || str == "0:0") {
      _id = 0;
      _uid = 0;
      return;
    }

    var spl = str.split(":");
    if (spl.length != 2) throw Exception("IdUid has invalid format, wrong number of columns: $str");
    id = int.parse(spl[0]);
    uid = int.parse(spl[1]);
  }

  IdUid.empty()
      : this._id = 0,
        this._uid = 0;

  set id(int id) {
    if (id < 0 || id > ((1 << 63) - 1)) throw Exception("id out of bounds: $id");
    _id = id;
  }

  set uid(int uid) {
    if (uid < 0 || uid > ((1 << 63) - 1)) throw Exception("uid out of bounds: $uid");
    _uid = uid;
  }

  int get id => _id;

  int get uid => _uid;

  String toString() => "$_id:$_uid";
}
