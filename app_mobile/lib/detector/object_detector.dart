/// Representa um objeto detectado pelo modelo YOLO.
/// Usado pela [TtsService] para calcular posição, proximidade e prioridade.
class Detection {
  final int classIndex;
  final String className;
  final double confidence;
  // Bounding box normalizada [0,1] relativa ao frame
  final double x1, y1, x2, y2;

  const Detection({
    required this.classIndex,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}
