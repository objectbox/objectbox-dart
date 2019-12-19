bool listContains<T>(List<T> list, T item) => list.indexWhere((x) => x == item) != -1;
