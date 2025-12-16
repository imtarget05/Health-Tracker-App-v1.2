import 'package:hive/hive.dart';
import '../models/scan_result.dart';

class DBService {
  static const _boxName = 'scan_history';

  static Future<void> init() async {
    await Hive.openBox<ScanResult>(_boxName);
  }

  static Future<void> addResult(ScanResult result) async {
    final box = Hive.box<ScanResult>(_boxName);
    await box.add(result);
  }

  static List<ScanResult> getAllResults() {
    final box = Hive.box<ScanResult>(_boxName);
    return box.values.toList();
  }

  static Future<void> markSynced(int index) async {
    final box = Hive.box<ScanResult>(_boxName);
    final result = box.getAt(index);
    if (result != null) {
      result.synced = true;
      await result.save();
    }
  }

  static Future<void> deleteResult(int index) async {
    final box = Hive.box<ScanResult>(_boxName);
    await box.deleteAt(index);
  }
}
