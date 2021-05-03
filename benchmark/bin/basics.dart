import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

void main() {
  ModelInit().report();
}

class ModelInit extends Benchmark {
  ModelInit() : super('${ModelInit}', iterations: 1000);

  @override
  void runIteration(int i) => getObjectBoxModel();
}
