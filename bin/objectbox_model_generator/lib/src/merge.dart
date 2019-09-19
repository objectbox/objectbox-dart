import "modelinfo/entity.dart";
import "modelinfo/modelinfo.dart";

void merge(ModelInfo modelInfo, Entity readEntity) {
  print(modelInfo.toMap());
  print(readEntity.toMap());
}
