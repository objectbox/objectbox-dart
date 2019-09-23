import "modelinfo/entity.dart";
import "modelinfo/modelinfo.dart";

void merge(ModelInfo modelInfo, Entity readEntity) {
  // "readEntity" only contains the entity info directly read from the annotations and Dart source
  // "entityInModel" is the entity from the model with all correct id/uid, last***Id etc.
  Entity entityInModel = modelInfo.findEntity(readEntity);

  if (entityInModel == null) {
    // in case the entity is created (i.e. when its given UID or name does not yet exist), we are done, as nothing needs to be merged
    modelInfo.createCopiedEntity(readEntity);
    return;
  }

  // here, the entity was found already and entityInModel and readEntity might differ, i.e. conflicts need to be resolved
}
