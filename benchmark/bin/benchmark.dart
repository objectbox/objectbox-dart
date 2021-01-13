import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:objectbox_benchmark/benchmark.dart';

void main(List<String> arguments) {
  exitCode = 0; // presume success

  final argDb = 'db';
  final argCount = 'count';
  final argRuns = 'runs';

  final parser = ArgParser()
    ..addOption(argDb, defaultsTo: 'benchmark-db', help: 'database directory')
    ..addOption(argCount, defaultsTo: '10000', help: 'number of objects')
    ..addOption(argRuns,
        defaultsTo: '30', help: 'number of times the tests should be executed');

  final args = parser.parse(arguments);
  final dbDir = Directory(args[argDb]);
  final count = int.parse(args[argCount]);
  final runs = int.parse(args[argRuns]);

  print('running $runs times with $count objects in $dbDir');

  if (dbDir.existsSync()) {
    print('deleting existing DB files in $dbDir');
    final dbFilesGlob = Glob(dbDir.path + '/*.mdb');
    for (var dbFile in dbFilesGlob.listSync()) {
      dbFile.deleteSync();
    }
  }

  final bench = Executor(dbDir);

  final inserts = bench.prepareData(count);

  for (var i = 0; i < runs; i++) {
    bench.putMany(inserts);
    final items = bench.readAll();
    bench.changeValues(items);
    bench.updateAll(items);
    bench.removeAll();

    print('${i + 1}/$runs finished');
  }

  bench.close();
  bench.printTimes([
    'putMany',
    'readAll',
    'updateAll',
    'removeAll',
  ]);
}
