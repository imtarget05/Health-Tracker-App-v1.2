import 'package:hive/hive.dart';

class SuggestionService {
  static const _boxName = 'scan_suggestions';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  /// Save a suggestion map (e.g., {"name": "Rice", "nutrition": {...}, "imagePath": "...", "ts": 12345})
  static Future<void> addSuggestion(Map<String, dynamic> suggestion) async {
    final box = Hive.box(_boxName);
    await box.add(suggestion);
  }

  static List<Map<String, dynamic>> getAll() {
    final box = Hive.box(_boxName);
    final list = box.values.toList();
    return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
  }

  static Future<void> deleteAt(int index) async {
    final box = Hive.box(_boxName);
    await box.deleteAt(index);
  }

  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}
