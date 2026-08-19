import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

void main() async {
  await ModelInit().report();

  await BoxAccessMap().report();
  await BoxAccessHashMap().report();
  await BoxAccessList().report();
  assert(_boxAccessResult.isNotEmpty);

  await DynLibProcess().report();
  await DynLibFile().report();

  await StoreOpen().report();
}

class ModelInit extends Benchmark {
  ModelInit() : super('$ModelInit', iterations: 1000);

  @override
  void runIteration(int i) => getObjectBoxModel();
}

// ~ 21 M/second
class DynLibProcess extends Benchmark {
  DynLibProcess() : super('$DynLibProcess', iterations: 1000);

  @override
  void runIteration(int i) => DynamicLibrary.process();
}

// ~ 4 M/second
class DynLibFile extends Benchmark {
  DynLibFile() : super('$DynLibFile', iterations: 1000);

  @override
  void runIteration(int i) => DynamicLibrary.open('libobjectbox.so');
}

// Test whether using a map or iterating over a list is faster to access boxes.
// Typically, there's only a small number of entities so a list may be faster.
// Note: actual values of the following list don't matter... it's just trying
// to reproduce what store.box() does.
// Results:
//   * [Map] (defaults to [LinkedHashMap]) starts to be faster than a fixed-size
//     list at about 5-6 elements.
//   * [HashMap] is faster than a fixed size list since 3-4 elements
final _types = <Type>[int, double, String, List, Map, HashMap];

String _boxAccessResult = ''; // so that we do something with the result

class BoxAccessMap extends Benchmark {
  final boxes = {for (var item in _types) item: item.toString()};

  BoxAccessMap() : super('$BoxAccessMap', iterations: 10000);

  @override
  void runIteration(int i) {
    final desiredType = _types[i % _types.length];
    _boxAccessResult = boxes[desiredType]!;
  }
}

class BoxAccessHashMap extends Benchmark {
  final boxes = HashMap<Type, String>.fromIterable(
    _types,
    key: (item) => item,
    value: (item) => item.toString(),
  );

  BoxAccessHashMap() : super('$BoxAccessHashMap', iterations: 10000);

  @override
  void runIteration(int i) {
    final desiredType = _types[i % _types.length];
    _boxAccessResult = boxes[desiredType]!;
  }
}

class BoxAccessList extends Benchmark {
  final boxIndexes = List<Type>.from(_types, growable: false);
  final boxValues = List<String>.from(
    _types.map((t) => t.toString()),
    growable: false,
  );

  BoxAccessList() : super('$BoxAccessList', iterations: 10000);

  @override
  void runIteration(int i) {
    final desiredType = _types[i % _types.length];
    for (int j = 0; j < boxIndexes.length; j++) {
      if (boxIndexes[j] == desiredType) {
        _boxAccessResult = boxValues[j];
        return;
      }
    }
  }
}

class StoreOpen extends Benchmark {
  final String dbDir = 'benchmark-db';

  StoreOpen() : super('$StoreOpen');

  @override
  void runIteration(int iteration) {
    final store = Store(getObjectBoxModel(), directory: dbDir);
    store.close();
  }

  @override
  void teardown() {
    // Note: do not delete before test, not benchmarking file creation time.
    deleteDbDir();
    super.teardown();
  }

  void deleteDbDir() {
    final dir = Directory(dbDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
