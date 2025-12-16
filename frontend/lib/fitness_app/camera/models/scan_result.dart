import 'package:hive/hive.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  String imagePath;

  @HiveField(1)
  String predictedClass;

  @HiveField(2)
  double confidence;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  bool synced;

  ScanResult({
    required this.imagePath,
    required this.predictedClass,
    required this.confidence,
    required this.timestamp,
    this.synced = false,
  });
}
