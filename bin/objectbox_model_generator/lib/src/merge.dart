import "modelinfo/entity.dart";
import "modelinfo/modelinfo.dart";
import "modelinfo/property.dart";

void _mergeProperty(Entity entity, Property prop) {
  Property propInModel = entity.findSameProperty(prop);
  if (propInModel == null) {
    entity.createCopiedProperty(prop);
  } else {
    propInModel.type = prop.type;
    propInModel.flags = prop.flags;
  }
}

void mergeEntity(ModelInfo modelInfo, Entity readEntity) {
  // "readEntity" only contains the entity info directly read from the annotations and Dart source (i.e. with missing ID, lastPropertyId etc.)
  // "entityInModel" is the entity from the model with all correct id/uid, lastPropertyId etc.
  Entity entityInModel = modelInfo.findSameEntity(readEntity);

  if (entityInModel == null) {
    // in case the entity is created (i.e. when its given UID or name that does not yet exist), we are done, as nothing needs to be merged
    modelInfo.createCopiedEntity(readEntity);
  } else {
    // here, the entity was found already and entityInModel and readEntity might differ, i.e. conflicts need to be resolved, so merge all properties first
    readEntity.properties.forEach((p) => _mergeProperty(entityInModel, p));

    // them remove all properties not present anymore in readEntity
    entityInModel.properties
        .where((p) => readEntity.findSameProperty(p) == null)
        .forEach((p) => entityInModel.removeProperty(p));
  }
}
