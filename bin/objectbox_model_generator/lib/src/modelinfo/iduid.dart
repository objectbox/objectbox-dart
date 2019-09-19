class IdUid {
  int id, uid;

  IdUid(String str) {
    var spl = str.split(":");
    if (spl.length != 2) throw Exception("IdUid has invalid format, too many columns: $str");
    id = int.parse(spl[0]);
    if (id <= 0 || id > ((1 << 63) - 1)) throw Exception("id out of bounds: $id");
    uid = int.parse(spl[1]);
    if (uid <= 0 || uid > ((1 << 63) - 1)) throw Exception("uid out of bounds: $uid");
    validate();
  }

  IdUid.create(this.id, this.uid) {
    validate();
  }

  IdUid.empty()
      : this.id = 0,
        this.uid = 0;

  void validate() {
    if (id <= 0) throw Exception("id may not be <= 0");
    if (uid <= 0) throw Exception("uid may not be <= 0");
  }

  String toString() => "$id:$uid";
}
