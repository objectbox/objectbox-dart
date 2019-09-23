class IdUid {
  int _id, _uid;

  IdUid(String str) {
    if (str == null) {
      _id = 0;
      _uid = 0;
      return;
    }

    var spl = str.split(":");
    if (spl.length != 2) throw Exception("IdUid has invalid format, wrong number of columns: $str");
    id = int.parse(spl[0]);
    uid = int.parse(spl[1]);
  }

  IdUid.create(int newId, int newUid) {
    id = newId;
    uid = newUid;
  }

  IdUid.empty()
      : this._id = 0,
        this._uid = 0;

  set id(int id) {
    if (id <= 0 || id > ((1 << 63) - 1)) throw Exception("id out of bounds: $id");
    _id = id;
  }

  set uid(int uid) {
    if (uid <= 0 || uid > ((1 << 63) - 1)) throw Exception("uid out of bounds: $uid");
    _uid = uid;
  }

  get id => _id;
  get uid => _uid;
  String toString() => "$id:$uid";
}
