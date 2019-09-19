import "modelinfo/modelinfo.dart";

Map<String, dynamic> merge(Map<String, dynamic> modelInfo, Map<String, dynamic> annotatedModel) {
  print(annotatedModel);
  print(ModelInfo.fromMap(modelInfo).toMap());
  return modelInfo;
}
